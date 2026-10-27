# Rol de la Step Function "Update RecMaster". DELTA: Distributed Map, Glue por
# tabla y Lambda Validation. FULL: S3 Import a una tabla nueva, Validation y
# borrado de la tabla anterior.
data "aws_iam_policy_document" "sfn_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sfn_updrecmaster" {
  source_policy_documents = [data.aws_iam_policy_document.kms_use.json]

  statement {
    sid       = "RunGlueJob"
    actions   = ["glue:StartJobRun", "glue:GetJobRun", "glue:GetJobRuns", "glue:BatchStopJobRun"]
    resources = [local.arns.glue_transform]
  }

  statement {
    sid       = "InvokeValidation"
    actions   = ["lambda:InvokeFunction"]
    resources = [local.arns.lambda_validation, "${local.arns.lambda_validation}:*"]
  }

  # Distributed Map: la SFN arranca ejecuciones hijas de si misma.
  statement {
    sid       = "DistributedMapStart"
    actions   = ["states:StartExecution"]
    resources = [local.arns.sfn_updrecmaster]
  }

  statement {
    sid       = "DistributedMapManage"
    actions   = ["states:DescribeExecution", "states:StopExecution"]
    resources = [local.arns.sfn_executions, local.arns.sfn_map_runs]
  }

  # ItemReader (manifiesto) y ResultWriter.
  statement {
    sid       = "ReadTriggers"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [local.arns.s3_triggers, "${local.arns.s3_triggers}/*"]
  }

  statement {
    sid       = "WriteStagingResults"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:ListMultipartUploadParts", "s3:AbortMultipartUpload"]
    resources = [local.arns.s3_staging, "${local.arns.s3_staging}/*"]
  }

  # FULL: el S3 Import crea la tabla <prefijo><run_id>; la Step Function la
  # etiqueta y, validada la carga, borra la anterior. Solo tablas con el prefijo.
  dynamic "statement" {
    for_each = local.has_master_table
    content {
      sid = "ImportMasterTables"
      actions = [
        "dynamodb:ImportTable",
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:TagResource",
        "dynamodb:DeleteTable"
      ]
      resources = [local.dynamodb_master_tables_arn]
    }
  }

  dynamic "statement" {
    for_each = local.has_master_table
    content {
      sid       = "DescribeImports"
      actions   = ["dynamodb:DescribeImport"]
      resources = ["${local.dynamodb_master_tables_arn}/import/*"]
    }
  }

  # Logs que escribe el S3 Import en CloudWatch.
  statement {
    sid = "ImportLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy"
    ]
    resources = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws-dynamodb/*"]
  }

  statement {
    sid = "LogsDelivery"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "XRay"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords", "xray:GetSamplingRules", "xray:GetSamplingTargets"]
    resources = ["*"]
  }
}

module "sfn_updrecmaster_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-sfn-updrecmaster" # BURoleFor-dev-647096294147-rcncr-ws5-sfn-updrecmaster
  role_description     = "Role for the Update RecMaster Step Function (Distributed Map)"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.sfn_assume_role.json

  policy_name        = "-${local.name_prefix}-sfn-updrecmaster" # BUPolicyFor-dev-647096294147-rcncr-ws5-sfn-updrecmaster
  policy_description = "Glue, Lambda, S3 and DynamoDB import access for the Update RecMaster Step Function"
  policy_documents   = [data.aws_iam_policy_document.sfn_updrecmaster.json]

  tags = merge(local.default_tags, local.s3_exception_tags)
}
