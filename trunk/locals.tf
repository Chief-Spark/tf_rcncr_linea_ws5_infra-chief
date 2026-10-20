locals {
  env_prefix = {
    develop    = "dev"
    qa         = "qa"
    demo       = "demo"
    production = "prod"
  }

  env_short   = lookup(local.env_prefix, var.environment, var.environment)
  name_prefix = "${local.env_short}-${var.account_id}-${var.project}"

  permissions_boundary_arn = "arn:aws:iam::${var.account_id}:policy/${var.permissions_boundary}"
  kms_key_arn              = var.kms_key_arn == "" ? null : var.kms_key_arn

  # Nombres finales. Las librerias arman algunos nombres solas; aqui se replica
  # la formula para que los roles apunten a ARNs deterministicos sin depender de
  # que el recurso exista (evita ciclos rol <-> recurso):
  #   lambda      -> <prefix>-<function_scope>-lambda
  #   s3          -> <prefix>-<bucket_name>-s3
  #   eventbridge -> <prefix>-<name>-event
  #   api gateway -> <name>-api
  names = {
    lambda_authorizer    = "${local.name_prefix}-authorizer-lambda"
    lambda_reclineacloud = "${local.name_prefix}-reclineacloud-lambda"
    lambda_validation    = "${local.name_prefix}-validation-lambda"
    glue_transform       = "${local.name_prefix}-recmas-transform-upload"
    glue_log_group       = "/aws-glue/jobs/${local.name_prefix}-recmaster"
    sfn_updrecmaster     = "${local.name_prefix}-upd-recmaster-sfn"
    sqs_facturacion      = "${local.name_prefix}-facturacion.fifo"
    sqs_facturacion_dlq  = "${local.name_prefix}-facturacion-dlq.fifo"
    s3_triggers          = "${local.name_prefix}-triggers-reconocer-s3"
    s3_staging           = "${local.name_prefix}-upload-staging-s3"
    api                  = "${local.name_prefix}-reconocer-linea"
  }

  lambda_names = {
    authorizer    = local.names.lambda_authorizer
    reclineacloud = local.names.lambda_reclineacloud
    validation    = local.names.lambda_validation
  }

  arns = {
    lambda_validation = "arn:aws:lambda:${var.region}:${var.account_id}:function:${local.names.lambda_validation}"
    glue_transform    = "arn:aws:glue:${var.region}:${var.account_id}:job/${local.names.glue_transform}"
    sfn_updrecmaster  = "arn:aws:states:${var.region}:${var.account_id}:stateMachine:${local.names.sfn_updrecmaster}"
    sfn_executions    = "arn:aws:states:${var.region}:${var.account_id}:execution:${local.names.sfn_updrecmaster}:*"
    sfn_map_runs      = "arn:aws:states:${var.region}:${var.account_id}:execution:${local.names.sfn_updrecmaster}/*"
    sqs_facturacion   = "arn:aws:sqs:${var.region}:${var.account_id}:${local.names.sqs_facturacion}"
    s3_triggers       = "arn:aws:s3:::${local.names.s3_triggers}"
    s3_staging        = "arn:aws:s3:::${local.names.s3_staging}"
  }

  glue_script_location = coalesce(var.glue_script_location, "s3://${local.names.s3_staging}/glue-scripts/recmas_transform_and_upload.py")
  glue_script_bucket   = split("/", trimprefix(local.glue_script_location, "s3://"))[0]

  # Excepcion a la bucket policy de eits-tf-aws-s3 para los roles que llaman a
  # S3 desde la red de AWS (ver var.s3_source_ip_exception).
  s3_exception_tags = var.s3_source_ip_exception ? { "eec:SourceIPException" = "true" } : {}

  default_tags = {
    Environment = var.environment
    Project     = var.project
    AppID       = var.app_id
    CostString  = var.cost_string
    ManagedBy   = "terraform"
    Repository  = "tf_rcncr_linea_ws5_infra-chief"
  }
}
