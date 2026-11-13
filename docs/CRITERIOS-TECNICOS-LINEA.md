# Criterios técnicos de aceptación — Reconocer Master En Línea (AWS)

Ocho criterios básicos que cubren En Línea de punta a punta: carga de
novedades, consulta, facturación, lotes y operación. Cada uno trae la evidencia
con la que QA lo da por cumplido. Nombres de ejemplo en DEV (cuenta
647096294147); en los otros ambientes cambia el prefijo (ver
[checklist, sección 2](CHECKLIST-DESPLIEGUE.md#2-ambientes-y-cuentas)).

| ID | Tema |
|---|---|
| CT-01 | Archivo final y disparo de la carga |
| CT-02 | Carga FULL en DynamoDB |
| CT-03 | Carga DELTA en DynamoDB |
| CT-04 | Novedades hacia Redshift Bureau |
| CT-05 | Consulta en línea (API Int) |
| CT-06 | Facturación del consumo |
| CT-07 | Cargue de archivos (Lotes) |
| CT-08 | Operación, seguridad y despliegue |

---

## CT-01 · Archivo final y disparo de la carga

**Criterio.** Dado que Redshift Reconocer terminó el UNLOAD de las 7 tablas en
`nov/<run_id>/data/<tabla>/` (CSV con encabezado, GZIP, columnas `pk` y `sk`
primero), cuando se escribe el archivo final `nov/<run_id>/7_tablas_finish.json`
con un conteo por tabla, entonces arrancan al mismo tiempo la Step Function
Update RecMaster (cuenta Reconocer) y el aviso a la cuenta Batch. Ningún otro
archivo dispara la carga, y dentro de `data/` solo hay archivos de datos.

**Evidencia.** Listado de `nov/<run_id>/` en el bucket Triggers_reconocer, el
contenido del archivo final, la ejecución de la Step Function con su input y el
evento recibido en la cuenta Batch.

## CT-02 · Carga FULL en DynamoDB

**Criterio.** Con `tipo_carga = FULL`, el S3 Import crea una tabla nueva
`reconocer_master_<run_id>` (llave `pk` + `sk`, cifrada con la CMK) con las
filas de las 7 tablas. La Lambda Validation compara `ImportedItemCount` con la
suma de `registros_esperados`:
- si coincide, cambia el puntero en Metadata & Control
  (`pk = VERSION#GLOBAL`, `sk = ACTIVA`) a la tabla nueva, y la tabla anterior
  se borra 5 minutos después;
- si no coincide, el puntero no cambia, la tabla anterior sigue atendiendo y la
  ejecución termina en `Failed`.

**Evidencia.** Ejecución exitosa y una con conteo alterado, con su historial de
estados; el puntero antes y después; el reporte
`validacion/<run_id>/resumen.json` en Upload_Staging; la tabla anterior borrada
solo en el caso exitoso.

## CT-03 · Carga DELTA en DynamoDB

**Criterio.** Con `tipo_carga = DELTA`, el Glue procesa cada una de las 7
tablas y escribe sobre la tabla vigente (la del puntero): inserta lo nuevo y
reemplaza lo que ya existe con la misma `pk` + `sk`. No borra filas ni cambia
el puntero. La Validation deja un reporte por tabla; si alguna tabla falla, la
ejecución termina en `Failed`.

**Evidencia.** Ejecución con sus 7 Glue, reportes `validacion/<run_id>/<tabla>.json`,
y una consulta de una `pk` modificada antes y después de la corrida.

## CT-04 · Novedades hacia Redshift Bureau

**Criterio.** Con el mismo archivo final, la cuenta Batch hace el COPY de las 7
tablas a tablas temporales leyendo el bucket de la cuenta Reconocer con *role
chaining* (rol del Bureau → `redshift-copy-xacct`). En FULL reemplaza la tabla
final (`DELETE` + `INSERT` en una transacción, nunca `TRUNCATE`); en DELTA hace
`MERGE` por la llave de cada tabla. Si el conteo de una tabla temporal no
coincide con `registros_esperados`, no se hace el `COMMIT`. Redshift Bureau no
se pausa.

**Evidencia.** Ejecución de la Step Function Upload, conteos por tabla temporal
contra el archivo final y conteo final por tabla en Bureau.

> Depende del repo de IaC de la cuenta Batch (RITM5324186) y de los repos
> Redshift (RITM5340235).

## CT-05 · Consulta en línea (API Int)

**Criterio.** `GET /v1/sujetos/{tipo}/{numero}/reporte/{perfil}` responde por
el API PRIVATE solo a través del VPC endpoint de e-Connect; desde fuera
responde 403. RecLineaCloud lee la tabla vigente del puntero y consulta por
`pk = <tipo>#<numero>`, de modo que tras un cambio de puntero (CT-02) las
consultas siguientes ya usan la tabla nueva sin redeploy. La respuesta llega
antes del límite de 29 s, y un sujeto inexistente devuelve una respuesta
controlada, no un error 5xx.

**Evidencia.** Llamada exitosa desde la red de e-Connect, llamada rechazada
desde fuera, consulta antes y después de un FULL, logs en CloudWatch con la
duración y la tabla consultada.

## CT-06 · Facturación del consumo

**Criterio.** Cada consulta exitosa deja un mensaje en la cola
`<prefijo>-facturacion.fifo` (con `MessageGroupId`). La Lambda Facturación lo
consume de a un mensaje y lo envía al API de facturación electrónica. Si falla,
se reintenta hasta 5 veces y luego el mensaje pasa a la DLQ; no se pierde ni se
factura dos veces.

**Evidencia.** Mensaje en la cola tras una consulta, invocación de la Lambda
Facturación, respuesta del API de facturación y un caso con fallo forzado que
termina en la DLQ.

> Pendiente: URL y tipo de autenticación del API de facturación electrónica.

## CT-07 · Cargue de archivos (Lotes)

**Criterio.** Cuando el Portal sube un `.csv` o `.txt` (hasta 99 registros) a
`input/<batch_id>/` del bucket RecMasterLotes, arranca la Step Function Lotes y
el lote pasa por RECIBIDO, VALIDADO, EN_PROCESO y PROCESADO en Metadata &
Control (`pk = BATCH#<batch_id>`, `sk = ESTADO`). RecLineaCloud genera un PDF
por registro en `output_raw/<batch_id>/` (5 a la vez) y Consolidar deja
`output_zip/<batch_id>/resultado.zip`. Un archivo inválido, o más del 10 % de
registros fallidos, deja el lote en FALLIDO con `detalle_error`. Entradas y
salidas se borran a los 30 días; `plantillas/` se conserva.

**Evidencia.** Un lote exitoso (estados, ZIP con un PDF por registro), un
archivo inválido y un lote con más del 10 % de fallas, ambos en FALLIDO, y la
regla de ciclo de vida del bucket.

> Pendiente: identidad AWS del Portal (Operación) para crear el rol
> `portal-lotes`.

## CT-08 · Operación, seguridad y despliegue

**Criterio.**
- Todo se despliega por IaC con Jenkins en DEV, QA, DEMO y PDN, desde el mismo
  código (`trunk/`) y con un state por cuenta.
- Un segundo build sin cambios responde *No changes*.
- Cada componente tiene su propio rol `BURoleFor-<prefijo>-<componente>` con el
  boundary de la cuenta y mínimo privilegio.
- S3, SQS, logs, Lambdas y las tablas del Import se cifran con la CMK del
  stack.
- No hay credenciales en el código ni en Secrets Manager.
- Hay logs en CloudWatch para Lambdas, Step Functions y API.
- El escaneo Wiz queda en `PASSED_BY_POLICY`.

**Evidencia.** Builds de Jenkins por ambiente (incluido uno con *No changes*),
roles y su boundary en IAM, la CMK en KMS, log groups y el reporte de Wiz.

> **SLA pendiente de acordar con negocio**: tiempo de respuesta de la consulta
> en línea, duración de la carga FULL y DELTA, y tiempo máximo por lote.

---

**Fuentes:** HLD *En_Línea_v2*, IaC `TF_RCNCR_LINEA_WS5_INFRA`
([SOLICITUD](SOLICITUD-REPOS-DESARROLLO.md), [guía de UNLOAD y carga](GUIA-UNLOAD-Y-CARGA.md),
[checklist](CHECKLIST-DESPLIEGUE.md)) y los builds de DEV del 20-oct al 13-nov.
