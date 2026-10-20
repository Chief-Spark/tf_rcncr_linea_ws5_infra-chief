# Rol de la Lambda Validation: verifica conteos/hash del staging contra el
# manifiesto y promueve active_run_id en la tabla de Control.
data "aws_iam_policy_document" "lambda_validation" {
  source_policy_documents = [
    data.aws_iam_policy_document.lambda_base["validation"].json,
    data.aws_iam_policy_document.kms_use.json
  ]

  statement {
    sid       = "ReadBuckets"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [local.arns.s3_staging, "${local.arns.s3_staging}/*", local.arns.s3_triggers, "${local.arns.s3_triggers}/*"]
  }

  statement {
    sid       = "ReadBaseOnline"
    actions   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:DescribeTable"]
    resources = [local.dynamodb_reconocer_master_arn]
  }

  statement {
    sid = "WriteControl"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:ConditionCheckItem"
    ]
    resources = [local.dynamodb_metadata_control_arn]
  }
}

module "lambda_validation_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-lmbd-validation" # BURoleFor-dev-647096294147-rcncr-ws5-lmbd-validation
  role_description     = "Role for the RecMaster Validation Lambda"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json

  policy_name        = "-${local.name_prefix}-lmbd-validation" # BUPolicyFor-dev-647096294147-rcncr-ws5-lmbd-validation
  policy_description = "S3 staging read and Control table write for the Validation Lambda"
  policy_documents   = [data.aws_iam_policy_document.lambda_validation.json]

  tags = merge(local.default_tags, local.s3_exception_tags)
}
