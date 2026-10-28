# Rol de RecLineaCloud: consulta Base_Online + puntero de version en Control,
# valida identidad (rol cross-account), publica el mensaje de facturacion (SQS
# FIFO) y, en Lotes (modo pdf_s3), lee plantillas/ y escribe el PDF en output_raw/.
data "aws_iam_policy_document" "lambda_reclineacloud" {
  source_policy_documents = [
    data.aws_iam_policy_document.lambda_base["reclineacloud"].json,
    data.aws_iam_policy_document.kms_use.json
  ]

  dynamic "statement" {
    for_each = local.has_master_table
    content {
      sid       = "ReadBaseOnline"
      actions   = ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:DescribeTable"]
      resources = [local.dynamodb_master_tables_arn, "${local.dynamodb_master_tables_arn}/index/*"]
    }
  }

  dynamic "statement" {
    for_each = local.has_control_table
    content {
      sid       = "ReadControl"
      actions   = ["dynamodb:GetItem", "dynamodb:Query"]
      resources = [local.dynamodb_metadata_control_arn]
    }
  }

  statement {
    sid       = "SendFacturacion"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    resources = [local.arns.sqs_facturacion]
  }

  dynamic "statement" {
    for_each = var.enable_lotes ? [1] : []
    content {
      sid       = "ReadPlantillasLotes"
      actions   = ["s3:GetObject"]
      resources = ["${local.arns.s3_lotes}/plantillas/*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_lotes ? [1] : []
    content {
      sid       = "WritePdfLotes"
      actions   = ["s3:PutObject"]
      resources = ["${local.arns.s3_lotes}/output_raw/*"]
    }
  }

  # Validacion de identidad: API de otra cuenta AWS, con su rol cross-account.
  dynamic "statement" {
    for_each = var.validacion_identidad_role_arn == "" ? [] : [1]
    content {
      sid       = "AssumeValidacionIdentidad"
      actions   = ["sts:AssumeRole"]
      resources = [var.validacion_identidad_role_arn]
    }
  }

  dynamic "statement" {
    for_each = var.reclinea_output_bucket == "" ? [] : [1]
    content {
      sid       = "WritePdfOutput"
      actions   = ["s3:PutObject"]
      resources = ["arn:aws:s3:::${var.reclinea_output_bucket}/*"]
    }
  }
}

module "lambda_reclineacloud_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-lmbd-reclineacloud" # BURoleFor-dev-647096294147-rcncr-ws5-lmbd-reclineacloud
  role_description     = "Role for the RecLineaCloud Lambda (online consumption)"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json

  policy_name        = "-${local.name_prefix}-lmbd-reclineacloud" # BUPolicyFor-dev-647096294147-rcncr-ws5-lmbd-reclineacloud
  policy_description = "DynamoDB read, SQS billing publish and PDF output for RecLineaCloud"
  policy_documents   = [data.aws_iam_policy_document.lambda_reclineacloud.json]

  tags = local.default_tags
}
