# Las tablas DynamoDB NO se crean con Terraform:
# - Metadata & Control la crea otro proceso.
# - reconocer_master: en FULL la crea la Step Function con el S3 Import, una
#   tabla nueva por corrida (<prefijo><run_id>); la vigente la indica el puntero
#   de Metadata & Control.
# Aqui solo se arman los ARN para los permisos de los roles.
locals {
  # Patron: todas las tablas reconocer_master de cualquier corrida.
  dynamodb_master_tables_arn    = "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamodb_reconocer_master_prefix}*"
  dynamodb_metadata_control_arn = "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamodb_metadata_control_table}"

  # [1] si hay nombre/prefijo, [] si no: para dynamic "statement".
  has_master_table  = var.dynamodb_reconocer_master_prefix != "" ? [1] : []
  has_control_table = var.dynamodb_metadata_control_table != "" ? [1] : []

  # Variables de entorno / argumentos solo con las tablas definidas.
  dynamodb_env = merge(
    var.dynamodb_reconocer_master_prefix != "" ? { TABLE_MASTER_PREFIX = var.dynamodb_reconocer_master_prefix } : {},
    var.dynamodb_metadata_control_table != "" ? { TABLE_CONTROL = var.dynamodb_metadata_control_table } : {}
  )
}
