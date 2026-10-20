# Rol de RecLineaCloud: consulta Base_Online + puntero de version en Control,
# publica el mensaje de facturacion (SQS FIFO) y, en modo pdf_s3, escribe el PDF.
data "aws_iam_policy_document" "lambda_reclineacloud" {
  source_policy_documents = [
    data.aws_iam_policy_document.lambda_base["reclineacloud"].json,
    data.aws_iam_policy_document.kms_use.json
  ]

  statement {
    sid       = "ReadBaseOnline"
    actions   = ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:DescribeTable"]
    resources = [local.dynamodb_reconocer_master_arn, "${local.dynamodb_reconocer_master_arn}/index/*"]
  }

  statement {
    sid       = "ReadControl"
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [local.dynamodb_metadata_control_arn]
  }

  statement {
    sid       = "SendFacturacion"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    resources = [local.arns.sqs_facturacion]
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
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.1"

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
