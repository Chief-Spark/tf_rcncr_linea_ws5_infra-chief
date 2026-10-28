# Roles del flujo de Lotes (lotes.tf). Uno por componente.

# --- EventBridge Lotes: archivo nuevo en input/ -> Step Function Lotes ---
data "aws_iam_policy_document" "evb_lotes" {
  statement {
    sid       = "StartSfnLotes"
    actions   = ["states:StartExecution"]
    resources = [local.arns.sfn_lotes]
  }
}

module "evb_lotes_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = local.lotes_enabled

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-evb-lotes" # BURoleFor-dev-647096294147-rcncr-ws5-evb-lotes
  role_description     = "Role for the EventBridge rule that starts the Lotes Step Function"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.evb_assume_role.json

  policy_name        = "-${local.name_prefix}-evb-lotes" # BUPolicyFor-dev-647096294147-rcncr-ws5-evb-lotes
  policy_description = "Allows EventBridge to start the Lotes Step Function"
  policy_documents   = [data.aws_iam_policy_document.evb_lotes.json]

  tags = local.default_tags
}

# --- Step Function Lotes ---
data "aws_iam_policy_document" "sfn_lotes" {
  source_policy_documents = [data.aws_iam_policy_document.kms_use.json]

  statement {
    sid       = "InvokeLambdas"
    actions   = ["lambda:InvokeFunction"]
    resources = flatten([for arn in [local.arns.lambda_parseo, local.arns.lambda_consolidar, local.arns.lambda_reclineacloud] : [arn, "${arn}:*"]])
  }

  # Estado del lote y puntero a la tabla vigente.
  dynamic "statement" {
    for_each = local.has_control_table
    content {
      sid       = "ControlLotes"
      actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
      resources = [local.dynamodb_metadata_control_arn]
    }
  }

  # Distributed Map: la SFN arranca ejecuciones hijas de si misma.
  statement {
    sid       = "DistributedMapStart"
    actions   = ["states:StartExecution"]
    resources = [local.arns.sfn_lotes]
  }

  statement {
    sid       = "DistributedMapManage"
    actions   = ["states:DescribeExecution", "states:StopExecution"]
    resources = [local.arns.sfn_lotes_executions, local.arns.sfn_lotes_map_runs]
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

module "sfn_lotes_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = local.lotes_enabled

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-sfn-lotes" # BURoleFor-dev-647096294147-rcncr-ws5-sfn-lotes
  role_description     = "Role for the Lotes Step Function (Distributed Map over RecLineaCloud)"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.sfn_assume_role.json

  policy_name        = "-${local.name_prefix}-sfn-lotes" # BUPolicyFor-dev-647096294147-rcncr-ws5-sfn-lotes
  policy_description = "Lambda invoke and Control table access for the Lotes Step Function"
  policy_documents   = [data.aws_iam_policy_document.sfn_lotes.json]

  tags = local.default_tags
}

# --- Lambda Parseo: lee el archivo de input/ ---
data "aws_iam_policy_document" "lambda_parseo" {
  count = local.lotes_enabled

  source_policy_documents = [
    data.aws_iam_policy_document.lambda_base["parseo"].json,
    data.aws_iam_policy_document.kms_use.json
  ]

  statement {
    sid       = "ReadInput"
    actions   = ["s3:GetObject"]
    resources = ["${local.arns.s3_lotes}/input/*"]
  }
}

module "lambda_parseo_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = local.lotes_enabled

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-lmbd-lotes-parseo" # BURoleFor-dev-647096294147-rcncr-ws5-lmbd-lotes-parseo
  role_description     = "Role for the Lotes Parseo Lambda"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json

  policy_name        = "-${local.name_prefix}-lmbd-lotes-parseo" # BUPolicyFor-dev-647096294147-rcncr-ws5-lmbd-lotes-parseo
  policy_description = "Read the input file for the Lotes Parseo Lambda"
  policy_documents   = [data.aws_iam_policy_document.lambda_parseo[0].json]

  tags = local.default_tags
}

# --- Lambda Consolidar: PDFs de output_raw/ -> ZIP en output_zip/ ---
data "aws_iam_policy_document" "lambda_consolidar" {
  count = local.lotes_enabled

  source_policy_documents = [
    data.aws_iam_policy_document.lambda_base["consolidar"].json,
    data.aws_iam_policy_document.kms_use.json
  ]

  statement {
    sid       = "ListOutputRaw"
    actions   = ["s3:ListBucket"]
    resources = [local.arns.s3_lotes]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["output_raw/*"]
    }
  }

  statement {
    sid       = "ReadOutputRaw"
    actions   = ["s3:GetObject"]
    resources = ["${local.arns.s3_lotes}/output_raw/*"]
  }

  statement {
    sid       = "WriteOutputZip"
    actions   = ["s3:PutObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
    resources = ["${local.arns.s3_lotes}/output_zip/*"]
  }
}

module "lambda_consolidar_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = local.lotes_enabled

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-lmbd-lotes-consolidar" # BURoleFor-dev-647096294147-rcncr-ws5-lmbd-lotes-consolidar
  role_description     = "Role for the Lotes Consolidar Lambda"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json

  policy_name        = "-${local.name_prefix}-lmbd-lotes-consolidar" # BUPolicyFor-dev-647096294147-rcncr-ws5-lmbd-lotes-consolidar
  policy_description = "Read PDFs and write the ZIP for the Lotes Consolidar Lambda"
  policy_documents   = [data.aws_iam_policy_document.lambda_consolidar[0].json]

  tags = local.default_tags
}

# --- Portal (on-premise, lo administra Operacion) ---
# Rol que asume el Portal para subir el archivo, consultar el estado del lote y
# descargar el ZIP (URL firmada). Solo se crea cuando Operacion entrega la
# identidad del Portal (lotes_portal_principal_arns).
data "aws_iam_policy_document" "portal_lotes_trust" {
  count = length(var.lotes_portal_principal_arns) > 0 ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = var.lotes_portal_principal_arns
    }
  }
}

data "aws_iam_policy_document" "portal_lotes" {
  source_policy_documents = [data.aws_iam_policy_document.kms_use.json]

  statement {
    sid       = "UploadInput"
    actions   = ["s3:PutObject"]
    resources = ["${local.arns.s3_lotes}/input/*"]
  }

  statement {
    sid       = "DownloadZip"
    actions   = ["s3:GetObject"]
    resources = ["${local.arns.s3_lotes}/output_zip/*"]
  }

  # Consulta el estado del lote y lo marca DESCARGADO.
  dynamic "statement" {
    for_each = local.has_control_table
    content {
      sid       = "EstadoLote"
      actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
      resources = [local.dynamodb_metadata_control_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["BATCH#*"]
      }
    }
  }
}

module "portal_lotes_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = var.enable_lotes && length(var.lotes_portal_principal_arns) > 0 ? 1 : 0

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-portal-lotes" # BURoleFor-dev-647096294147-rcncr-ws5-portal-lotes
  role_description     = "Role assumed by the on-premise Portal to upload batches and download results"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.portal_lotes_trust[0].json

  policy_name        = "-${local.name_prefix}-portal-lotes" # BUPolicyFor-dev-647096294147-rcncr-ws5-portal-lotes
  policy_description = "Upload input, read batch status and download ZIP for the Portal"
  policy_documents   = [data.aws_iam_policy_document.portal_lotes.json]

  tags = local.default_tags
}
