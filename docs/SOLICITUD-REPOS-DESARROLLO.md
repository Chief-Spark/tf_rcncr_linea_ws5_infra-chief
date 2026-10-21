# Reconocer Master Linea: IaC desplegada, repos de desarrollo y analisis

> Stack SLCOPRBA-1437. Que crea este repo (`COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA`)
> en la cuenta `647096294147`, que repo de desarrollo atiende cada componente,
> los tickets de esos repos y la traza del analisis de arquitectura en curso.
>
> Nombres en develop (build 74281). En otros ambientes cambia el prefijo:
> `<stage>-<accountId>-rcncr-ws5` con stage = `dev`, `qa`, `demo`, `prod`.

## Indice

1. [Inventario de la IaC desplegada (cuenta 147)](#1-inventario-de-la-iac-desplegada-cuenta-147)
2. [Reparto de responsabilidades](#2-reparto-de-responsabilidades)
3. [Contrato por repo de desarrollo](#3-contrato-por-repo-de-desarrollo)
   - [3.1 RecLineaCloud](#31-a_rcncr_ln_rclncld--reclineacloud-java)
   - [3.2 Lambda Authorizer](#32-a_rcncr_ln_athrzr--lambda-authorizer-python)
   - [3.3 Validation](#33-a_rcncr_ln_vldtn--validation-python)
   - [3.4 Glue RecMas_Transform_and_Upload](#34-a_rcncr_ln_rcms_trnsfrm--glue-recmas_transform_and_upload-python)
   - [3.5 Archivo que dispara la carga](#35-archivo-que-dispara-la-carga)
4. [Lo que necesita cada pipeline de desarrollo](#4-lo-que-necesita-cada-pipeline-de-desarrollo)
5. [Repos de desarrollo: seguimiento](#5-repos-de-desarrollo-seguimiento)
6. [Repos de desarrollo: tickets](#6-repos-de-desarrollo-tickets)
7. [Analisis en curso: novedades hacia la cuenta Batch](#7-analisis-en-curso-novedades-hacia-la-cuenta-batch)
   - [7.1 Que hay en cada cuenta](#71-que-hay-en-cada-cuenta)
   - [7.2 Lo que ya esta definido](#72-lo-que-ya-esta-definido)
   - [7.3 Conceptos](#73-conceptos)
   - [7.4 Recomendaciones](#74-recomendaciones)
   - [7.5 Preguntas abiertas](#75-preguntas-abiertas)
8. [Bitacora](#8-bitacora)

---

## 1. Inventario de la IaC desplegada (cuenta 147)

| # | Componente (HLD) | Recurso AWS desplegado (develop) | Archivo IaC | Rol IAM | Repo de desarrollo | Ticket |
|---|---|---|---|---|---|---|
| 1 | RecLineaCloud | Lambda `dev-647096294147-rcncr-ws5-reclineacloud-lambda` (java21) | `lambda.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-lmbd-reclineacloud` | `A_RCNCR_LN_RCLNCLD` (AWS – LAMBDA-JAVA) | RITM5307356 |
| 2 | Lambda Authorizer (Okta) | Lambda `dev-647096294147-rcncr-ws5-authorizer-lambda` (python3.13) | `lambda.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-lmbd-authorizer` | `A_RCNCR_LN_ATHRZR` (AWS – LAMBDA-ZIP) | RITM5307364 |
| 3 | Validation | Lambda `dev-647096294147-rcncr-ws5-validation-lambda` (python3.13) | `lambda.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-lmbd-validation` | `A_RCNCR_LN_VLDTN` (AWS – LAMBDA-ZIP) | RITM5307368 |
| 4 | RecMas_Transform_and_Upload | Glue Job `dev-647096294147-rcncr-ws5-recmas-transform-upload` (Glue 5.0) | `glue.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-glue-transform` | `A_RCNCR_LN_RCMS_TRNSFRM` (AWS – GLUE-PYTHON) | RITM5307372 |
| 5 | API Int / Ext | API REST PRIVATE `bg2kuoleug`, stage `dev` | `apigateway.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-apigw-cloudwatch` | Solo IaC (este repo) | — |
| 6 | Update RecMaster | Step Function `dev-647096294147-rcncr-ws5-upd-recmaster-sfn` (Distributed Map) | `stepfunctions.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-sfn-updrecmaster` | Solo IaC (este repo) | — |
| 7 | EventBridge Update | Regla `dev-647096294147-rcncr-ws5-upd-recmaster-event` | `eventbridge.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-evb-updrecmaster` | Solo IaC (este repo) | — |
| 8 | S3 Triggers_reconocer | Bucket `dev-647096294147-rcncr-ws5-triggers-reconocer-s3` | `s3.tf` | — | Solo IaC (este repo) | — |
| 9 | S3 Upload_Staging | Bucket `dev-647096294147-rcncr-ws5-upload-staging-s3` | `s3.tf` | — | Solo IaC (este repo) | — |
| 10 | Facturacion | SQS `dev-647096294147-rcncr-ws5-facturacion.fifo` + DLQ `...-facturacion-dlq.fifo` | `sqs.tf` | — (consumidor en otra cuenta) | Solo IaC (este repo) | — |
| 11 | Redshift UNLOAD / COPY | Roles `BURoleFor-dev-647096294147-rcncr-ws5-redshift-unload` y `-redshift-copy-xacct` (pendiente ARN Bureau) | `iam-redshift.tf` | — | Solo IaC (este repo) | — |
| 12 | Catalogo Glue | Database `dev-647096294147-rcncr-ws5-recmaster-glue` | `glue.tf` | — | Solo IaC (este repo) | — |

Fuera de alcance de este repo (no se despliegan aqui): tablas DynamoDB
(Base_Online, Metadata & Control), Lambda RecMicroservicios (existente) y Lambda
de Facturacion (otra cuenta).

Los componentes "Solo IaC" no tienen codigo propio: cualquier cambio (rutas del
API, definicion de la Step Function, patron del evento, politicas) se pide con
un PR a este repo.

---

## 2. Reparto de responsabilidades

| Lo define el repo de desarrollo | Lo define este repo de IaC (PR aqui) |
|---|---|
| Codigo fuente, tests, build del artefacto | Runtime, handler, memoria, timeout, concurrencia reservada |
| Ramas y merges propios | Variables de entorno de infraestructura |
| Publicar el codigo en la funcion / el script en S3 | Roles y permisos IAM, VPC, KMS, logs |
| | Rutas del API, Step Function, EventBridge, argumentos del Glue Job |

Si el pipeline de desarrollo cambia la **configuracion** de una Lambda (runtime,
handler, env vars), el siguiente build de IaC la revierte. El **codigo** no:
Terraform no fija `source_code_hash`.

---

## 3. Contrato por repo de desarrollo

### 3.1 `A_RCNCR_LN_RCLNCLD` — RecLineaCloud (Java)
- Publica en: `<stage>-647096294147-rcncr-ws5-reclineacloud-lambda`.
- Runtime `java21`, handler `com.experian.reconocer.linea.Handler::handleRequest`
  (**provisional**: desarrollo confirma el real y se ajusta en `var.lambdas`).
- 2048 MB, timeout 29 s (limite de integracion del API), concurrencia 50.
- Invocada por el API: `GET /v1/sujetos/{tipo}/{numero}/reporte/{perfil}`
  (integracion `AWS_PROXY`). Consumidor: Portal Reconocer, sin authorizer (API
  PRIVATE, solo entra por el VPC endpoint). *Cambio en la rama, pendiente de
  desplegar: hoy en AWS esta ruta aun usa el authorizer.*
- Variables de entorno que entrega la IaC:
  - `SQS_FACTURACION_URL`: cola FIFO de facturacion (envia `MessageGroupId`).
  - Nombres de tablas DynamoDB (cuando se informen en `terraform.tfvars`).
  - `OUTPUT_BUCKET`: solo si se define `reclinea_output_bucket`.
- Permisos: lectura DynamoDB (cuando haya tablas), `sqs:SendMessage` a la cola.

### 3.2 `A_RCNCR_LN_ATHRZR` — Lambda Authorizer (Python)
- Publica en: `<stage>-647096294147-rcncr-ws5-authorizer-lambda`.
- Runtime `python3.13`, handler `handler.lambda_handler`, 256 MB, 10 s.
- Protege **solo el API Ext** (accesos desde Apigee, ruta
  `POST /v1/microservicios/{operacion}`); el API Int no lo usa. Se asocia al API
  cuando se configura `recmicroservicios_function_name`. *Cambio en la rama,
  pendiente de desplegar.*
- Authorizer tipo **TOKEN**: recibe el header `Authorization` (JWT Okta) y debe
  devolver una policy IAM (`Allow`/`Deny` sobre `execute-api:Invoke`). Cache de
  resultado: 300 s.
- Sin variables de entorno de infraestructura; las de Okta (issuer, audience) se
  agregan en `var.lambdas.authorizer.environment_variables`.

### 3.3 `A_RCNCR_LN_VLDTN` — Validation (Python)
- Publica en: `<stage>-647096294147-rcncr-ws5-validation-lambda`.
- Runtime `python3.13`, handler `handler.lambda_handler`, 1024 MB, 300 s,
  concurrencia 7 (igual a la concurrencia del Map).
- La invoca la Step Function despues de cada Glue; recibe el item del Map
  (`run_id`, `tipo_carga`, `dominio`) y su respuesta es la salida del item.
- Variables de entorno: `BUCKET_STAGING`, `BUCKET_TRIGGERS` y tablas DynamoDB.

### 3.4 `A_RCNCR_LN_RCMS_TRNSFRM` — Glue RecMas_Transform_and_Upload (Python)
- Publica el script en:
  `s3://<stage>-647096294147-rcncr-ws5-upload-staging-s3/glue-scripts/recmas_transform_and_upload.py`
  (configurable con `glue_script_location`).
- Glue 5.0, G.1X, 10 workers, timeout 480 min.
- Argumentos fijos: `--TempDir`, `--BUCKET_TRIGGERS`, `--BUCKET_STAGING`,
  `--TABLE_BASE_ONLINE` (cuando se informe la tabla).
- Argumentos por ejecucion (desde la Step Function): `--run_id`, `--tipo_carga`,
  `--dominio`, `--s3_path`, `--registros_esperados`.

### 3.5 Archivo que dispara la carga
Hoy un objeto que termina en `manifest.json` en el bucket Triggers dispara
EventBridge → Step Function. El nombre y el formato son **supuestos** de la IaC
(borrador del HLD). **Acordado:** el disparador sera el CTL final
`7_tablas_finish.json` (ver [7.2](#72-lo-que-ya-esta-definido)); la regla aun no se ha
cambiado. Formato supuesto:

```json
{
  "run_id": "20261020-001",
  "tipo_carga": "FULL",
  "dominios": [
    { "nombre": "personas", "s3_path": "s3://.../personas/", "registros_esperados": 1000 }
  ]
}
```

---

## 4. Lo que necesita cada pipeline de desarrollo

1. Rol de despliegue con `lambda:UpdateFunctionCode` (y `lambda:PublishVersion`
   si versionan) sobre su funcion, o `s3:PutObject` sobre
   `glue-scripts/*` del bucket Upload_Staging en el caso del Glue.
2. El nombre del recurso por ambiente (tabla de la [seccion 1](#1-inventario-de-la-iac-desplegada-cuenta-147), cambiando el stage).
3. Mientras no publiquen, la Lambda corre el placeholder y falla en cada
   invocacion (el API devuelve error).

---

## 5. Repos de desarrollo: seguimiento

| # | Repo | Componente | Combinacion | Ticket | Estado |
|---|---|---|---|---|---|
| 1 | `A_RCNCR_LN_RCLNCLD` | RecLineaCloud | AWS – LAMBDA-JAVA | RITM5307356 | Creado (2026-10-21) |
| 2 | `A_RCNCR_LN_ATHRZR` | Lambda Authorizer | AWS – LAMBDA-ZIP | RITM5307364 | Creado (2026-10-21) |
| 3 | `A_RCNCR_LN_VLDTN` | Validation | AWS – LAMBDA-ZIP | RITM5307368 | Creado (2026-10-21) |
| 4 | `A_RCNCR_LN_RCMS_TRNSFRM` | Glue RecMas_Transform_and_Upload | AWS – GLUE-PYTHON | RITM5307372 | Creado (2026-10-21) |

Los 4 repos estan creados en el proyecto `COAWSPPR` de Bitbucket.

Pendiente: repo nuevo para la cuenta Batch (`651706752126`) con el EventBridge y
la Step Function Upload (ver [seccion 7](#7-analisis-en-curso-novedades-hacia-la-cuenta-batch)).

---

## 6. Repos de desarrollo: tickets

Un ticket por repo en **DevSecOps SPLatam → Radicar solicitud de Creacion de
Repositorio** (plantilla de la guia "Solicitud de repositorios").

**Datos comunes**
- Country: Colombia
- Project Key: `COAWSPPR` (mismo proyecto que `TF_RCNCR_LINEA_WS5_INFRA`)
- App type: AWS
- AppID (Sonar y Checkmarx): 29197

**Reglas de nombre**
- Mayusculas, sin vocales salvo la que inicia una palabra, palabras separadas por `_`.
- Prefijo AWS: `A_`. Raiz comun `RCNCR_LN` (Reconocer Linea).
- LAMBDA-ZIP es la combinacion valida para Lambdas Python (no existe LAMBDA-PYTHON).

### Ticket 1 — RecLineaCloud (RITM5307356)

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: AWS
Lenguaje: LAMBDA-JAVA
Nombre Repositorio: A_RCNCR_LN_RCLNCLD

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: codigo de la Lambda RecLineaCloud (Java 21) del stack Reconocer
Master Linea (SLCOPRBA-1437). La infraestructura ya esta desplegada por
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA en la cuenta 647096294147; este repo solo
publica el codigo en la funcion dev-647096294147-rcncr-ws5-reclineacloud-lambda.

Gracias
```

### Ticket 2 — Lambda Authorizer (RITM5307364)

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: AWS
Lenguaje: LAMBDA-ZIP
Nombre Repositorio: A_RCNCR_LN_ATHRZR

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: codigo Python 3.13 de la Lambda Authorizer (Okta) del API Reconocer
Master Linea (SLCOPRBA-1437). La infraestructura ya esta desplegada por
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA en la cuenta 647096294147; este repo solo
publica el codigo en la funcion dev-647096294147-rcncr-ws5-authorizer-lambda.

Gracias
```

### Ticket 3 — Validation (RITM5307368)

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: AWS
Lenguaje: LAMBDA-ZIP
Nombre Repositorio: A_RCNCR_LN_VLDTN

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: codigo Python 3.13 de la Lambda Validation del flujo Update RecMaster
(SLCOPRBA-1437). La infraestructura ya esta desplegada por
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA en la cuenta 647096294147; este repo solo
publica el codigo en la funcion dev-647096294147-rcncr-ws5-validation-lambda.

Gracias
```

### Ticket 4 — Glue RecMas_Transform_and_Upload (RITM5307372)

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: AWS
Lenguaje: GLUE-PYTHON
Nombre Repositorio: A_RCNCR_LN_RCMS_TRNSFRM

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: script PySpark del Glue Job RecMas_Transform_and_Upload del flujo
Update RecMaster (SLCOPRBA-1437). El job ya esta desplegado por
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA en la cuenta 647096294147
(dev-647096294147-rcncr-ws5-recmas-transform-upload); este repo publica el
script en s3://dev-647096294147-rcncr-ws5-upload-staging-s3/glue-scripts/.

Gracias
```

---

## 7. Analisis en curso: novedades hacia la cuenta Batch

> Estado: **en analisis, sin cambios en codigo**. Nada de esta seccion esta
> desplegado todavia.

### 7.1 Que hay en cada cuenta

**Cuenta 147 (`647096294147`) – este repo**
- Redshift Reconocer (provisionado). **Ya existe, no se despliega.**
- S3 Triggers_reconocer, EventBridge Update, Step Function Update RecMaster
  (Glue + Validation), S3 Upload_Staging. **Desplegados.**

**Cuenta Batch (`651706752126`) – repo nuevo por pedir**
- Redshift Bureau. **Ya existe, no se despliega. No se puede pausar.**
- EventBridge que recibe las novedades.
- Step Function Upload: carga las novedades en Redshift Bureau (COPY).

**Fuera de alcance**
- ECR `/ContactDataStdr`.

### 7.2 Lo que ya esta definido

- El **UNLOAD de Redshift Reconocer** escribe los archivos en Triggers_reconocer.
- Hay **dos flujos independientes** que arrancan al mismo tiempo desde ese bucket:
  1. Update RecMaster (cuenta 147): carga Base_Online para la consulta en linea.
  2. Novedades (cuenta Batch): carga las novedades en Redshift Bureau.
- El mismo bucket avisa a **los dos EventBridge**: el de la 147 y el `default`
  de la cuenta Batch.
- Redshift Bureau nunca se pausa.
- Se copian **7 tablas**. Las novedades que van a la cuenta Batch son **las mismas
  7 tablas** que alimentan el update online.
- **Un solo CTL final** dispara los dos flujos. Nombre acordado:
  **`7_tablas_finish.json`** (2026-10-21).
- Todo se escribe en el bucket **Triggers_reconocer** (147), ya desplegado.

**Estructura de carpetas propuesta** (una carpeta por ejecucion y, dentro, una
por tabla). En S3 las carpetas se crean solas cuando el UNLOAD escribe; no hay
que crearlas en la IaC.

```
nov/<run_id>/<tabla_1>/            archivos del UNLOAD + manifest de la tabla
nov/<run_id>/<tabla_2>/
...
nov/<run_id>/<tabla_7>/
nov/<run_id>/7_tablas_finish.json  CTL final: el unico que dispara
```

- Por ejecucion: no se pisan datos entre corridas y se puede reprocesar o auditar.
- Por tabla: el Glue (147) y el COPY de Bureau (Batch) leen una tabla por carpeta.
  El COPY puede usar directamente el manifest de la tabla (`COPY ... MANIFEST`).
- Regla de disparo (en las dos cuentas): carpeta `nov/` + archivo que termina en
  `7_tablas_finish.json`.

**Contenido propuesto de `7_tablas_finish.json`** (el formato que ya lee la Step
Function Update RecMaster; la Step Function Upload puede usar la misma lista):

```json
{
  "run_id": "20261021-001",
  "tipo_carga": "NOVEDADES",
  "fecha_fin": "2026-10-21T05:00:00Z",
  "dominios": [
    {
      "nombre": "tabla_1",
      "s3_path": "s3://<bucket-triggers>/nov/20261021-001/tabla_1/",
      "registros_esperados": 125000
    }
  ]
}
```
(una entrada por cada una de las 7 tablas)
- Redshift Reconocer deberia apagarse al terminar su calculo y el UNLOAD, y
  encenderse antes del siguiente calculo, para ahorrar costos.

### 7.3 Conceptos

- **Archivo de control (CTL):** archivo pequeño que el UNLOAD escribe **al final**
  para avisar "ya termine". Es el unico que dispara la Step Function. Sin el, se
  lanzaria una ejecucion por cada archivo que escribe el UNLOAD (el UNLOAD parte
  los datos en muchos archivos).
- **`manifest.json`:** es el nombre que se **supuso** en la IaC para ese archivo
  de control. Hoy la regla EventBridge Update se dispara con cualquier archivo
  que termine en `manifest.json`. Se cambia por el nombre que se acuerde.
- **Update online:** la carga que actualiza Base_Online (DynamoDB), que es lo que
  consulta el API en linea. Es el flujo de la Step Function Update RecMaster.
- **Reenvio de eventos entre cuentas:** S3 solo avisa al EventBridge de su propia
  cuenta (147). Para que la cuenta Batch se entere, una regla en la 147 reenvia
  el evento al bus `default` de la cuenta Batch.

### 7.4 Recomendaciones

- **Pausa / Resume de Redshift Reconocer: tiene sentido** por costos (pausado no
  se cobra computo, solo almacenamiento).
  - Pausarlo apenas termine el UNLOAD: el Glue y el COPY de Bureau leen de S3,
    no de Reconocer, asi que no hay que esperarlos.
  - Encenderlo antes del siguiente calculo.
  - Debe controlarlo el proceso que lanza el calculo Reconocer. Si es la Step
    Function de la cuenta Batch, hace falta en la 147 un rol con
    `redshift:PauseCluster`, `redshift:ResumeCluster` y `redshift:DescribeClusters`
    sobre ese cluster, que pueda asumir el rol de esa Step Function.
  - Validar antes que nadie mas use Reconocer en horarios en que estaria apagado.
- **COPY en Redshift Bureau: role chaining** (lo que ya esta preparado en
  `iam-redshift.tf`). El rol del Redshift Bureau asume el rol
  `redshift-copy-xacct` de la 147, que solo puede leer el bucket Triggers. No hay
  que tocar la policy del bucket. Falta el ARN del rol del Redshift Bureau.
- **Archivo de control:** que el UNLOAD escriba un archivo de control al final de
  cada flujo, y que cada EventBridge se dispare solo con el suyo (por nombre y
  carpeta), para que un flujo no dispare al otro.
- **CTL por tabla + CTL final (propuesta 2026-10-21, 7 tablas):**
  - **CTL por tabla:** el `UNLOAD ... MANIFEST VERBOSE` de Redshift ya escribe,
    por cada tabla, un archivo con la lista de archivos y el numero de registros.
    No hay que programarlo. **No dispara nada**: solo sirve para saber que esa
    tabla termino y cuantos registros tiene.
  - **CTL final:** cuando terminan las 7 tablas, el proceso que corre los UNLOAD
    escribe un ultimo archivo (por ejemplo `<run_id>/_CTL_FIN.json`) con las 7
    tablas, su carpeta y su conteo. **Es el unico que dispara** los EventBridge.
    Redshift puede escribirlo con un UNLOAD de una consulta pequeña
    (`PARALLEL OFF`).
  - Encaja con la Step Function Update RecMaster: el Map recorre las 7 tablas
    (concurrencia maxima ya configurada en 7), el Glue procesa cada una y la
    Validation compara contra el conteo del CTL.

### 7.5 Preguntas abiertas

1. Carpetas (prefijos) exactas donde escribe el UNLOAD: novedades (`nov/`?) y
   update online. ¿Los dos flujos usan los mismos archivos o carpetas distintas?
2. Aprobar la estructura de carpetas y el contenido de `7_tablas_finish.json`
   (7.2). Nombres reales de las 7 tablas y formato del `run_id`.
3. ¿Que proceso lanza hoy el calculo Reconocer? (define quien enciende y apaga
   el cluster).
4. ARN del rol IAM del Redshift Bureau (para el COPY).
5. ¿El Data Sharing Bureau → Reconocer ya existe o es parte de este trabajo?
6. Ambientes: ¿por ahora solo develop? ¿Que cuentas se usan en qa y produccion?

---

## 8. Bitacora

| Fecha | Que paso |
|---|---|
| 2026-10-20 | Build 74281: IaC desplegada en develop (cuenta 147). |
| 2026-10-21 | Tickets RITM5307356, RITM5307364, RITM5307368 y RITM5307372 atendidos: 4 repos creados. |
| 2026-10-21 | Authorizer solo para Apigee (API Ext): cambio en la rama, **pendiente de decidir y desplegar**. |
| 2026-10-21 | Analisis del flujo de novedades hacia la cuenta Batch: respuestas registradas en 7.2, preguntas abiertas en 7.5. |
| 2026-10-21 | Se copian 7 tablas. Propuesta: CTL por tabla (manifest nativo del UNLOAD) + CTL final que dispara los flujos (7.4). |
| 2026-10-21 | Novedades = las mismas 7 tablas. Un solo CTL final, `7_tablas_finish`, dispara los dos flujos. Pendiente ajustar la IaC. |
| 2026-10-21 | CTL final: `7_tablas_finish.json`. Propuesta de carpetas `nov/<run_id>/<tabla>/` y contenido del JSON (7.2). |
