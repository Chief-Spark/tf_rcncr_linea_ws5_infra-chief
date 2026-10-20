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

  # Nombres de los recursos. Se definen aqui para que los roles puedan apuntar a
  # ARNs deterministicos sin depender de que el recurso ya exista (evita ciclos,
  # p. ej. la SFN necesita su rol y el rol necesita el ARN de la SFN).
  names = {
    lambda_authorizer    = "${local.name_prefix}-lmbd-authorizer"
    lambda_reclineacloud = "${local.name_prefix}-lmbd-reclineacloud"
    lambda_facturacion   = "${local.name_prefix}-lmbd-facturacion"
    lambda_validation    = "${local.name_prefix}-lmbd-validation"
    glue_transform       = "${local.name_prefix}-glue-recmas-transform-upload"
    sfn_updrecmaster     = "${local.name_prefix}-sfn-upd-recmaster"
    evb_updrecmaster     = "${local.name_prefix}-evb-upd-recmaster"
    sqs_facturacion      = "${local.name_prefix}-sqs-facturacion.fifo"
    sqs_facturacion_dlq  = "${local.name_prefix}-sqs-facturacion-dlq.fifo"
    s3_triggers          = "${local.name_prefix}-triggers-reconocer"
    s3_staging           = "${local.name_prefix}-upload-staging"
  }

  lambda_names = {
    authorizer    = local.names.lambda_authorizer
    reclineacloud = local.names.lambda_reclineacloud
    facturacion   = local.names.lambda_facturacion
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

  default_tags = {
    Environment = var.environment
    Project     = var.project
    AppID       = var.app_id
    CostString  = var.cost_string
    ManagedBy   = "terraform"
    Repository  = "tf_rcncr_linea_ws5_infra-chief"
  }
}
