output "lambda_authorizer_role_arn" {
  description = "IAM role ARN of the Lambda Authorizer"
  value       = module.lambda_authorizer_role.role_arn
}

output "lambda_reclineacloud_role_arn" {
  description = "IAM role ARN of the RecLineaCloud Lambda"
  value       = module.lambda_reclineacloud_role.role_arn
}

output "lambda_facturacion_role_arn" {
  description = "IAM role ARN of the billing Lambda"
  value       = module.lambda_facturacion_role.role_arn
}

output "lambda_validation_role_arn" {
  description = "IAM role ARN of the Validation Lambda"
  value       = module.lambda_validation_role.role_arn
}

output "glue_transform_role_arn" {
  description = "IAM role ARN of the RecMas_Transform_and_Upload Glue job"
  value       = module.glue_transform_role.role_arn
}

output "sfn_updrecmaster_role_arn" {
  description = "IAM role ARN of the Update RecMaster Step Function"
  value       = module.sfn_updrecmaster_role.role_arn
}

output "evb_updrecmaster_role_arn" {
  description = "IAM role ARN of the EventBridge Update rule"
  value       = module.evb_updrecmaster_role.role_arn
}
