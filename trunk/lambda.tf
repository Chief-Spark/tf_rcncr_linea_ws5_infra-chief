# Lambdas (libreria eits-tf-aws-lambda). El codigo vive en otros repos: aqui solo
# se apunta al paquete en S3 (var.lambdas). Nombre final: <prefix>-<scope>-lambda.
# Se crean solo con enable_lambdas = true, cuando los paquetes ya existen.
locals {
  lambda_role_arns = {
    authorizer    = module.lambda_authorizer_role.role_arn
    reclineacloud = module.lambda_reclineacloud_role.role_arn
    validation    = module.lambda_validation_role.role_arn
  }

  lambda_descriptions = {
    authorizer    = "Lambda Authorizer (Okta JWT) del API Reconocer Linea"
    reclineacloud = "RecLineaCloud: consumo en linea de Reconocer Master"
    validation    = "Validacion de integridad de la carga de Base_Online"
  }

  # Variables de entorno de infraestructura; var.lambdas[*].environment_variables
  # agrega o sobreescribe las de negocio.
  lambda_infra_env = {
    authorizer = {}
    reclineacloud = merge(
      local.dynamodb_env,
      { SQS_FACTURACION_URL = aws_sqs_queue.facturacion.url },
      var.reclinea_output_bucket != "" ? { OUTPUT_BUCKET = var.reclinea_output_bucket } : {}
    )
    validation = merge(local.dynamodb_env, {
      BUCKET_STAGING  = module.s3_staging.s3_bucket_id
      BUCKET_TRIGGERS = module.s3_triggers.s3_bucket_id
    })
  }
}

module "lambda" {
  source   = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git?ref=1.11.2"
  for_each = var.enable_lambdas ? local.lambda_role_arns : {}

  prefix         = local.name_prefix
  function_scope = each.key # => dev-647096294147-rcncr-ws5-<scope>-lambda
  description    = local.lambda_descriptions[each.key]

  # Rol creado con eits-tf-aws-iam (nomenclatura BURoleFor-...), no el del modulo.
  role = each.value

  runtime                        = var.lambdas[each.key].runtime
  handler                        = var.lambdas[each.key].handler
  s3_bucket                      = var.lambdas[each.key].s3_bucket
  s3_key                         = var.lambdas[each.key].s3_key
  memory_size                    = var.lambdas[each.key].memory_size
  timeout                        = var.lambdas[each.key].timeout
  reserved_concurrent_executions = var.lambdas[each.key].reserved_concurrent_executions
  environment_variables          = merge(local.lambda_infra_env[each.key], var.lambdas[each.key].environment_variables)
  kms_key_arn                    = local.kms_key_arn

  tracing_config_mode               = "Active"
  vpc_config                        = var.lambda_vpc_config
  cloudwatch_logs_retention_in_days = var.lambda_log_retention_days
  cloudwatch_logs_kms_key_arn       = local.kms_key_arn

  tags = local.default_tags
}
