# Step Function "Update RecMaster" (recurso nativo: no hay libreria confirmada).
#
# BORRADOR de la definicion segun el HLD; validar con el equipo de desarrollo:
#   1. Lee el manifiesto (evento S3 de EventBridge).
#   2. Distributed Map: una rama por dominio -> Glue (transform + staging + upsert)
#      -> Lambda Validation (conteos/hash vs manifiesto, swap de active_run_id).
resource "aws_cloudwatch_log_group" "sfn_updrecmaster" {
  name              = "/aws/vendedlogs/states/${local.names.sfn_updrecmaster}"
  retention_in_days = 90
  kms_key_id        = local.kms_key_arn
}

resource "aws_sfn_state_machine" "updrecmaster" {
  name     = local.names.sfn_updrecmaster
  role_arn = module.sfn_updrecmaster_role.role_arn

  definition = jsonencode({
    Comment = "Actualiza Base_Online (reconocer_master) a partir del manifiesto publicado en Triggers_reconocer",
    StartAt = "LeerManifiesto",
    States = {
      LeerManifiesto = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:s3:getObject",
        Parameters = {
          "Bucket.$" = "$.detail.bucket.name",
          "Key.$"    = "$.detail.object.key"
        },
        ResultSelector = {
          "manifiesto.$" = "States.StringToJson($.Body)"
        },
        ResultPath = "$.lectura",
        Next       = "ProcesarDominios"
      },
      ProcesarDominios = {
        Type           = "Map",
        ItemsPath      = "$.lectura.manifiesto.dominios",
        MaxConcurrency = var.sfn_max_concurrency,
        ItemSelector = {
          "run_id.$"     = "$.lectura.manifiesto.run_id",
          "tipo_carga.$" = "$.lectura.manifiesto.tipo_carga",
          "dominio.$"    = "$$.Map.Item.Value"
        },
        ItemProcessor = {
          ProcessorConfig = {
            Mode          = "DISTRIBUTED",
            ExecutionType = "STANDARD"
          },
          StartAt = "TransformAndUpload",
          States = {
            TransformAndUpload = {
              Type     = "Task",
              Resource = "arn:aws:states:::glue:startJobRun.sync",
              Parameters = {
                JobName = local.names.glue_transform,
                Arguments = {
                  "--run_id.$"              = "$.run_id",
                  "--tipo_carga.$"          = "$.tipo_carga",
                  "--dominio.$"             = "$.dominio.nombre",
                  "--s3_path.$"             = "$.dominio.s3_path",
                  "--registros_esperados.$" = "States.Format('{}', $.dominio.registros_esperados)"
                }
              },
              ResultPath = null,
              Next       = "Validation"
            },
            Validation = {
              Type     = "Task",
              Resource = "arn:aws:states:::lambda:invoke",
              Parameters = {
                FunctionName = local.arns.lambda_validation,
                "Payload.$"  = "$"
              },
              OutputPath = "$.Payload",
              Retry = [{
                ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"],
                IntervalSeconds = 2,
                MaxAttempts     = 3,
                BackoffRate     = 2
              }],
              End = true
            }
          }
        },
        ResultPath = "$.resultados",
        End        = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_updrecmaster.arn}:*"
    include_execution_data = false
    level                  = "ERROR"
  }

  tracing_configuration {
    enabled = true
  }
}
