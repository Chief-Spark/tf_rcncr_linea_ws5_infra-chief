# Estructura del repositorio Terraform

Este repositorio organiza la infraestructura por ambientes y separa el codigo compartido de los valores especificos de cada entorno.

## Carpetas

### trunk/
Archivos Terraform compartidos entre todos los ambientes. Versiona aqui los recursos comunes, por ejemplo:
- Archivos .tf de Lambdas, policies IAM, buckets S3 y modulos reutilizables
- Archivos base como provider.tf, backend.tf y variables.tf

Antes de cada despliegue, el pipeline copia el contenido de trunk/ hacia la carpeta del ambiente correspondiente.

### develop/, qa/, demo/, production/
Cada carpeta representa un ambiente de despliegue. Manten en cada una el archivo terraform.tfvars con los valores de las variables de ese ambiente (account_id, region, tags, nombres de recursos, etc.).

Los archivos .tf dentro de estas carpetas provienen de trunk/ durante el pipeline. Evita editarlos directamente en la carpeta del ambiente; realiza los cambios en trunk/.

## Flujo de trabajo

1. Desarrolla y versiona los cambios de infraestructura en trunk/.
2. Define o actualiza las variables de cada ambiente en <ambiente>/terraform.tfvars.
3. El job de Jenkins ejecuta `cp -r trunk/* <ambiente>/` en before_deploy y luego corre terraform dentro de la carpeta del ambiente.

## Documentacion de referencia

