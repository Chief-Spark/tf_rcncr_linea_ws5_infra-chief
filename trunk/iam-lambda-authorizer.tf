# Rol de la Lambda Authorizer (valida JWT de Okta en el borde del API Gateway).
data "aws_iam_policy_document" "lambda_authorizer" {
  source_policy_documents = [data.aws_iam_policy_document.lambda_base["authorizer"].json]
}

module "lambda_authorizer_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-lmbd-authorizer" # BURoleFor-dev-647096294147-rcncr-ws5-lmbd-authorizer
  role_description     = "Role for the Okta Lambda Authorizer of the Reconocer Linea API"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json

  policy_name        = "-${local.name_prefix}-lmbd-authorizer" # BUPolicyFor-dev-647096294147-rcncr-ws5-lmbd-authorizer
  policy_description = "Logs and X-Ray for the Lambda Authorizer"
  policy_documents   = [data.aws_iam_policy_document.lambda_authorizer.json]

  tags = local.default_tags
}
