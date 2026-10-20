# Rol del Glue Job RecMas_Transform_and_Upload: lee el Parquet publicado en
# Triggers_reconocer, escribe el resultado validado en Upload_Staging y hace el
# BatchWriteItem hacia Base_Online.
data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "glue_transform" {
  source_policy_documents = [data.aws_iam_policy_document.kms_use.json]

  statement {
    sid       = "ReadTriggers"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [local.arns.s3_triggers, "${local.arns.s3_triggers}/*"]
  }

  statement {
    sid       = "ReadWriteStaging"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [local.arns.s3_staging, "${local.arns.s3_staging}/*"]
  }

  statement {
    sid       = "WriteBaseOnline"
    actions   = ["dynamodb:BatchWriteItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DescribeTable"]
    resources = [local.dynamodb_reconocer_master_arn]
  }

  statement {
    sid     = "Logs"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws-glue/*",
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws-glue/*:*"
    ]
  }

  statement {
    sid       = "Metrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["Glue"]
    }
  }
}

module "glue_transform_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.1"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-glue-transform" # BURoleFor-dev-647096294147-rcncr-ws5-glue-transform
  role_description     = "Role for the RecMas_Transform_and_Upload Glue job"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.glue_assume_role.json

  policy_name        = "-${local.name_prefix}-glue-transform" # BUPolicyFor-dev-647096294147-rcncr-ws5-glue-transform
  policy_description = "S3 read/write and DynamoDB Base_Online write for the transform Glue job"
  policy_documents   = [data.aws_iam_policy_document.glue_transform.json]

  tags = local.default_tags
}
