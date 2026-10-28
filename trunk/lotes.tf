# Flujo de Lotes (Cargue de archivos). Reemplaza el consumo por lotes con
# Control-M: el Portal (on-premise) sube un archivo de hasta 99 registros y
# recibe un ZIP con un PDF por registro.
#
# Bucket RecMasterLotes (<prefix>-recmasterlotes-s3):
#   input/<batch_id>/<archivo>.csv|.txt  lo sube el Portal; dispara el flujo
#   plantillas/                          plantillas de los PDF (no se borran)
#   output_raw/<batch_id>/               un PDF por registro (RecLineaCloud)
#   output_zip/<batch_id>/resultado.zip  lo arma Consolidar; lo descarga el Portal
#
# EventBridge (archivo nuevo en input/) -> Step Function Lotes:
#   1. Estado RECIBIDO en Metadata & Control.
#   2. Lambda Parseo: lee y valida el archivo; devuelve los registros.
#   3. Estado VALIDADO, lee la tabla vigente (puntero) y estado EN_PROCESO.
#   4. Map: RecLineaCloud por registro (output_mode pdf_s3), N a la vez.
#   5. Lambda Consolidar: arma el ZIP. Estado PROCESADO.
#   Cualquier falla (o mas registros fallidos que el % tolerado): FALLIDO.
#
# Contrato con la tabla Metadata & Control (la crea otro proceso): llave
# pk (S) + sk (S).
#   Lote:    pk = BATCH#<batch_id>, sk = ESTADO -> estado, s3_key, resultado...
#   Puntero: pk = VERSION#GLOBAL,   sk = ACTIVA -> tabla_activa (lo escribe Validation)
locals {
  lotes_enabled = var.enable_lotes ? 1 : 0

  control_key_lote = {
    pk = { "S.$" = "States.Format('BATCH#{}', $.batch_id)" }
    sk = { S = "ESTADO" }
  }

  # Marca el estado del lote; extra agrega mas atributos al SET.
  lotes_estado = {
    for estado, extra in {
      RECIBIDO   = { set = ", s3_key = :k", values = { ":k" = { "S.$" = "$.s3_key" } } }
      VALIDADO   = { set = ", conteo = :c", values = { ":c" = { "N.$" = "States.Format('{}', $.parseo.conteo)" } } }
      EN_PROCESO = { set = "", values = {} }
      PROCESADO  = { set = ", resultado = :r", values = { ":r" = { "S.$" = "States.JsonToString($.consolidado)" } } }
      FALLIDO    = { set = ", detalle_error = :r", values = { ":r" = { "S.$" = "States.JsonToString($.error)" } } }
    } :
    estado => {
      Type     = "Task"
      Resource = "arn:aws:states:::dynamodb:updateItem"
      Parameters = {
        TableName                = var.dynamodb_metadata_control_table
        Key                      = local.control_key_lote
        UpdateExpression         = "SET #e = :e, actualizado = :t${extra.set}"
        ExpressionAttributeNames = { "#e" = "estado" }
        ExpressionAttributeValues = merge({
          ":e" = { S = estado }
          ":t" = { "S.$" = "$$.State.EnteredTime" }
        }, extra.values)
      }
      ResultPath = null
    }
  }

  # Archivo nuevo en input/. Un solo comodin por patron: con dos (input/*/*.csv)
  # EventBridge rechaza la regla por compleja (build 75086). El * tambien cubre
  # la carpeta <batch_id>/.
  lotes_event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [local.names.s3_lotes] }
      object = { key = [for ext in ["csv", "CSV", "txt", "TXT"] : { wildcard = "input/*.${ext}" }] }
    }
  })

  lotes_catch = [{
    ErrorEquals = ["States.ALL"]
    ResultPath  = "$.error"
    Next        = "MarcarFallido"
  }]
}

module "s3_lotes" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-s3.git?ref=2.19.2"
  count  = local.lotes_enabled

  prefix                  = local.name_prefix
  bucket_name             = "recmasterlotes" # => dev-647096294147-rcncr-ws5-recmasterlotes-s3
  sse_algorithm           = local.kms_enabled ? "aws:kms" : "AES256"
  kms_key_arn             = local.kms_key_arn
  disable_source_ip_check = var.s3_disable_source_ip_check

  # Entradas y salidas se borran a los N dias; plantillas/ se conserva. El
  # bucket es versionado: tambien se borran las versiones anteriores.
  lifecycle_rules = [for p in ["input/", "output_raw/", "output_zip/"] : {
    id                            = "borrar-${trimsuffix(p, "/")}"
    filter                        = { prefix = p }
    expiration                    = { days = var.lotes_retention_days }
    noncurrent_version_expiration = { noncurrent_days = 1 }
  }]

  tags = local.default_tags
}

resource "aws_s3_bucket_notification" "lotes" {
  count = local.lotes_enabled

  bucket      = module.s3_lotes[0].s3_bucket_id
  eventbridge = true
}

module "evb_lotes" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git?ref=2.7.0"
  count  = local.lotes_enabled

  name_prefix      = local.name_prefix
  name             = "lotes" # => dev-647096294147-rcncr-ws5-lotes-event
  description      = "Arranca la Step Function Lotes al subir un archivo a input/ de RecMasterLotes"
  enable_scheduler = false

  event_pattern_json = local.lotes_event_pattern

  existing_role_arn = module.evb_lotes_role[0].role_arn
  rule_targets = {
    sfn = {
      arn      = aws_sfn_state_machine.lotes[0].arn
      role_arn = module.evb_lotes_role[0].role_arn
    }
  }

  tags = local.default_tags
}

