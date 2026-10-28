output "role_arns" {
  description = "IAM role ARNs created for each component"
  value = {
    lambda_authorizer    = module.lambda_authorizer_role.role_arn
    lambda_reclineacloud = module.lambda_reclineacloud_role.role_arn
    lambda_validation    = module.lambda_validation_role.role_arn
    lambda_facturacion   = module.lambda_facturacion_role.role_arn
    lambda_parseo        = try(module.lambda_parseo_role[0].role_arn, null)
    lambda_consolidar    = try(module.lambda_consolidar_role[0].role_arn, null)
    sfn_lotes            = try(module.sfn_lotes_role[0].role_arn, null)
    evb_lotes            = try(module.evb_lotes_role[0].role_arn, null)
    portal_lotes         = try(module.portal_lotes_role[0].role_arn, null)
    glue_transform       = module.glue_transform_role.role_arn
    sfn_updrecmaster     = module.sfn_updrecmaster_role.role_arn
    evb_updrecmaster     = module.evb_updrecmaster_role.role_arn
    redshift_unload      = module.redshift_unload_role.role_arn
    redshift_copy_xacct  = try(module.redshift_copy_role[0].role_arn, null)
    apigw_cloudwatch     = module.apigw_cloudwatch_role.role_arn
    evb_fwd_batch        = try(module.evb_fwd_batch_role[0].role_arn, null)
  }
}

output "s3_triggers_bucket" {
  description = "Triggers_reconocer bucket name"
  value       = module.s3_triggers.s3_bucket_id
}

output "s3_staging_bucket" {
  description = "Upload_Staging bucket name"
  value       = module.s3_staging.s3_bucket_id
}

output "sqs_facturacion" {
  description = "Billing FIFO queue and its DLQ"
  value = {
    url     = aws_sqs_queue.facturacion.url
    arn     = aws_sqs_queue.facturacion.arn
    dlq_arn = aws_sqs_queue.facturacion_dlq.arn
  }
}

output "glue_job_name" {
  description = "RecMas_Transform_and_Upload Glue job name"
  value       = local.names.glue_transform
}

output "state_machine_arn" {
  description = "Update RecMaster Step Function ARN"
  value       = aws_sfn_state_machine.updrecmaster.arn
}

output "eventbridge_rule_arn" {
  description = "EventBridge Update rule ARN"
  value       = module.evb_updrecmaster.rule_arn
}

output "lambda_arns" {
  description = "Lambda function ARNs (empty until enable_lambdas = true)"
  value       = { for k, m in module.lambda : k => m.arn }
}

output "api_id" {
  description = "Private REST API id (null until enable_lambdas = true)"
  value       = try(aws_api_gateway_rest_api.this[0].id, null)
}

output "api_invoke_url" {
  description = "Private REST API stage invoke URL (null until enable_lambdas = true)"
  value       = try(aws_api_gateway_stage.this[0].invoke_url, null)
}

output "kms_key_arn" {
  description = "CMK del stack (null sin CMK)"
  value       = local.kms_key_arn
}

output "lotes" {
  description = "Flujo de Lotes: bucket y Step Function (null con enable_lotes = false)"
  value = var.enable_lotes ? {
    bucket            = module.s3_lotes[0].s3_bucket_id
    state_machine_arn = aws_sfn_state_machine.lotes[0].arn
  } : null
}
