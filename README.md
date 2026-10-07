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
