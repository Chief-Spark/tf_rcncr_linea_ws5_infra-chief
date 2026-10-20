# Las tablas DynamoDB NO se crean en este repo (las gestiona otro repo de infra).
# Se referencian por nombre con ARNs deterministicos, asi los roles se pueden
# crear aunque las tablas todavia no existan.
locals {
  dynamodb_reconocer_master_arn = "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamodb_reconocer_master_table}"
  dynamodb_metadata_control_arn = "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamodb_metadata_control_table}"
}
