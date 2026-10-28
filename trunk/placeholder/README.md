# Paquete placeholder de las Lambdas

`lambda-placeholder.zip` es el paquete con el que Terraform **crea** las Lambdas
(Authorizer, RecLineaCloud, Validation y Facturacion). Se envia directo en `CreateFunction`:
no se sube nada a S3.

El codigo real vive en los repos de codigo y su pipeline lo publica con
`aws lambda update-function-code`. Terraform no lo revierte en los siguientes
builds (no se fija `source_code_hash`).

Contenido del zip: un unico `handler.py` cuyo `lambda_handler` lanza
`RuntimeError("Codigo pendiente de despliegue ...")`. Mientras una Lambda tenga
el placeholder, toda invocacion falla; en el Authorizer eso significa que el
API niega el acceso.

No cambiar la ruta ni el nombre del zip (`filename` en `lambda.tf`): Terraform
lo tomaria como un cambio de codigo y volveria a subir el placeholder encima
del codigo real.
