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

Despliega solo IaC (el codigo de Lambdas y Glue vive en otros repos) de los
componentes del HLD *Reconocer Master Cloud - Consumo en linea* marcados para
este repo. Las tablas DynamoDB (Base_Online / Metadata & Control) **no** se
crean aqui: se referencian por nombre (`dynamodb.tf`).

### Nomenclatura
`name_prefix = <stage>-<accountId>-<project>` -> `dev-647096294147-rcncr-ws5`.
Los roles se crean con `eits-tf-aws-iam` (`?ref=1.9.1`, Terraform >= 1.9) pasando
`role_name` con guion inicial, lo que produce `BURoleFor-dev-647096294147-rcncr-ws5-<sufijo>`.

### Roles (fase 1)

| Archivo | Rol (sufijo) | Componente |
|---|---|---|
| `iam-lambda-authorizer.tf` | `lmbd-authorizer` | Lambda Authorizer (Okta) |
| `iam-lambda-reclineacloud.tf` | `lmbd-reclineacloud` | Lambda RecLineaCloud |
| `iam-lambda-facturacion.tf` | `lmbd-facturacion` | Lambda Facturacion (consume SQS FIFO) |
| `iam-lambda-validation.tf` | `lmbd-validation` | Lambda Validation |
| `iam-glue-transform.tf` | `glue-transform` | Glue Job RecMas_Transform_and_Upload |
| `iam-sfn-updrecmaster.tf` | `sfn-updrecmaster` | Step Function Update RecMaster (Distributed Map) |
| `iam-evb-updrecmaster.tf` | `evb-updrecmaster` | Regla EventBridge Update |

Los roles apuntan a ARNs deterministicos (`locals.tf` -> `names` / `arns`), asi
que se pueden crear antes que los recursos.

### Pendiente
- Nombres de las tablas DynamoDB en `develop/terraform.tfvars` (el plan falla sin ellos).
- CMK (KMS), VPC de Lambdas y bucket de salida de PDFs (variables opcionales).
- Recursos: API Gateway, Lambdas, SQS FIFO + DLQ, S3, EventBridge, Glue Job y
  Step Function (segun las librerias que se confirmen).
