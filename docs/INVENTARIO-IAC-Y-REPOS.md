# Inventario: IaC desplegada y repos de desarrollo

> Stack Reconocer Master Linea (SLCOPRBA-1437). Lo que este repo
> (`COAWSPPR/TF_RCNCR_LINEA_WS5_INFRA`) crea en la cuenta `647096294147` y, al
> lado, el repo de desarrollo que publica el codigo de cada componente.
>
> Nombres en develop (build 74281). En otros ambientes cambia el prefijo:
> `<stage>-<accountId>-rcncr-ws5` con stage = `dev`, `qa`, `demo`, `prod`.
>
> Textos de los tickets de creacion de repos:
> [SOLICITUD-REPOS-DESARROLLO.md](SOLICITUD-REPOS-DESARROLLO.md).

---

## 1. Componentes y repo responsable

| # | Componente (HLD) | Recurso AWS desplegado (develop) | Archivo IaC | Rol IAM | Repo de desarrollo | Ticket |
|---|---|---|---|---|---|---|
| 1 | RecLineaCloud | Lambda `dev-647096294147-rcncr-ws5-reclineacloud-lambda` (java21) | `lambda.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-lmbd-reclineacloud` | `A_RCNCR_LN_RCLNCLD` (AWS – LAMBDA-JAVA) | RITM5307356 (creado) |
| 2 | Lambda Authorizer (Okta) | Lambda `dev-647096294147-rcncr-ws5-authorizer-lambda` (python3.13) | `lambda.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-lmbd-authorizer` | `A_RCNCR_LN_ATHRZR` (AWS – LAMBDA-ZIP) | RITM5307364 (creado) |
| 3 | Validation | Lambda `dev-647096294147-rcncr-ws5-validation-lambda` (python3.13) | `lambda.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-lmbd-validation` | `A_RCNCR_LN_VLDTN` (AWS – LAMBDA-ZIP) | RITM5307368 (creado) |
| 4 | RecMas_Transform_and_Upload | Glue Job `dev-647096294147-rcncr-ws5-recmas-transform-upload` (Glue 5.0) | `glue.tf` | `BURoleFor-dev-647096294147-rcncr-ws5-glue-transform` | `A_RCNCR_LN_RCMS_TRNSFRM` (AWS – GLUE-PYTHON) | RITM5307372 (creado) |
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
  PRIVATE, solo entra por el VPC endpoint).
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
  cuando se configura `recmicroservicios_function_name`.
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

### Manifiesto que dispara la carga
Un objeto que termina en `manifest.json` en el bucket Triggers dispara
EventBridge → Step Function. Formato esperado (borrador del HLD, validar):

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
2. El nombre del recurso por ambiente (tabla de la seccion 1, cambiando el stage).
3. Mientras no publiquen, la Lambda corre el placeholder y falla en cada
   invocacion (el API devuelve error).
