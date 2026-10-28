# Checklist de despliegue: Reconocer Master Linea

> **Documento central.** Aqui se ve, por ambiente, que ya se desplego, que falta
> y la traza de cada despliegue. Se actualiza **despues de cada build** (o de
> cada cambio hecho por fuera de la IaC).
>
> Ambientes: **DEV · QA · DEMO · PDN**.

## Indice

1. [Como leer y actualizar](#1-como-leer-y-actualizar)
2. [Ambientes y cuentas](#2-ambientes-y-cuentas)
3. [IaC cuenta Reconocer (este repo)](#3-iac-cuenta-reconocer-este-repo)
4. [IaC cuenta Batch (repo aparte)](#4-iac-cuenta-batch-repo-aparte)
5. [Codigo (repos de desarrollo)](#5-codigo-repos-de-desarrollo)
6. [Requisitos fuera de la IaC](#6-requisitos-fuera-de-la-iac)
7. [Ya existe: no se despliega](#7-ya-existe-no-se-despliega)
8. [Traza por ambiente](#8-traza-por-ambiente)

---

## 1. Como leer y actualizar

| Marca | Significa |
|---|---|
| ✅ | Desplegado y verificado |
| 🟡 | Desplegado, pero falta un dato o una configuracion (ver nota) |
| ⏳ | Pendiente |
| ⛔ | Bloqueado (ver nota) |
| ➖ | No aplica en ese ambiente |

Para actualizar despues de un build:
1. Cambiar la marca de cada componente afectado en la columna del ambiente.
2. Agregar una fila en la [traza](#8-traza-por-ambiente) con fecha, build,
   subtarea Jira y resultado.

---

## 2. Ambientes y cuentas

| | DEV | QA | DEMO | PDN |
|---|---|---|---|---|
| Carpeta en el repo | `develop/` | `qa/` | `demo/` | `production/` |
| Prefijo de nombres | `dev-<cuenta>-rcncr-ws5` | `qa-<cuenta>-rcncr-ws5` | `demo-<cuenta>-rcncr-ws5` | `prod-<cuenta>-rcncr-ws5` |
| Tag `Environment` | `dev` | `tst` | `uat` | `prd` |
| Cuenta Reconocer | `647096294147` | por definir | por definir | por definir |
| Cuenta Batch | `651706752126` | por definir | por definir | por definir |
| `terraform.tfvars` | ✅ | ⏳ | ⏳ | ⏳ |
| Ultimo build OK | 2026-10-28 (SLCOPRBA-1526) | — | — | — |

---

## 3. IaC cuenta Reconocer (este repo)

`TF_RCNCR_LINEA_WS5_INFRA`. Un rol por componente:
`BURoleFor-<prefijo>-<sufijo>`.

| # | Componente | Recurso | Archivo | DEV | QA | DEMO | PDN |
|---|---|---|---|---|---|---|---|
| 1 | S3 Triggers_reconocer | Bucket `-triggers-reconocer-s3` (avisa a EventBridge) | `s3.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 2 | S3 Upload_Staging | Bucket `-upload-staging-s3` | `s3.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 3 | EventBridge Update | Regla `-upd-recmaster-event` (`nov/*/7_tablas_finish.json`) | `eventbridge.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 4 | Reenvio a cuenta Batch | Regla `-fwd-batch-event` → bus `default` de la cuenta Batch | `eventbridge.tf` | 🟡 (1) | ⏳ | ⏳ | ⏳ |
| 5 | Step Function Update RecMaster | `-upd-recmaster-sfn` (FULL = S3 Import, DELTA = Glue) | `stepfunctions.tf` | 🟡 (2) | ⏳ | ⏳ | ⏳ |
| 6 | Glue RecMas_Transform_and_Upload | Job `-recmas-transform-upload` + database `-recmaster-glue` | `glue.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 7 | Lambda Validation | `-validation-lambda` (python3.13) | `lambda.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 8 | Lambda RecLineaCloud | `-reclineacloud-lambda` (java21) | `lambda.tf` | 🟡 (3) | ⏳ | ⏳ | ⏳ |
| 9 | Lambda Authorizer | `-authorizer-lambda` (python3.13) | `lambda.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 10 | API Int (Portal) | API PRIVATE, `GET /v1/sujetos/{tipo}/{numero}/reporte/{perfil}` | `apigateway.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 11 | API Ext (Apigee) | `POST /v1/microservicios/{operacion}` + authorizer Okta | `apigateway.tf` | ⏳ (4) | ⏳ | ⏳ | ⏳ |
| 12 | SQS Facturacion | `-facturacion.fifo` + DLQ | `sqs.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 12b | Lambda Facturacion | `-facturacion-lambda` (python3.13), la dispara la cola (1 mensaje por vez) | `lambda.tf`, `iam-lambda-facturacion.tf` | 🟡 (5) | ⏳ | ⏳ | ⏳ |
| 13 | Rol UNLOAD Redshift Reconocer | `-redshift-unload` | `iam-redshift.tf` | 🟡 (6) | ⏳ | ⏳ | ⏳ |
| 14 | Rol COPY Redshift Bureau | `-redshift-copy-xacct` (role chaining) | `iam-redshift.tf` | 🟡 (7) | ⏳ | ⏳ | ⏳ |
| 15 | Rol CloudWatch del API | `-apigw-cloudwatch` (uno por cuenta) | `iam-apigw-cloudwatch.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 16 | Lotes: bucket RecMasterLotes | `-recmasterlotes-s3`: `input/`, `plantillas/`, `output_raw/`, `output_zip/` (30 dias) | `lotes.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 17 | Lotes: EventBridge | `-lotes-event`: `.csv`/`.txt` nuevo en `input/<batch_id>/` → SFN Lotes | `lotes.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 18 | Lotes: SFN Lotes | `-lotes-sfn`: Parseo → RecLineaCloud por registro (5 a la vez, 10 % tolerado) → Consolidar; estado en Metadata & Control | `lotes.tf`, `iam-lotes.tf` | 🟡 (8) | ⏳ | ⏳ | ⏳ |
| 19 | Lotes: Lambda Parseo | `-parseo-lambda` (python3.13) | `lambda.tf`, `iam-lotes.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 20 | Lotes: Lambda Consolidar | `-consolidar-lambda` (python3.13) | `lambda.tf`, `iam-lotes.tf` | ✅ | ⏳ | ⏳ | ⏳ |
| 20b | Lotes: rol del Portal (on-premise) | `-portal-lotes`: sube a `input/`, lee el estado, descarga `output_zip/` | `iam-lotes.tf` | ⏳ (11) | ⏳ | ⏳ | ⏳ |
| 21 | RecLineaCloud → Validacion de identidad Cloud (otra cuenta) | Permiso `sts:AssumeRole` al rol cross-account de esa cuenta | `iam-lambda-reclineacloud.tf` | ⏳ (9) | ⏳ | ⏳ | ⏳ |
| 22 | CMK de KMS propia (S3, SQS, logs, Lambdas, tablas del Import) | `alias/<prefijo>-recmaster-kms` con `eits-tf-aws-kms` 1.10.5 | `kms.tf` | ✅ (10) | ⏳ | ⏳ | ⏳ |

Notas DEV:
1. La cuenta Batch debe permitir en su bus `default` que la 147 le envie
   eventos (`events:PutEvents`). Va en el repo de la cuenta Batch.
2. El FULL aun no se ha probado. Falta que CE confirme que el permissions
   boundary deja crear, etiquetar y borrar las tablas `reconocer_master_*`.
3. Falta confirmar el handler real y como se despliega el codigo Java
   (DevSecOps).
4. Se activa cuando se defina `recmicroservicios_function_name`. Al activarlo se
   crea tambien el authorizer.
5. Desplegada. Falta la URL del API de facturacion
   electronica (`facturacion_api_url`) y saber si ese API usa autenticacion IAM
   (`facturacion_api_execute_arn`). La Lambda se crea igual sin esos datos.
6. Falta asociar el rol al namespace del Redshift Reconocer.
7. Falta crear el rol de Bureau en la cuenta Batch. Cuando exista, la confianza
   se cambia al ARN exacto del rol (se quita el aviso Wiz IAM-146).
8. Flujo de Lotes desplegado. Contratos en
   [SOLICITUD, seccion 3.6](SOLICITUD-REPOS-DESARROLLO.md#36-flujo-de-lotes).
   La SFN Lotes funciona cuando Metadata & Control exista con llave `pk` + `sk`
   (texto) y el codigo de Parseo, Consolidar y RecLineaCloud (`pdf_s3`) este
   publicado.
9. Opcional, no creado aun. Falta el ARN del rol cross-account
   (`validacion_identidad_role_arn`). Esa cuenta debe confiar en
   `BURoleFor-<prefijo>-lmbd-reclineacloud`.
10. Desplegada: llave `ed5cee79-ab9e-48de-9953-57126ace5b2f`. S3, SQS, logs,
    Lambdas y la SFN Update usan la CMK (los objetos ya guardados quedan con su
    cifrado anterior).
11. Opcional: se crea cuando Operacion entregue la identidad AWS del Portal
    (`lotes_portal_principal_arns`).

---

## 4. IaC cuenta Batch (repo aparte)

`TF_RCNCR_LINEA_WS5_BTCH_INFRA` (RITM5324186). **Repo radicado, aun sin
codigo.**

| # | Componente | DEV | QA | DEMO | PDN |
|---|---|---|---|---|---|
| 1 | Policy del bus `default`: recibir eventos de la cuenta Reconocer | ⏳ | ⏳ | ⏳ | ⏳ |
| 2 | Regla EventBridge `7_tablas_finish.json` → Step Function Upload | ⏳ | ⏳ | ⏳ | ⏳ |
| 3 | Step Function Upload (COPY a staging + FULL/MERGE en Bureau) | ⏳ | ⏳ | ⏳ | ⏳ |
| 4 | Rol `-redshift-bureau-copy` asociado al cluster Bureau | ⏳ | ⏳ | ⏳ | ⏳ |
| 5 | Rol de la Step Function Upload | ⏳ | ⏳ | ⏳ | ⏳ |

---

## 5. Codigo (repos de desarrollo)

La IaC crea las Lambdas con un placeholder. El codigo real lo publica cada repo.

| Repo | Componente | Ticket | DEV | QA | DEMO | PDN |
|---|---|---|---|---|---|---|
| `A_RCNCR_LN_RCLNCLD` | RecLineaCloud (Java) | RITM5307356 | ⛔ (a) | ⏳ | ⏳ | ⏳ |
| `A_RCNCR_LN_ATHRZR` | Lambda Authorizer (Python) | RITM5307364 | ⏳ | ⏳ | ⏳ | ⏳ |
| `A_RCNCR_LN_VLDTN` | Validation (Python) | RITM5307368 | ⏳ | ⏳ | ⏳ | ⏳ |
| `A_RCNCR_LN_RCMS_TRNSFRM` | Glue (script en `glue-scripts/`) | RITM5307372 | ⏳ | ⏳ | ⏳ | ⏳ |
| Por pedir | Lambda Facturacion (Python) | — | ⏳ | ⏳ | ⏳ | ⏳ |
| Por pedir | Lambdas Lotes Parseo y Consolidar (Python) | — | ⏳ | ⏳ | ⏳ | ⏳ |
| UNLOAD Redshift Reconocer | SQL del UNLOAD y `7_tablas_finish.json` ([guia](GUIA-UNLOAD-Y-CARGA.md)) | — | ⏳ | ⏳ | ⏳ | ⏳ |

(a) DevSecOps no tiene plantilla LAMBDA-JAVA. Esperando su respuesta.

---

## 6. Requisitos fuera de la IaC

| # | Que | Responsable | DEV | QA | DEMO | PDN |
|---|---|---|---|---|---|---|
| 1 | Tabla DynamoDB Metadata & Control (`reconocer_metadata_control`) | Proceso externo de DynamoDB | ⏳ | ⏳ | ⏳ | ⏳ |
| 2 | Confirmar boundary: ImportTable / TagResource / DeleteTable | CE | ⏳ | ⏳ | ⏳ | ⏳ |
| 3 | Asociar rol `redshift-unload` al Redshift Reconocer | Admin del Redshift | ⏳ | ⏳ | ⏳ | ⏳ |
| 4 | URL y tipo de autenticacion del API de facturacion electronica | Equipo de Facturacion | ⏳ | ⏳ | ⏳ | ⏳ |
| 5 | Nombre de la Lambda RecMicroservicios (API Ext) | Dueno de RecMicroservicios | ⏳ | ⏳ | ⏳ | ⏳ |
| 6 | Lectura de `reconocer_master_*` para el rol de RecMicroservicios | Dueno de RecMicroservicios | ⏳ | ⏳ | ⏳ | ⏳ |
| 7 | Variables de Okta (issuer, audience) para el Authorizer | Desarrollo | ⏳ | ⏳ | ⏳ | ⏳ |
| 8 | Pausa y encendido del Redshift Reconocer: se hace por otro medio (decision 2026-10-28) | Fuera de la IaC | ➖ | ➖ | ➖ | ➖ |
| 9 | Permiso de `devsecops-sa-jenkins` para comentar en Jira (no bloquea) | Admin Jira | ⏳ | ⏳ | ⏳ | ⏳ |
| 10 | Permiso de los pipelines de los 4 repos para publicar codigo (`lambda:UpdateFunctionCode`, `s3:PutObject` en `glue-scripts/`) | DevSecOps | ⏳ | ⏳ | ⏳ | ⏳ |
| 11 | Validar con desarrollo el contrato de la Validation ([seccion 3.3](SOLICITUD-REPOS-DESARROLLO.md#33-a_rcncr_ln_vldtn--validation-python)) | Desarrollo | ⏳ | ⏳ | ⏳ | ⏳ |
| 12 | Re-ejecutar el build y ver "No changes" (confirma que la IaC quedo estable) | IaC | ⏳ | ⏳ | ⏳ | ⏳ |
| 13 | CMK de KMS: ver fila 22 de la seccion 3 | IaC | ➖ | ➖ | ➖ | ➖ |
| 14 | Opcional: SnapStart para RecLineaCloud (la libreria aun no lo soporta) | IaC | ⏳ | ⏳ | ⏳ | ⏳ |

---

## 7. Ya existe: no se despliega

Solo se referencian. No llevan marca por ambiente.

- Redshift Reconocer (cuenta Reconocer, provisionado).
- Redshift Bureau (cuenta Batch, no se puede pausar).
- Lambda RecMicroservicios.
- Orquesta-Facturacion y su API Gateway (cuenta de facturacion electronica).
- Tablas DynamoDB `reconocer_master_*`: las crea la Step Function en cada FULL.
- Fuera de alcance: ECR `/ContactDataStdr`.
- Secrets Manager: no se necesita (los APIs no usan usuario/clave ni API key, 2026-10-28).
- Fuera de alcance (2026-10-28): DR en us-west-2, motor de normalizacion de
  direcciones y su catalogo DIVIPOLA, Validacion 2.0 on-prem y ESB/DataPower.
  Las Lambdas no van en VPC.

---

## 8. Traza por ambiente

### DEV (cuentas 647096294147 / 651706752126)

| Fecha | Build | Jira | Resultado | Que cambio |
|---|---|---|---|---|
| 2026-10-20 | 74278–74280 | SLCOPRBA-1437 | ❌ | Ajustes de librerias, SCP de tags y API PRIVATE ([aprendizajes](APRENDIZAJES-DESPLIEGUE-LINEA.md)) |
| 2026-10-20 | 74281 | SLCOPRBA-1437 | ✅ | Primer despliegue completo: buckets, Lambdas, Glue, Step Function, EventBridge, API, SQS, roles |
| 2026-10-28 | 74994 | SLCOPRBA-1526 | ❌ parcial | FULL/DELTA, CTL `7_tablas_finish.json`, reenvio a cuenta Batch, roles COPY y fwd-batch, permisos. Fallo solo el deployment del API |
| 2026-10-28 | por confirmar | SLCOPRBA-1526 | ✅ | Correccion del deployment del API (`yyhd67`); authorizer retirado del API Int |
| 2026-10-28 | por confirmar | SLCOPRBA-1526 | ✅ | Lambda de Facturacion y su disparo desde la cola (ya estaban en AWS al correr el 75086) |
| 2026-10-28 | 75086 | SLCOPRBA-1526 | ❌ parcial | Plan 36 add / 24 change / 0 destroy. Creados: CMK, bucket RecMasterLotes, SFN Lotes, Lambdas Parseo y Consolidar, roles; S3, SQS, logs y Lambdas pasan a la CMK. Fallaron: regla EventBridge de Lotes (patron muy complejo) y la SFN Update (campo `SSESpecification`). Ademas los ARN de Parseo/Consolidar en IAM no coincidian con el nombre real. Corregido en la rama |
| 2026-10-28 | 75087 | SLCOPRBA-1526 | ❌ sin cambios | Plan correcto (2 add, 5 change, 0 destroy) pero fallo en el `plan` por el agente de Jenkins: una lectura quedo colgada 15 min y AWS rechazo la siguiente por `RequestTimeTooSkewed`. No se aplico nada; se relanza el build sin cambios |
| 2026-10-28 | por confirmar (relanzamiento del 75087) | SLCOPRBA-1526 | ✅ | Plan 2 add, 5 change, 0 destroy. Creados: regla EventBridge `-lotes-event` y su destino a la SFN Lotes. Actualizados: SFN Lotes (ARN correctos de Parseo/Consolidar), SFN Update (`SseSpecification` con la CMK) y las policies de Parseo, Consolidar y SFN Lotes. Wiz: PASSED_BY_POLICY. **CMK, Lotes y Facturacion desplegados en DEV** |

### QA

| Fecha | Build | Jira | Resultado | Que cambio |
|---|---|---|---|---|
| | | | | |

### DEMO

| Fecha | Build | Jira | Resultado | Que cambio |
|---|---|---|---|---|
| | | | | |

### PDN

| Fecha | Build | Jira | Resultado | Que cambio |
|---|---|---|---|---|
| | | | | |
