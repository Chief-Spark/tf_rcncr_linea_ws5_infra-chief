# Rol de CloudWatch de API Gateway (configuracion a nivel cuenta/region:
# aws_api_gateway_account, que la libreria eits-tf-aws-api-gateway siempre
# gestiona). La cuenta no tiene el rol por defecto de la libreria
# (BURoleForAPIGatewayCloudwatchGlobal) y ese nombre no cumple la nomenclatura,
# asi que se crea aqui con eits-tf-aws-iam y se le pasa a la libreria.
data "aws_iam_policy_document" "apigw_cloudwatch_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

# Mismas acciones que el rol por defecto de la libreria.
data "aws_iam_policy_document" "apigw_cloudwatch" {
  statement {
    sid = "PushLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = ["*"]
  }
}

module "apigw_cloudwatch_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-apigw-cloudwatch" # BURoleFor-dev-647096294147-rcncr-ws5-apigw-cloudwatch
  role_description     = "Account-level CloudWatch Logs role for API Gateway"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.apigw_cloudwatch_assume_role.json

  policy_name        = "-${local.name_prefix}-apigw-cloudwatch" # BUPolicyFor-dev-647096294147-rcncr-ws5-apigw-cloudwatch
  policy_description = "Allows API Gateway to push logs to CloudWatch"
  policy_documents   = [data.aws_iam_policy_document.apigw_cloudwatch.json]

  tags = local.default_tags
}
