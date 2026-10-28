# Lambdas (libreria eits-tf-aws-lambda). Nombre final: <prefix>-<scope>-lambda.
#
# Codigo: se crean con un paquete PLACEHOLDER (placeholder/lambda-placeholder.zip,
# enviado directo en CreateFunction; no se sube nada a S3). El pipeline de cada
# repo de codigo publica la version real con `aws lambda update-function-code`.
# Terraform no revierte ese codigo en los siguientes builds porque no se fija
# source_code_hash. La CONFIGURACION (runtime, handler, memoria, env vars) si es
# de este repo: si el pipeline del codigo la cambia, el siguiente build la pisa.
locals {
  lambda_role_arns = merge(
    {
      authorizer    = module.lambda_authorizer_role.role_arn
      reclineacloud = module.lambda_reclineacloud_role.role_arn
      validation    = module.lambda_validation_role.role_arn
      facturacion   = module.lambda_facturacion_role.role_arn
    },
    var.enable_lotes ? {
      parseo     = module.lambda_parseo_role[0].role_arn
      consolidar = module.lambda_consolidar_role[0].role_arn
    } : {}
  )

  lambda_descriptions = {
    authorizer    = "Lambda Authorizer (Okta JWT) del API Reconocer Linea"
    reclineacloud = "RecLineaCloud: consumo en linea de Reconocer Master"
    validation    = "Validacion de integridad de la carga de Base_Online"
    facturacion   = "Facturacion: lee la cola SQS y envia al API de facturacion electronica"
    parseo        = "Lotes: lee y valida el archivo de entrada y devuelve sus registros"
    consolidar    = "Lotes: empaqueta los PDF del lote en un ZIP"
  }

  # Defaults por Lambda (sobreescribibles en var.lambdas). Todas en Python, como
  # las Lambdas de las guias del equipo (handler.py -> handler.lambda_handler).
  # RecLineaCloud pasa de Java a Python (decision del equipo, 2026-10-28).
  lambda_defaults = {
    authorizer = {
      runtime                        = "python3.13"
      handler                        = "handler.lambda_handler"
      memory_size                    = 256
      timeout                        = 10
      reserved_concurrent_executions = 10
    }
    reclineacloud = {
      runtime                        = "python3.13"
      handler                        = "handler.lambda_handler"
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
    # Un mensaje por invocacion (batch 1). timeout x 6 <= visibility timeout de la
    # cola (60 s), como recomienda AWS para Lambdas que leen SQS.
    facturacion = {
      runtime                        = "python3.13"
      handler                        = "handler.lambda_handler"
      memory_size                    = 256
      timeout                        = 10
      reserved_concurrent_executions = 5
    }
    # Lotes: archivo de hasta 99 registros (a mediano plazo ~1.000).
    parseo = {
      runtime                        = "python3.13"
      handler                        = "handler.lambda_handler"
      memory_size                    = 512
      timeout                        = 60
      reserved_concurrent_executions = 5
    }
    consolidar = {
      runtime                        = "python3.13"
      handler                        = "handler.lambda_handler"
      memory_size                    = 1024
      timeout                        = 300
      reserved_concurrent_executions = 5
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
      var.reclinea_output_bucket != "" ? { OUTPUT_BUCKET = var.reclinea_output_bucket } : {},
      var.enable_lotes ? { BUCKET_LOTES = local.names.s3_lotes } : {},
      var.validacion_identidad_role_arn != "" ? { VALIDACION_IDENTIDAD_ROLE_ARN = var.validacion_identidad_role_arn } : {}
    )
    validation = merge(local.dynamodb_env, {
      BUCKET_STAGING  = module.s3_staging.s3_bucket_id
      BUCKET_TRIGGERS = module.s3_triggers.s3_bucket_id
    })
    facturacion = var.facturacion_api_url != "" ? { FACTURACION_API_URL = var.facturacion_api_url } : {}
    parseo      = { BUCKET_LOTES = local.names.s3_lotes }
    consolidar  = { BUCKET_LOTES = local.names.s3_lotes }
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

# La cola de facturacion dispara la Lambda de Facturacion, un mensaje a la vez.
# Si falla maxReceiveCount veces, el mensaje pasa a la DLQ.
resource "aws_lambda_event_source_mapping" "facturacion" {
  count = var.enable_lambdas ? 1 : 0

  event_source_arn = aws_sqs_queue.facturacion.arn
  function_name    = module.lambda["facturacion"].arn
  batch_size       = 1
  enabled          = true
}
