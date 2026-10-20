# EventBridge Update (libreria eits-tf-aws-eventbridge): al llegar el manifiesto a
# Triggers_reconocer arranca la Step Function Update RecMaster.
module "evb_updrecmaster" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git?ref=2.7.0"

  name_prefix      = local.name_prefix
  name             = "upd-recmaster" # => dev-647096294147-rcncr-ws5-upd-recmaster-event
  description      = "Dispara la carga de Base_Online al publicarse el manifiesto en Triggers_reconocer"
  enable_scheduler = false

  event_pattern_json = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [module.s3_triggers.s3_bucket_id] }
      object = { key = [{ suffix = var.manifest_key_suffix }] }
    }
  })

  # Rol creado con eits-tf-aws-iam (nomenclatura BURoleFor-...), no el del modulo.
  existing_role_arn = module.evb_updrecmaster_role.role_arn
  rule_targets = {
    sfn = {
      arn      = aws_sfn_state_machine.updrecmaster.arn
      role_arn = module.evb_updrecmaster_role.role_arn
    }
  }

  tags = local.default_tags
}
