# Reconocer Master Linea: IaC desplegada, repos de desarrollo y analisis

> Stack SLCOPRBA-1437. Que crea este repo (`COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA`)
> en la cuenta `647096294147`, que repo de desarrollo atiende cada componente,
> los tickets de esos repos y la traza del analisis de arquitectura en curso.
>
> Nombres en develop (build 74281). En otros ambientes cambia el prefijo:
> `<stage>-<accountId>-rcncr-ws5` con stage = `dev`, `qa`, `demo`, `prod`.
>
> Estado por ambiente (desplegado / pendiente) y traza de builds:
> [CHECKLIST-DESPLIEGUE.md](CHECKLIST-DESPLIEGUE.md).

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
   - [7.5 Impacto de FULL / DELTA en el despliegue](#75-impacto-de-full--delta-en-el-despliegue-cuenta-147)
   - [7.6 Preguntas abiertas](#76-preguntas-abiertas)
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
  PRIVATE, solo entra por el VPC endpoint). *Desplegado 2026-10-28.*
- Variables de entorno que entrega la IaC:
  - `SQS_FACTURACION_URL`: cola FIFO de facturacion (envia `MessageGroupId`).
  - `TABLE_CONTROL` (Metadata & Control) y `TABLE_MASTER_PREFIX`
    (`reconocer_master_`): la tabla vigente se lee del puntero en Metadata &
    Control. *Desplegado 2026-10-28.*
  - `OUTPUT_BUCKET`: solo si se define `reclinea_output_bucket`.
- Permisos: lectura DynamoDB (cuando haya tablas), `sqs:SendMessage` a la cola.

### 3.2 `A_RCNCR_LN_ATHRZR` — Lambda Authorizer (Python)
- Publica en: `<stage>-647096294147-rcncr-ws5-authorizer-lambda`.
- Runtime `python3.13`, handler `handler.lambda_handler`, 256 MB, 10 s.
- Protege **solo el API Ext** (accesos desde Apigee, ruta
  `POST /v1/microservicios/{operacion}`); el API Int no lo usa. Se asocia al API
  cuando se configura `recmicroservicios_function_name`. Hoy no esta asociado
  (el authorizer del API se borro el 2026-10-28; se crea solo con el API Ext).
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
- Variables de entorno: `BUCKET_STAGING`, `BUCKET_TRIGGERS`, `TABLE_CONTROL` y
  `TABLE_MASTER_PREFIX`.
- **FULL** (*desplegado 2026-10-28*): la Step Function la invoca una vez, despues
  del S3 Import, con `{run_id, tipo_carga, dominios, tabla_nueva, importacion}`
  (`importacion` = descripcion del Import: `ImportedItemCount`, `ErrorCount`...).
  Debe:
  1. comparar `ImportedItemCount` con la suma de `registros_esperados`;
  2. si esta bien, cambiar el puntero en Metadata & Control a `tabla_nueva`;
  3. responder `{"estado": "OK"|"ERROR", "tabla_anterior": "<nombre>"|null}`.
  Con `OK` y `tabla_anterior`, la Step Function espera 5 minutos y borra esa
  tabla (solo si empieza por `reconocer_master_` y no es la nueva).
- Escribe su reporte en `s3://<upload-staging>/validacion/<run_id>/` (formato en
  la [guia, seccion 7](GUIA-UNLOAD-Y-CARGA.md#7-validaciones)). *Permiso
  desplegado 2026-10-28.*

### 3.4 `A_RCNCR_LN_RCMS_TRNSFRM` — Glue RecMas_Transform_and_Upload (Python)
- Publica el script en:
  `s3://<stage>-647096294147-rcncr-ws5-upload-staging-s3/glue-scripts/recmas_transform_and_upload.py`
  (configurable con `glue_script_location`).
- Glue 5.0, G.1X, 10 workers, timeout 480 min.
- Argumentos fijos: `--TempDir`, `--BUCKET_TRIGGERS`, `--BUCKET_STAGING`,
  `--TABLE_CONTROL` y `--TABLE_MASTER_PREFIX` (*desplegado 2026-10-28*). En DELTA
  el Glue lee el puntero en Metadata & Control y escribe en la tabla vigente.
- Argumentos por ejecucion (desde la Step Function): `--run_id`, `--tipo_carga`,
  `--dominio`, `--s3_path`, `--registros_esperados`.

### 3.5 Archivo que dispara la carga
El CTL final `nov/<run_id>/7_tablas_finish.json` dispara la Step Function y el
reenvio a la cuenta Batch (regla `nov/*/7_tablas_finish.json`; *pendiente de
desplegar*: hoy en AWS la regla aun espera `manifest.json`). Formato y contenido
en [7.2](#72-lo-que-ya-esta-definido) y en la
[guia, seccion 4](GUIA-UNLOAD-Y-CARGA.md#4-paso-2-archivo-final-7_tablas_finishjson).

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

| 5 | `TF_RCNCR_LINEA_WS5_BTCH_INFRA` | IaC de la cuenta Batch (651706752126) | TERRAFORM – TERRAFORM | RITM5324186 | Radicado (2026-10-27) ([Ticket 5](#ticket-5--iac-cuenta-batch-ritm5324186)) |

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

### Ticket 5 — IaC cuenta Batch (RITM5324186)

```
Buenos dias, solicito la creacion del siguiente repositorio en Bitbucket:

Country: Colombia
ProjectKey: COAWSPPR
Tecnologia: Terraform
Lenguaje: Terraform
Nombre Repositorio: TF_RCNCR_LINEA_WS5_BTCH_INFRA

Adicional aplicaciones: Sonar y Checkmarx con AppID 29197.

Contexto: infraestructura (Terraform) de Reconocer Master Linea (SLCOPRBA-1437)
en la cuenta Procesos Batch 651706752126: EventBridge que recibe el aviso de
novedades desde la cuenta 647096294147, Step Function Upload que hace el COPY
a Redshift Bureau y sus roles IAM. Complementa a
COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA (cuenta 647096294147).

Gracias
```

**Lo que debe crear ese repo (cuenta 651706752126)**
1. Rol `BURoleFor-dev-651706752126-rcncr-ws5-redshift-bureau-copy`
   (**exactamente este nombre**: la 147 ya confia en el):
   - confianza: `redshift.amazonaws.com`;
   - permiso: `sts:AssumeRole` sobre
     `arn:aws:iam::647096294147:role/BURoleFor-dev-647096294147-rcncr-ws5-redshift-copy-xacct`;
   - luego, el administrador del cluster lo asocia a Redshift Bureau.
2. Resource policy del event bus `default`: permitir `events:PutEvents` desde
   la cuenta `647096294147`.
3. Regla EventBridge en el bus `default` (evento S3 "Object Created" con
   `nov/*/7_tablas_finish.json`) → Step Function Upload.
4. Step Function Upload y su rol: lee el CTL final, hace el COPY de las 7 tablas
   a tablas temporales y luego FULL (`DELETE` + `INSERT`) o DELTA (`MERGE`).
   Ver [guia, seccion 6](GUIA-UNLOAD-Y-CARGA.md#6-paso-4-copy-en-redshift-bureau-cuenta-batch).

Alternativa sin ticket: el repo batch existente `TF_RCNCR_WS5_INFRA` ya despliega
en la cuenta 651706752126 y podria alojar estas piezas.

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

**Flujo**
- El **UNLOAD de Redshift Reconocer** escribe los archivos en el bucket
  **Triggers_reconocer** (147), ya desplegado.
- Dos **flujos independientes** arrancan al mismo tiempo con el mismo archivo final:
  1. Update RecMaster (cuenta 147): carga Base_Online (DynamoDB) para la consulta en linea.
  2. Novedades (cuenta Batch): carga los mismos datos en Redshift Bureau.
- El bucket avisa a **los dos EventBridge**: el de la 147 y el `default` de la
  cuenta Batch (reenviado desde la 147).
- Redshift Bureau nunca se pausa. Redshift Reconocer deberia apagarse al terminar
  el calculo y el UNLOAD, y encenderse antes del siguiente calculo (costos).

**Las 7 tablas** (aprobado 2026-10-21)
1. `mat_info_ubicacion`
2. `mat_info_actividad_economica`
3. `mat_ubicacion_agregada`
4. `mat_info_basica`
5. `mat_info_contactabilidad`
6. `mat_info_punto_interes`
7. `mat_info_movilidad`

**`run_id`** (aprobado): fecha + hora (timestamp) + `FULL` o `DELTA`.
Ejemplo: `20261021T053000Z_FULL`.

**Tipo de carga** (2026-10-21)
- **FULL:** el insert a DynamoDB del en linea se hace con **DynamoDB Import from
  S3**, leyendo el mismo bucket Triggers_reconocer.
- **DELTA:** se sigue usando el Glue RecMas_Transform_and_Upload. Solo trae
  registros **nuevos y modificados** (no borrados): el Glue escribe encima
  (upsert) en la tabla vigente.
- **Tabla vigente (puntero):** lo guarda la tabla DynamoDB **Metadata & Control**
  (ya prevista en la arquitectura). RecLineaCloud recibe el puntero por parametro
  o consulta esa tabla. La Validation actualiza el puntero cuando el FULL queda
  validado.
- **Despues de un FULL, la tabla anterior se borra.**

**Carpetas** (aprobado 2026-10-21). `nov/` es una carpeta dentro del bucket
Triggers_reconocer (ya desplegado), no un bucket aparte. Una carpeta por
ejecucion; dentro, `data/` con una carpeta por tabla, y el CTL final fuera de
`data/` (el Import lee todo `data/` y no debe ver el CTL). En S3 las carpetas se
crean solas cuando el UNLOAD escribe; no van en la IaC.

```
nov/20261021T053000Z_FULL/data/mat_info_ubicacion/   solo archivos de datos
nov/20261021T053000Z_FULL/data/mat_info_basica/
...                                                  (las 7 tablas)
nov/20261021T053000Z_FULL/7_tablas_finish.json       CTL final: el unico que dispara
```

Las 7 tablas van a **una sola** tabla DynamoDB (`reconocer_master`). En FULL,
**nuestra Step Function** lanza un Import sobre `nov/<run_id>/data/`.

**Formato del UNLOAD** (aprobado 2026-10-22): **CSV con encabezado + GZIP.**

**Llave de `reconocer_master`** (2026-10-22): tipo de identificacion + numero de
identificacion. Diseño **aprobado 2026-10-22**:
- `pk` (partition key, **texto**) = `<tipo_id>#<numero_id>`. Ej.: `CC#1020304050`.
  Identifica a la persona.
- `sk` (sort key, **texto**) = de que tabla viene el registro. Ej.: `INFO_BASICA`,
  `UBICACION`. La combinacion `pk` + `sk` no se repite.

**Grano de cada tabla y `sk` propuesto** (grano recibido 2026-10-22; el `sk` es
propuesta para el equipo de desarrollo):

| Tabla | Llave de origen | Filas por persona | `sk` propuesto |
|---|---|---|---|
| `mat_info_basica` | `id` (la persona) | 1 | `INFO_BASICA` |
| `mat_info_ubicacion` | `id` = `cod_dw_persona_ubic` | N (una por ubicacion) | `UBICACION#<cod_dw_persona_ubic>` |
| `mat_info_actividad_economica` | CIIU | N | `ACTIVIDAD#<ciiu>` |
| `mat_ubicacion_agregada` | 7 columnas | N | `UBIC_AGREGADA#<codigodane>#<ciudad>#<departamento>#<dato>` |
| `mat_info_contactabilidad` | `(id, sector, ubicacion_id)` | N | `CONTACTABILIDAD#<sector>#<ubicacion_id>` |
| `mat_info_punto_interes` | `(id, ubicacion_id)` | N | `PUNTO_INTERES#<ubicacion_id>` |
| `mat_info_movilidad` | por evento | 0..N | `MOVILIDAD#<id del evento>` |

Consecuencias para desarrollo:
- Cada tabla debe traer (o unir en el `SELECT` del UNLOAD) el **tipo y numero de
  identificacion** de la persona para armar el `pk`.
- DELTA no borra: si una persona deja de tener una ubicacion, el registro viejo
  queda hasta el siguiente FULL.
- RecLineaCloud debe paginar la consulta por `pk` (DynamoDB devuelve maximo
  1 MB por pagina), sobre todo por movilidad (0..N eventos).
- Las columnas `pk` y `sk` las arma el `SELECT` del UNLOAD en las 7 tablas.
- Asi RecLineaCloud trae todo de una persona con una sola consulta, y los
  registros de una tabla no pisan a los de otra.

Regla de disparo (las dos cuentas): carpeta `nov/` + archivo que termina en
`7_tablas_finish.json`.

**Contenido de `7_tablas_finish.json`** (aprobado). Es el formato que ya lee la
Step Function Update RecMaster; la Step Function Upload usa la misma lista.

```json
{
  "run_id": "20261021T053000Z_FULL",
  "tipo_carga": "FULL",
  "fecha_fin": "2026-10-21T05:30:00Z",
  "dominios": [
    {
      "nombre": "mat_info_ubicacion",
      "s3_path": "s3://<bucket-triggers>/nov/20261021T053000Z_FULL/data/mat_info_ubicacion/",
      "registros_esperados": 125000
    }
  ]
}
```
(una entrada por cada una de las 7 tablas; `tipo_carga` = `FULL` o `DELTA`)

### 7.3 Conceptos

- **Archivo de control (CTL):** archivo pequeño que se escribe **al final** para
  avisar "ya termine". Es el unico que dispara los flujos. Sin el, se lanzaria
  una ejecucion por cada archivo del UNLOAD (el UNLOAD parte los datos en muchos
  archivos).
- **`manifest.json`:** nombre que se **supuso** en la IaC para el CTL. Se
  reemplaza por `7_tablas_finish.json`.
- **Update online:** la carga que actualiza Base_Online (DynamoDB), que es lo que
  consulta el API en linea.
- **Reenvio de eventos entre cuentas:** S3 solo avisa al EventBridge de su propia
  cuenta (147). Una regla en la 147 reenvia el evento al bus `default` de la
  cuenta Batch.
- **DynamoDB Import from S3:** carga masiva de archivos de S3 a DynamoDB, sin
  Glue. Dos limites importantes:
  - **Siempre crea una tabla nueva.** No puede cargar sobre una tabla existente.
  - Lee **CSV, DynamoDB JSON o Amazon Ion**. No lee Parquet.

### 7.4 Recomendaciones

- **Pausa / Resume de Redshift Reconocer: tiene sentido** por costos.
  - Pausarlo apenas termine el UNLOAD (el Glue, el Import y el COPY leen de S3,
    no de Reconocer).
  - **Decision 2026-10-28:** la pausa y el encendido se hacen **por otro medio**,
    fuera de esta IaC y de la Step Function Upload. No se crea rol para eso.
- **COPY en Redshift Bureau: role chaining** (ya preparado en `iam-redshift.tf`).
  Falta el ARN del rol del Redshift Bureau.
- **Sin control por tabla dentro de la carpeta de la tabla:** el Import de
  DynamoDB carga **todo** lo que haya en la carpeta; un archivo de control ahi
  se tomaria como datos. Los conteos por tabla van solo en `7_tablas_finish.json`.
  (Reemplaza la propuesta anterior de usar `MANIFEST VERBOSE` por tabla.)
- **Formato del UNLOAD: CSV con encabezado, comprimido (GZIP).** Es el unico
  formato que el UNLOAD de Redshift produce y que el Import de DynamoDB lee; sirve
  tambien para el Glue (DELTA) y el COPY de Bureau.
  - Alternativa: CSV + ZSTD (archivos mas pequeños; confirmar que el Glue lo lee).
  - Descartado Parquet: el Import no lo lee.
  - Descartado JSON: el UNLOAD genera JSON normal, no el "DynamoDB JSON" que pide
    el Import.
  - **Ojo con los tipos:** con CSV, el Import guarda todo como texto (salvo las
    llaves). El Glue (DELTA) debe escribir los mismos tipos que el FULL, para que
    la tabla no mezcle numeros y textos.
- **Borrado de la tabla anterior (FULL):** borrarla unos minutos despues de
  cambiar el puntero, no en el mismo instante, para no cortar consultas que aun
  la esten leyendo.
- **Etiquetas de las tablas creadas por el Import:** el Import no pone etiquetas
  al crear la tabla; hay que agregarlas despues (AppID, CostString, etc.) para
  cumplir las reglas de la cuenta.

### 7.5 Impacto de FULL / DELTA en el despliegue (cuenta 147)

**Desplegado en develop el 2026-10-28** (subtarea SLCOPRBA-1526; build 74994
mas el build de la correccion del API).

1. **Step Function Update RecMaster:** agregar una decision por `tipo_carga`:
   - `DELTA` → camino actual (Glue + Validation).
   - `FULL` → Import from S3 + esperar a que termine + etiquetar la tabla +
     Validation (con el conteo del Import) + cambiar el puntero en Metadata &
     Control + borrar la tabla anterior.
2. **Rol de la Step Function:** permisos para importar (`dynamodb:ImportTable`,
   `dynamodb:DescribeImport`), etiquetar y borrar tablas
   (`dynamodb:TagResource`, `dynamodb:DeleteTable`), leer el bucket Triggers y
   escribir los logs del Import. Validar con CE que el permissions boundary lo
   permite, porque el flujo **crea y borra tablas** en tiempo de ejecucion.
3. **Nombres de tablas DynamoDB:** `reconocer_master_<run_id>` (patron
   `reconocer_master_*`) y Metadata & Control `reconocer_metadata_control`
   (propuesta; se cambia en `develop/terraform.tfvars`). Los roles de
   RecLineaCloud, Glue y Validation quedan sobre ese patron. El rol de
   RecMicroservicios (existente) no es de este repo: su dueño debe darle lectura
   sobre el mismo patron.
4. **RecLineaCloud:** toma el nombre de la tabla vigente del puntero (parametro o
   Metadata & Control), no de una variable fija. Validation escribe el puntero.
5. **Validation → Upload_Staging:** escribe un reporte por tabla y un resumen en
   `validacion/<run_id>/` (aprobado 2026-10-22). Permiso `s3:PutObject` solo
   sobre `validacion/*` en `iam-lambda-validation.tf`: **desplegado**.
6. **EventBridge:** la regla dispara con `nov/*/7_tablas_finish.json` y una regla
   nueva (`dev-647096294147-rcncr-ws5-fwd-batch-event`, rol `evb-fwd-batch`)
   reenvia el mismo evento al bus `default` de la cuenta 651706752126.
7. **Rol COPY de Bureau:** se crea `redshift-copy-xacct` confiando solo en
   `BURoleFor-dev-651706752126-rcncr-ws5-redshift-bureau-copy` (lo crea el repo de
   la cuenta Batch, ver [Ticket 5](#ticket-5--iac-cuenta-batch-ritm5324186)).
8. **Borrado de la tabla anterior:** lo hace la Step Function (decision
   2026-10-27).
9. **Cuenta Batch:** decidir que hace el COPY en Bureau con FULL (¿borra y carga?)
   y con DELTA. Es del repo de la cuenta Batch.

### 7.6 Preguntas abiertas

**Para la IaC**

1. ~~¿Que proceso lanza hoy el calculo Reconocer?~~ Resuelto 2026-10-28: la
   pausa y el encendido del Redshift Reconocer se hacen por otro medio, fuera de
   la IaC.
2. ARN del rol IAM del Redshift Bureau (para el COPY).
3. ¿El Data Sharing Bureau → Reconocer ya existe o es parte de este trabajo?
4. Ambientes: ¿por ahora solo develop? ¿Que cuentas se usan en qa y produccion?

**Del diccionario de datos de las 7 tablas** (recibido 2026-10-22,
`DICCIONARIO_DATOS_7_TABLAS_DOMINIO.md`; tablas en `bdm_datos` de Redshift
Reconocer). Hallazgos que afectan la carga:

- Las 7 tablas son **foto completa** de cada corrida (`TRUNCATE` + `INSERT`).
- **d5 y d7 no traen tipo ni numero de identificacion**: el UNLOAD debe unirlas
  con d1. d5 se une por `ubicacion_id = d1.id` (1 persona). d7 se une por
  `ubicacion_id = d1.cod_dw_ubic`, que **puede ser de varias personas**: el join
  multiplica filas.
- La llave de d5 `(id, sector, ubicacion_id)` tiene `id` y `sector` siempre NULL:
  el `sk` solo puede usar `ubicacion_id`.
- d3: la ficha no dice cuales son sus 7 columnas de llave. Sus campos `id`,
  `tipo` y `fuente` son listas con comas (el CSV debe ir entre comillas).
- **NULL vs vacio importa** (d5: NULL = "no se sabe"; d4 `genero`: vacio, no
  NULL). El CSV no los distingue solo: hay que definir como se escribe el NULL
  en el UNLOAD y probarlo con el S3 Import.
- Las columnas `pk`/`sk` y las de join no existen en las tablas de Bureau: el
  COPY debe cargar a tablas temporales (staging) que si las tengan, y de ahi
  pasar a las tablas finales.

**Decisiones 2026-10-22**
- d7: **se duplica por persona** (opcion A). RecLineaCloud trae todo con una sola
  consulta por `pk`. En Bureau se quitan los duplicados en la tabla temporal.
- El UNLOAD **incluye** las 3 columnas de trazabilidad (`lote`,
  `fecha_actualizacion`, `usuario_bd`).
- Las tablas de Bureau **se llaman igual y tienen las mismas columnas** que las 7
  de Reconocer.
- Llave de d3 (2026-10-22): `info_basica`, `tipo_identificacion`,
  `numero_identificacion`, `ubicacion_dato`, `ubicacion_codigodane`,
  `ubicacion_ciudad`, `ubicacion_departamento`.

**Guia para desarrollo (UNLOAD, archivo final, DynamoDB y COPY a Bureau):**
[GUIA-UNLOAD-Y-CARGA.md](GUIA-UNLOAD-Y-CARGA.md).

**Diagrama de arquitectura (draw.io):**
[arquitectura-reconocer-linea.drawio](arquitectura-reconocer-linea.drawio)
(pagina 1: carga de datos; pagina 2: consumo en linea).

**Para el equipo de desarrollo** (se resuelven en sus HU; no bloquean la IaC)

1. ~~¿Varios registros por persona?~~ Resuelto con el grano de cada tabla (7.2).
   Validar el `sk` propuesto.
2. ~~¿El `id` es tipo + numero o un codigo interno?~~ Resuelto 2026-10-22: el
   `id` es **tipo + numero de identificacion**; el `pk` sale directo de el.
3. `mat_ubicacion_agregada`: ¿cuales son sus 7 columnas de llave y alguna
   identifica a la persona?
4. Glue / RecLineaCloud: ¿algun campo debe ser numero? Con CSV el Import guarda
   todo como texto; el Glue (DELTA) debe escribir los mismos tipos que el FULL.

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
| 2026-10-21 | Aprobadas carpetas y contenido del CTL. Nombres de las 7 tablas. `run_id` = timestamp + FULL/DELTA. FULL usa DynamoDB Import from S3, DELTA usa Glue: impacto en 7.5. |
| 2026-10-21 | Puntero en Metadata & Control (lo escribe Validation). Tabla anterior se borra tras FULL. DELTA solo nuevos y modificados (upsert). |
| 2026-10-22 | Aprobado: 7 tablas a una sola `reconocer_master`, datos en `nov/<run_id>/data/<tabla>/`, CTL un nivel arriba. El Import lo lanza nuestra Step Function. Formato del UNLOAD en decision (7.4). |
| 2026-10-22 | Aprobado CSV + GZIP. Llave de `reconocer_master`: tipo + numero de identificacion; propuesta `pk`/`sk` en 7.2. |
| 2026-10-22 | Aprobada la llave `pk` + `sk` (ambas texto). Preguntas de datos pasadas al equipo de desarrollo (7.6). |
| 2026-10-22 | Recibido el grano de las 7 tablas. `sk` propuesto por tabla (7.2). Sin impacto en la IaC. |
| 2026-10-22 | El `id` de las tablas es tipo + numero de identificacion. |
| 2026-10-22 | Revisado el diccionario de datos de las 7 tablas: hallazgos en 7.6. Sin impacto en la IaC. |
| 2026-10-22 | d7 duplicado por persona; UNLOAD con columnas de trazabilidad; tablas de Bureau iguales a las de Reconocer. Pendiente: llave de d3. |
| 2026-10-22 | Llave de d3 recibida. Creada la guia para desarrollo `docs/GUIA-UNLOAD-Y-CARGA.md`. |
| 2026-10-22 | Diagrama draw.io de la arquitectura: `docs/arquitectura-reconocer-linea.drawio`. |
| 2026-10-22 | Validation escribe en Upload_Staging segun el diagrama; hoy su rol solo lee ese bucket (7.5). |
| 2026-10-22 | Reporte de Validation en `validacion/<run_id>/`: permiso `s3:PutObject` agregado en la rama (pendiente de desplegar). |
| 2026-10-27 | Implementado en la rama: FULL con S3 Import, disparo con `7_tablas_finish.json`, reenvio a la cuenta Batch, tablas `reconocer_master_*` / `reconocer_metadata_control`, rol COPY para el rol de Bureau y borrado por la Step Function. Pendiente de desplegar. |
| 2026-10-27 | Ticket 5 (repo IaC de la cuenta Batch) redactado, por radicar. |
| 2026-10-27 | Radicado el repo de IaC de la cuenta Batch `TF_RCNCR_LINEA_WS5_BTCH_INFRA`: RITM5324186. |
| 2026-10-27 | Subtarea de despliegue en la 147: SLCOPRBA-1526, rama Bitbucket `feature/SLCOPRBA-1526-desplegar-la-iac-en-develop-cuenta-147`. |
| 2026-10-28 | HU SLCOPRBA-1525 (IaC Reconocer Linea cuenta 147: FULL/DELTA, CTL final y reenvio a cuenta Batch). Commit `3c94bee9aad` en Bitbucket, enlazado a su subtarea SLCOPRBA-1526. |
| 2026-10-28 | Build 74994: plan correcto (11 add, 10 change, 5 destroy). Apply aplico casi todo (Step Function FULL/DELTA, reglas EventBridge, roles nuevos, permisos, variables) y fallo solo en el deployment del API ("Provider produced inconsistent final plan" por el hash de `triggers`). Corregido: el hash usa solo atributos de configuracion. |
| 2026-10-28 | Build de la correccion (commit `SLCOPRBA-1526 Corrige triggers...`): SUCCESS. Plan 1 add, 1 change, 2 destroy: deployment nuevo `yyhd67`, stage `dev` apuntando a el, borrados el deployment viejo `zu5lcx` y el authorizer. **IaC de la cuenta 147 desplegada completa.** Wiz: PASSED_BY_POLICY. Jenkins no pudo comentar en Jira (sin permiso en la subtarea), no afecta el despliegue. |
| 2026-10-28 | Creado el checklist central por ambiente `docs/CHECKLIST-DESPLIEGUE.md` (DEV, QA, DEMO, PDN). |
| 2026-10-28 | Pausa / encendido del Redshift Reconocer: se hace por otro medio, no en la IaC ni en la Step Function Upload. No se crea rol. |
