# Rol de la regla EventBridge Update: al llegar el manifiesto a
# Triggers_reconocer arranca la Step Function Update RecMaster.
data "aws_iam_policy_document" "evb_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "evb_updrecmaster" {
  statement {
    sid       = "StartSfn"
    actions   = ["states:StartExecution"]
    resources = [local.arns.sfn_updrecmaster]
  }
}

module "evb_updrecmaster_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.1"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-evb-updrecmaster" # BURoleFor-dev-647096294147-rcncr-ws5-evb-updrecmaster
  role_description     = "Role for the EventBridge rule that starts the Update RecMaster Step Function"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.evb_assume_role.json

  policy_name        = "-${local.name_prefix}-evb-updrecmaster" # BUPolicyFor-dev-647096294147-rcncr-ws5-evb-updrecmaster
  policy_description = "Allows EventBridge to start the Update RecMaster Step Function"
  policy_documents   = [data.aws_iam_policy_document.evb_updrecmaster.json]

  tags = local.default_tags
}
