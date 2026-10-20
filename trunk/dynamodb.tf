# Las tablas DynamoDB NO se crean en este repo (se crean por otro proceso).
# Solo se usan sus nombres para dar permisos a los roles. Si un nombre esta
# vacio, los roles se crean sin acceso a esa tabla (se agrega despues).
locals {
  dynamodb_reconocer_master_arn = "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamodb_reconocer_master_table}"
  dynamodb_metadata_control_arn = "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamodb_metadata_control_table}"

  # [1] si hay nombre de tabla, [] si no: para dynamic "statement".
  has_master_table  = var.dynamodb_reconocer_master_table != "" ? [1] : []
  has_control_table = var.dynamodb_metadata_control_table != "" ? [1] : []

  # Variables de entorno / argumentos solo con las tablas definidas.
  dynamodb_env = merge(
    var.dynamodb_reconocer_master_table != "" ? { TABLE_BASE_ONLINE = var.dynamodb_reconocer_master_table } : {},
    var.dynamodb_metadata_control_table != "" ? { TABLE_CONTROL = var.dynamodb_metadata_control_table } : {}
  )
}
