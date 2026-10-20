# Lambdas (libreria eits-tf-aws-lambda). Nombre final: <prefix>-<scope>-lambda.
#
# Codigo: se crean con un paquete PLACEHOLDER (placeholder/lambda-placeholder.zip,
# enviado directo en CreateFunction; no se sube nada a S3). El pipeline de cada
# repo de codigo publica la version real con `aws lambda update-function-code`.
# Terraform no revierte ese codigo en los siguientes builds porque no se fija
# source_code_hash. La CONFIGURACION (runtime, handler, memoria, env vars) si es
# de este repo: si el pipeline del codigo la cambia, el siguiente build la pisa.
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

  # Defaults por Lambda (sobreescribibles en var.lambdas). Runtimes segun el HLD:
  # RecLineaCloud en Java 21 (ADR-08); el resto en Python, como las Lambdas de
  # las guias del equipo (handler.py -> handler.lambda_handler).
  lambda_defaults = {
    authorizer = {
      runtime                        = "python3.13"
      handler                        = "handler.lambda_handler"
      memory_size                    = 256
      timeout                        = 10
      reserved_concurrent_executions = 10
    }
    reclineacloud = {
      runtime                        = "java21"
      handler                        = "com.experian.reconocer.linea.Handler::handleRequest" # confirmar con desarrollo
      memory_size                    = 2048
      timeout                        = 29
      reserved_concurrent_executions = 50
    }
    validation = {
      runtime                        = "python3.13"
      handler                        = "handler.lambda_handler"
      memory_size                    = 1024
      timeout                        = 300
      reserved_concurrent_executions = 7
    }
  }

  lambda_config = {
    for k, d in local.lambda_defaults : k => {
      for attr, value in d : attr => coalesce(try(var.lambdas[k][attr], null), value)
    }
  }

  lambda_placeholder_zip = "${path.module}/placeholder/lambda-placeholder.zip"

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

  filename                       = local.lambda_placeholder_zip
  runtime                        = local.lambda_config[each.key].runtime
  handler                        = local.lambda_config[each.key].handler
  memory_size                    = local.lambda_config[each.key].memory_size
  timeout                        = local.lambda_config[each.key].timeout
  reserved_concurrent_executions = local.lambda_config[each.key].reserved_concurrent_executions
  environment_variables          = merge(local.lambda_infra_env[each.key], try(var.lambdas[each.key].environment_variables, {}))
  kms_key_arn                    = local.kms_key_arn

  tracing_config_mode               = "Active"
  vpc_config                        = var.lambda_vpc_config
  cloudwatch_logs_retention_in_days = var.lambda_log_retention_days
  cloudwatch_logs_kms_key_arn       = local.kms_key_arn

  tags = local.default_tags
}
