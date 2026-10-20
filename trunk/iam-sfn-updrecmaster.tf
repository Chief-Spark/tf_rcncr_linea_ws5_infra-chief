# Rol de la Step Function "Update RecMaster" (Distributed Map, una rama por
# dominio). Lanza el Glue Job por rama, invoca la Lambda Validation y registra
# el estado de la corrida en la tabla de Control.
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

  statement {
    sid       = "ControlTable"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [local.dynamodb_metadata_control_arn]
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
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.1"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-sfn-updrecmaster" # BURoleFor-dev-647096294147-rcncr-ws5-sfn-updrecmaster
  role_description     = "Role for the Update RecMaster Step Function (Distributed Map)"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.sfn_assume_role.json

  policy_name        = "-${local.name_prefix}-sfn-updrecmaster" # BUPolicyFor-dev-647096294147-rcncr-ws5-sfn-updrecmaster
  policy_description = "Glue, Lambda, S3 and Control table access for the Update RecMaster Step Function"
  policy_documents   = [data.aws_iam_policy_document.sfn_updrecmaster.json]

  tags = local.default_tags
}