- [TERRAFORM - Proceso de versionamiento y despliegue](https://pages.experian.local/spaces/GDLC/pages/1235654713/TERRAFORM+-+Proceso+de+versionamiento+y+despliegue)
- [Nomenclaturas para la Region SPLatam](https://pages.experian.local/spaces/ESCCFT/pages/1903352398/Nomenclaturas+para+la+Regi%C3%B3n+SPLatam)

## Stack actual: Reconocer Master Linea (cuenta 147 = `647096294147`)

Solo IaC: el codigo de Lambdas y Glue vive en otros repos y este repo **no sube
archivos** (.py, .zip). **No** se despliegan aqui las tablas DynamoDB
(Base_Online / Metadata & Control, se crean por otro proceso), la Lambda
RecMicroservicios (existente) ni la Lambda de Facturacion (vive en otra cuenta):
solo se referencian por nombre o ARN (`dynamodb.tf`, `existing.tf`). Todos esos
valores son opcionales: si estan vacios se omite el permiso o la ruta asociada.

### Componentes

| Archivo | Componente | Libreria |
|---|---|---|
| `s3.tf` | Buckets Triggers_reconocer (notifica a EventBridge) y Upload_Staging | `eits-tf-aws-s3` 2.19.2 |
| `sqs.tf` | SQS FIFO de facturacion + DLQ (consumidor cross-account) | nativo |
| `lambda.tf` | Lambdas Authorizer, RecLineaCloud y Validation | `eits-tf-aws-lambda` 1.11.2 |
| `apigateway.tf` | API REST privado: Int -> RecLineaCloud, Ext -> RecMicroservicios | nativo (ver nota) |
| `glue.tf` | Glue Job RecMas_Transform_and_Upload | `eits-tf-aws-glue` 1.5.1 |
| `stepfunctions.tf` | Step Function Update RecMaster (Distributed Map) | nativo |
| `eventbridge.tf` | Regla EventBridge Update (manifiesto -> Step Function) | `eits-tf-aws-eventbridge` 2.7.0 |
| `iam-*.tf` | Un rol por componente | `eits-tf-aws-iam` 1.9.7 |
| `iam-apigw-cloudwatch.tf` | Rol de CloudWatch de API Gateway (configuracion a nivel cuenta) | `eits-tf-aws-iam` 1.9.7 |
| `iam-redshift.tf` | Roles de Redshift: UNLOAD (Reconocer) y COPY cross-account por role chaining (Bureau) | `eits-tf-aws-iam` 1.9.7 |

Las librerias exigen AWS provider 6.x (`provider.tf`: `~> 6.48`).

### Nomenclatura
`name_prefix = <stage>-<accountId>-<project>` -> `dev-647096294147-rcncr-ws5`.

- Roles: `BURoleFor-dev-647096294147-rcncr-ws5-<sufijo>`. Se crean con
  `eits-tf-aws-iam` (guion inicial en `role_name`) y se pasan a cada libreria,
  porque los roles que crean las librerias no siguen esta nomenclatura.
- Los nombres de recursos que arman las librerias (`-lambda`, `-s3`, `-event`,
  `-api`) se replican en `locals.tf`, para que los roles apunten a ARNs
  deterministicos.

### API Gateway con recursos nativos
`eits-tf-aws-api-gateway` solo hace rutas anidadas importando OpenAPI
(`PutRestApi`). El rol de Jenkins solo puede crear/modificar APIs PRIVATE
(condicion `apigateway:Request/EndpointType`) y esa importacion no llega como
PRIVATE: build 74280 fallo con AccessDenied en `apigateway:PUT /restapis/{id}`.
`apigateway.tf` replica lo que hacia la libreria (API PRIVATE por el VPC endpoint
e-Connect v3, resource policy, client certificate, rol de CloudWatch de la
cuenta, un stage) con recursos nativos y las rutas anidadas del HLD.

### Tag Environment
Las librerias solo aceptan `dev, prd, sbx, stg, tst, uat` (api-gateway usa `prd`
para elegir los VPC endpoints de produccion). `locals.tf` mapea: develop=dev,
qa=tst, demo=uat, production=prd.

### Codigo de las Lambdas (placeholder)
Las Lambdas se crean con `trunk/placeholder/lambda-placeholder.zip` (ver su README)
y el pipeline de cada repo de codigo publica la version real con
`aws lambda update-function-code`. Reparto de responsabilidades:

| Que | Donde |
|---|---|
| Codigo de la Lambda | Repo de codigo (su pipeline) |
| runtime, handler, memoria, timeout, concurrencia, env vars, rol, VPC | Este repo (`lambda.tf`, `var.lambdas`) |

Defaults: RecLineaCloud `java21` (HLD, ADR-08); Authorizer y Validation
`python3.13` con `handler.lambda_handler`. El handler de RecLineaCloud es
provisional: confirmarlo con desarrollo.

### Bucket policy de eits-tf-aws-s3
La libreria niega el acceso a S3 fuera de IPs de Experian / VPC endpoints. Glue,
la Step Function, la Lambda Validation y Redshift llaman a S3 desde la red de
AWS, por eso nuestros buckets usan `disable_source_ip_check = true`
(`s3_disable_source_ip_check`); se mantienen HTTPS/TLS 1.2 y el control por IAM.
El tag `eec:SourceIPException` en los roles NO es opcion: una SCP niega
`iam:TagRole` con ese tag (build 74279).

### Estado del despliegue (develop)
Build 74281 OK: todos los componentes creados. API `bg2kuoleug` (PRIVATE), stage
`dev`; desde la VPC del endpoint:
`https://bg2kuoleug-vpce-099b9bad5f18ee5a1.execute-api.us-east-1.amazonaws.com/dev`.
Las Lambdas siguen con el placeholder, asi que toda llamada al API falla hasta
publicar el codigo real. Historial de builds y lecciones:
[docs/APRENDIZAJES-DESPLIEGUE-LINEA.md](docs/APRENDIZAJES-DESPLIEGUE-LINEA.md).

### Pendiente
- Re-ejecutar el build y confirmar que el plan sale "No changes" (idempotencia).
- Nombres de las tablas DynamoDB (sin ellos los roles se crean sin acceso a DynamoDB).
- Asociar el rol `redshift-unload` al namespace del Redshift Reconocer (lo hace quien administra el namespace).
- ARN del rol IAM del Redshift Bureau (`redshift_bureau_role_arn`) y, en su cuenta, `sts:AssumeRole` sobre `redshift-copy-xacct`.
- ARN del rol consumidor de facturacion (otra cuenta).
- Handler real de RecLineaCloud (y runtime/handler de las Python si difieren del default).
- Permiso `lambda:UpdateFunctionCode` para el pipeline de cada repo de codigo.
- Nombre de la Lambda RecMicroservicios (ruta Ext del API).
- SnapStart para RecLineaCloud: la libreria eits-tf-aws-lambda aun no lo soporta.
- Script del Glue publicado por su repo en `s3://<upload-staging>/glue-scripts/` (o `glue_script_location`).
- Definicion de la Step Function: borrador segun el HLD, validar con desarrollo.
- CMK de KMS (`kms_key_arn`), opcional: quita el warning Wiz Serverless-010 de las env vars de las Lambdas.
- Permiso de `devsecops-sa-jenkins` para comentar en el issue Jira (hoy falla el comentario automatico de Wiz/despliegue; no bloquea).
- Repetir el despliegue en qa / demo / production (`terraform.tfvars` de cada ambiente).
