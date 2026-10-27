# EventBridge (libreria eits-tf-aws-eventbridge). El UNLOAD de Redshift Reconocer
# escribe <novedades_prefix><run_id>/data/<tabla>/ y, al terminar las 7 tablas,
# el CTL final <novedades_prefix><run_id>/<ctl_final_name>. Solo el CTL final
# dispara los dos flujos:
#   1. evb_updrecmaster: Step Function Update RecMaster (esta cuenta).
#   2. evb_fwd_batch: reenvia el mismo evento al bus de la cuenta Batch (Step
#      Function Upload -> COPY a Redshift Bureau).
locals {
  ctl_final_event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [module.s3_triggers.s3_bucket_id] }
      object = { key = [{ wildcard = "${var.novedades_prefix}*/${var.ctl_final_name}" }] }
    }
  })
}

module "evb_updrecmaster" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git?ref=2.7.0"

  name_prefix      = local.name_prefix
  name             = "upd-recmaster" # => dev-647096294147-rcncr-ws5-upd-recmaster-event
  description      = "Dispara la carga de reconocer_master al publicarse el CTL final en Triggers_reconocer"
  enable_scheduler = false

  event_pattern_json = local.ctl_final_event_pattern

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

# Reenvio del CTL final a la cuenta Batch. El bus de destino debe permitir
# events:PutEvents desde esta cuenta (resource policy en la cuenta Batch).
module "evb_fwd_batch" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git?ref=2.7.0"
  count  = var.batch_account_id != "" ? 1 : 0

  name_prefix      = local.name_prefix
  name             = "fwd-batch" # => dev-647096294147-rcncr-ws5-fwd-batch-event
  description      = "Reenvia el CTL final de novedades al EventBridge de la cuenta Batch"
  enable_scheduler = false

  event_pattern_json = local.ctl_final_event_pattern

  existing_role_arn = module.evb_fwd_batch_role[0].role_arn
  rule_targets = {
    batch = {
      arn      = local.batch_event_bus_arn
      role_arn = module.evb_fwd_batch_role[0].role_arn
    }
  }

  tags = local.default_tags
}
