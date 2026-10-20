# Rol de la Lambda de Facturacion: consume la cola SQS FIFO de facturacion.
data "aws_iam_policy_document" "lambda_facturacion" {
  source_policy_documents = [
    data.aws_iam_policy_document.lambda_base["facturacion"].json,
    data.aws_iam_policy_document.kms_use.json
  ]

  statement {
    sid = "ConsumeFacturacion"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes"
    ]
    resources = [local.arns.sqs_facturacion]
  }
}

module "lambda_facturacion_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.1"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-lmbd-facturacion" # BURoleFor-dev-647096294147-rcncr-ws5-lmbd-facturacion
  role_description     = "Role for the billing Lambda (SQS FIFO consumer)"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json

  policy_name        = "-${local.name_prefix}-lmbd-facturacion" # BUPolicyFor-dev-647096294147-rcncr-ws5-lmbd-facturacion
  policy_description = "SQS consume for the billing Lambda"
  policy_documents   = [data.aws_iam_policy_document.lambda_facturacion.json]

  tags = local.default_tags
}
