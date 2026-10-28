# Aprendizajes: despliegue de Reconocer Master Linea (cuenta 147)

> Lecciones de SLCOPRBA-1437: stack de consumo en linea desplegado self-service
> por Jenkins + Bitbucket + Terraform en `647096294147` (develop). Complementa a
> `docs/APRENDIZAJES-LIBRERIAS-Y-PERMISOS-IAM.md` del repo batch
> (`tf_rcncr_ws5_infra`): aqui solo lo nuevo.

---

## Historial de builds

| Build | Resultado | Causa | Solucion |
|---|---|---|---|
| 74278 | ❌ precondition | La libreria api-gateway espera el rol `BURoleForAPIGatewayCloudwatchGlobal`, que no existe en la cuenta | Rol propio `BURoleFor-dev-647096294147-rcncr-ws5-apigw-cloudwatch` (`iam-apigw-cloudwatch.tf`) |
| 74278 | ⚠️ warnings | Tag `Environment = develop` no es valido para las librerias | Mapa `env_tag` en `locals.tf` (develop=dev, qa=tst, demo=uat, production=prd) |
| 74279 | ❌ `iam:TagRole` explicit deny | Una SCP niega etiquetar roles con `eec:SourceIPException` | Sin ese tag; los buckets usan `disable_source_ip_check = true` |
| 74280 | ❌ `apigateway:PUT /restapis/{id}` AccessDenied | El rol de Jenkins solo crea/modifica APIs **PRIVATE** y la importacion OpenAPI de la libreria no llega como PRIVATE | API con recursos nativos (`apigateway.tf`) + bloques `moved` |
| 74281 | ✅ 17 add, 1 change, 1 destroy | — | API `bg2kuoleug` creado, el API a medio crear `f5n3zwmioc` eliminado |

---

## 1. Las librerias asumen recursos "globales" que no siempre existen

`eits-tf-aws-api-gateway` busca un rol de CloudWatch a nivel cuenta
(`BURoleForAPIGatewayCloudwatchGlobal`). En la 147 no existe. La configuracion de
API Gateway para logs es **una por cuenta y region** (`aws_api_gateway_account`):
si otro stack de la cuenta ya la gestiona, coordinar para no pisarse.

> Antes de usar una libreria, revisar sus `data` sources y `precondition`: ahi
> estan los recursos que da por hechos.

## 2. SCP sobre tags: un `explicit deny` no se arregla con permisos

`eec:SourceIPException` en un rol es una excepcion de seguridad controlada por
SCP. Ningun permiso del rol de Jenkins lo habilita. La alternativa permitida es
desactivar el check de IP **en el bucket** (`disable_source_ip_check`), que la
libreria marca con tag `eitsce:sourceipcheck=disabled` y un warning (no bloquea).

> "explicit deny in a service control policy" = decision de la organizacion. No
> buscar rodeos (ni roles intermedios para escalar): o se cambia el diseño o se
> pide la excepcion formal.

## 3. API Gateway: el rol de Jenkins solo permite APIs PRIVATE

La policy del rol de Jenkins condiciona API Gateway con
`apigateway:Request/EndpointType = PRIVATE` y
`apigateway:Resource/EndpointType = PRIVATE`. `PutRestApi` (importar OpenAPI)
no envia el tipo de endpoint en la peticion, asi que la condicion falla aunque
el API sea PRIVATE.

- Recursos nativos (`aws_api_gateway_resource`, `_method`, `_integration`,
  `_deployment`, `_stage`) **si** pasan: confirmado en 74281.
- Para cambiar de modulo a recursos nativos sin recrear: bloques `moved`
  (`module.api[0].X` → `X[0]`). Un recurso `tainted` se reemplaza igual.
- El API es privado: solo responde desde la VPC del endpoint
  `vpce-099b9bad5f18ee5a1` (URL con sufijo `-vpce-...` o DNS privado).

## 4. Lambdas sin subir codigo desde IaC

El pipeline valida "Lambda source code changes" y "Glue Python uploads to S3".
Las Lambdas se crean con un zip placeholder versionado (`trunk/placeholder/`),
sin `source_code_hash`, y cada repo de codigo publica con
`update-function-code`. Terraform no revierte el codigo en los siguientes builds.

## 5. Hallazgos que aparecen en cada build y no bloquean

- **Wiz INFO "S3 Bucket should have default encryption"**: falso positivo; los
  buckets tienen `aws_s3_bucket_server_side_encryption_configuration` (AES256)
  dentro de la libreria. Veredicto `PASSED_BY_POLICY`.
- **Serverless-010** (env vars sin CMK): se resuelve con `kms_key_arn`.
- **`restrict_access_to_approved_ips`**: consecuencia del punto 2.
- **Jira 400** al comentar: `devsecops-sa-jenkins` sin permiso de comentar en el
  issue. Es del proyecto Jira, no del repo.
- **`drs_rllbck` sin rollback**: informativo.

---

## Pendiente

Ver [CHECKLIST-DESPLIEGUE.md](CHECKLIST-DESPLIEGUE.md) (lista unica, mantenerla ahi).