resource "aws_cloudwatch_log_group" "sfn_lotes" {
  count = local.lotes_enabled

  name              = "/aws/vendedlogs/states/${local.names.sfn_lotes}"
  retention_in_days = 90
  kms_key_id        = local.kms_key_arn
}

resource "aws_sfn_state_machine" "lotes" {
  count = local.lotes_enabled

  name     = local.names.sfn_lotes
  role_arn = module.sfn_lotes_role[0].role_arn

  definition = jsonencode({
    Comment = "Lotes: archivo en input/ -> un PDF por registro con RecLineaCloud -> ZIP en output_zip/"
    StartAt = "DatosDelLote"
    States = {
      DatosDelLote = {
        Type = "Pass"
        Parameters = {
          "batch_id.$" = "States.ArrayGetItem(States.StringSplit($.detail.object.key, '/'), 1)"
          "bucket.$"   = "$.detail.bucket.name"
          "s3_key.$"   = "$.detail.object.key"
        }
        Next = "MarcarRecibido"
      }
      MarcarRecibido = merge(local.lotes_estado.RECIBIDO, { Next = "Parsear" })
      Parsear = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = local.arns.lambda_parseo
          Payload = {
            "batch_id.$" = "$.batch_id"
            "bucket.$"   = "$.bucket"
            "s3_key.$"   = "$.s3_key"
          }
        }
        # Contrato: {"registros": [...], "conteo": n, "producto": "...", "perfil": "..."}.
        # Si el archivo no es valido, la Lambda falla y el lote queda FALLIDO.
        ResultSelector = {
          "registros.$" = "$.Payload.registros"
          "conteo.$"    = "$.Payload.conteo"
          "producto.$"  = "$.Payload.producto"
          "perfil.$"    = "$.Payload.perfil"
        }
        ResultPath = "$.parseo"
        Retry      = local.sfn_lambda_retry
        Catch      = local.lotes_catch
        Next       = "MarcarValidado"
      }
      MarcarValidado = merge(local.lotes_estado.VALIDADO, { Next = "LeerTablaVigente" })
      LeerTablaVigente = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:getItem"
        Parameters = {
          TableName = var.dynamodb_metadata_control_table
          Key = {
            pk = { S = "VERSION#GLOBAL" }
            sk = { S = "ACTIVA" }
          }
        }
        ResultSelector = { "tabla.$" = "$.Item.tabla_activa.S" }
        ResultPath     = "$.vigente"
        Catch          = local.lotes_catch
        Next           = "MarcarEnProceso"
      }
      MarcarEnProceso = merge(local.lotes_estado.EN_PROCESO, { Next = "ProcesarRegistros" })
      ProcesarRegistros = {
        Type                       = "Map"
        ItemsPath                  = "$.parseo.registros"
        MaxConcurrency             = var.lotes_max_concurrency
        ToleratedFailurePercentage = var.lotes_tolerated_failure_percentage
        ItemSelector = {
          "batch_id.$"              = "$.batch_id"
          "registro_index.$"        = "$$.Map.Item.Index"
          "registro.$"              = "$$.Map.Item.Value"
          "producto.$"              = "$.parseo.producto"
          "perfil.$"                = "$.parseo.perfil"
          "active_table_override.$" = "$.vigente.tabla"
          output_mode               = "pdf_s3"
        }
        ItemProcessor = {
          ProcessorConfig = {
            Mode          = "DISTRIBUTED"
            ExecutionType = "STANDARD"
          }
          StartAt = "ResolverRegistro"
          States = {
            ResolverRegistro = {
              Type     = "Task"
              Resource = "arn:aws:states:::lambda:invoke"
              Parameters = {
                FunctionName = local.arns.lambda_reclineacloud
                "Payload.$"  = "$"
              }
              ResultSelector = { "estado.$" = "$.StatusCode" }
              Retry = [{
                ErrorEquals     = ["States.ALL"]
                IntervalSeconds = 2
                MaxAttempts     = 2
                BackoffRate     = 2
              }]
              End = true
            }
          }
        }
        ResultPath = null
        Catch      = local.lotes_catch
        Next       = "Consolidar"
      }
      Consolidar = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = local.arns.lambda_consolidar
          Payload = {
            "batch_id.$" = "$.batch_id"
            "conteo.$"   = "$.parseo.conteo"
          }
        }
        # Contrato: {"ubicacion_salida": "output_zip/<batch_id>/resultado.zip", "errores_parciales": n}.
        ResultSelector = { "resultado.$" = "$.Payload" }
        ResultPath     = "$.consolidado"
        Retry          = local.sfn_lambda_retry
        Catch          = local.lotes_catch
        Next           = "MarcarProcesado"
      }
      MarcarProcesado = merge(local.lotes_estado.PROCESADO, { Next = "Fin" })
      Fin = {
        Type = "Succeed"
      }
      MarcarFallido = merge(local.lotes_estado.FALLIDO, { Next = "LoteFallido" })
      LoteFallido = {
        Type  = "Fail"
        Error = "LoteFallido"
        Cause = "El lote quedo FALLIDO en Metadata & Control (ver detalle_error)."
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_lotes[0].arn}:*"
    include_execution_data = false
    level                  = "ERROR"
  }

  tracing_configuration {
    enabled = true
  }

  lifecycle {
    precondition {
      condition     = var.dynamodb_metadata_control_table != ""
      error_message = "El flujo de Lotes guarda el estado en Metadata & Control: defina dynamodb_metadata_control_table o enable_lotes = false."
    }
  }
}
