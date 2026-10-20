# Piezas IAM compartidas por los roles de este stack.
#
# NOMENCLATURA: el modulo eits-tf-aws-iam antepone "BURoleFor" / "BUPolicyFor"
# sin guion. Las librerias (lambda, glue, eventbridge) pueden crear su propio rol,
# pero no con esta nomenclatura; por eso los roles se crean aqui y se les pasan. Por eso role_name / policy_name se pasan con guion inicial:
#   "-${local.name_prefix}-<sufijo>" => BURoleFor-dev-647096294147-rcncr-ws5-<sufijo>

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Permisos base de cada Lambda: logs de su propio log group, X-Ray y, si van en
# VPC, gestion de ENIs.
data "aws_iam_policy_document" "lambda_base" {
  for_each = local.lambda_names

  statement {
    sid     = "Logs"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${each.value}",
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${each.value}:*"
    ]
  }

  statement {
    sid       = "XRay"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.lambda_vpc_config != null ? [1] : []
    content {
      sid = "VpcEni"
      actions = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSubnets",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ]
      resources = ["*"]
    }
  }
}

# Uso de la CMK (S3 y SQS cifrados). Vacio si no se define kms_key_arn.
data "aws_iam_policy_document" "kms_use" {
  dynamic "statement" {
    for_each = var.kms_key_arn == "" ? [] : [1]
    content {
      sid       = "KmsUse"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      resources = [var.kms_key_arn]
    }
  }
}
