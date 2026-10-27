# Rol de la regla EventBridge que reenvia el CTL final al bus de la cuenta Batch.
locals {
  batch_event_bus_arn = "arn:aws:events:${var.region}:${var.batch_account_id}:event-bus/${var.batch_event_bus_name}"
}

data "aws_iam_policy_document" "evb_fwd_batch" {
  statement {
    sid       = "PutEventsBatch"
    actions   = ["events:PutEvents"]
    resources = [local.batch_event_bus_arn]
  }
}

module "evb_fwd_batch_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = var.batch_account_id != "" ? 1 : 0

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-evb-fwd-batch" # BURoleFor-dev-647096294147-rcncr-ws5-evb-fwd-batch
  role_description     = "Role for the EventBridge rule that forwards the final CTL to the Batch account"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.evb_assume_role.json

  policy_name        = "-${local.name_prefix}-evb-fwd-batch" # BUPolicyFor-dev-647096294147-rcncr-ws5-evb-fwd-batch
  policy_description = "Allows EventBridge to put events on the Batch account event bus"
  policy_documents   = [data.aws_iam_policy_document.evb_fwd_batch.json]

  tags = local.default_tags
}
