# Step Function "Update RecMaster" (recurso nativo: no hay libreria confirmada).
#
# La dispara el CTL final (<novedades_prefix><run_id>/<ctl_final_name>):
#   1. Lee el CTL final (run_id, tipo_carga, dominios = las 7 tablas).
#   2. Segun tipo_carga:
#      FULL  -> S3 Import de <novedades_prefix><run_id>/data/ a una tabla NUEVA
#               <prefijo><run_id> (pk/sk texto) -> espera a que termine ->
#               etiqueta la tabla -> Validation (cambia el puntero en Metadata &
#               Control y devuelve la tabla anterior) -> espera -> borra la
#               tabla anterior.
#      DELTA -> Distributed Map: una rama por tabla -> Glue (upsert en la tabla
#               vigente) -> Validation.
# Contrato con Validation en FULL: responde {"estado": "OK"|"ERROR",
# "tabla_anterior": "<nombre>"|null}. Solo se borra una tabla con el prefijo
# de reconocer_master y distinta de la nueva.
locals {
  sfn_tabla_nueva = "States.Format('${var.dynamodb_reconocer_master_prefix}{}', $.lectura.manifiesto.run_id)"

  # Tags de la tabla que crea el S3 Import (el Import no acepta tags al crear).
  sfn_tabla_tags = [for k, v in local.default_tags : { Key = k, Value = v }]

  sfn_lambda_retry = [{
    ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"],
    IntervalSeconds = 2,
    MaxAttempts     = 3,
    BackoffRate     = 2
  }]

  sfn_import_table_params = merge(
    {
      "TableName.$" = local.sfn_tabla_nueva,
      AttributeDefinitions = [
        { AttributeName = "pk", AttributeType = "S" },
        { AttributeName = "sk", AttributeType = "S" }
      ],
      KeySchema = [
        { AttributeName = "pk", KeyType = "HASH" },
        { AttributeName = "sk", KeyType = "RANGE" }
      ],
      BillingMode = "PAY_PER_REQUEST"
    },
    local.kms_key_arn != null ? {
      SSESpecification = { Enabled = true, SSEType = "KMS", KMSMasterKeyId = local.kms_key_arn }
    } : {}
  )
}

resource "aws_cloudwatch_log_group" "sfn_updrecmaster" {
  name              = "/aws/vendedlogs/states/${local.names.sfn_updrecmaster}"
  retention_in_days = 90
  kms_key_id        = local.kms_key_arn
}

resource "aws_sfn_state_machine" "updrecmaster" {
  name     = local.names.sfn_updrecmaster
  role_arn = module.sfn_updrecmaster_role.role_arn

  definition = jsonencode({
    Comment = "Actualiza reconocer_master a partir del CTL final publicado en Triggers_reconocer (FULL: S3 Import, DELTA: Glue)",
    StartAt = "LeerCtlFinal",
    States = {
      LeerCtlFinal = {
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
        Next       = "TipoDeCarga"
      },
      TipoDeCarga = {
        Type = "Choice",
        Choices = [{
          Variable     = "$.lectura.manifiesto.tipo_carga",
          StringEquals = "FULL",
          Next         = "NombreTablaNueva"
        }],
        Default = "ProcesarDominios"
      },

      # ---------------- FULL ----------------
      NombreTablaNueva = {
        Type       = "Pass",
        Parameters = { "nombre.$" = local.sfn_tabla_nueva },
        ResultPath = "$.tabla_nueva",
        Next       = "ImportarTabla"
      },
      ImportarTabla = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:dynamodb:importTable",
        Parameters = {
          "ClientToken.$" = "$.lectura.manifiesto.run_id",
          S3BucketSource = {
            "S3Bucket.$"    = "$.detail.bucket.name",
            "S3KeyPrefix.$" = "States.Format('${var.novedades_prefix}{}/data/', $.lectura.manifiesto.run_id)"
          },
          InputFormat             = "CSV",
          InputCompressionType    = "GZIP",
          TableCreationParameters = local.sfn_import_table_params
        },
        ResultSelector = {
          "import_arn.$" = "$.ImportTableDescription.ImportArn",
          "table_arn.$"  = "$.ImportTableDescription.TableArn"
        },
        ResultPath = "$.importacion",
        Next       = "EsperarImport"
      },
      EsperarImport = {
        Type    = "Wait",
        Seconds = var.sfn_import_poll_seconds,
        Next    = "RevisarImport"
      },
      RevisarImport = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:dynamodb:describeImport",
        Parameters = {
          "ImportArn.$" = "$.importacion.import_arn"
        },
        ResultSelector = {
          "descripcion.$" = "$.ImportTableDescription"
        },
        ResultPath = "$.importacion.estado",
        Next       = "ImportTermino"
      },
      ImportTermino = {
        Type = "Choice",
        Choices = [
          {
            Variable     = "$.importacion.estado.descripcion.ImportStatus",
            StringEquals = "COMPLETED",
            Next         = "EtiquetarTabla"
          },
          {
            Variable     = "$.importacion.estado.descripcion.ImportStatus",
            StringEquals = "IN_PROGRESS",
            Next         = "EsperarImport"
          }
        ],
        Default = "ImportFallido"
      },
      ImportFallido = {
        Type  = "Fail",
        Error = "ImportFallido",
        Cause = "El S3 Import no termino en COMPLETED (CANCELLED o FAILED). Revisar el log del Import en CloudWatch."
      },
      EtiquetarTabla = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:dynamodb:tagResource",
        Parameters = {
          "ResourceArn.$" = "$.importacion.table_arn",
          Tags            = local.sfn_tabla_tags
        },
        ResultPath = null,
        Next       = "ValidarFull"
      },
      ValidarFull = {
        Type     = "Task",
        Resource = "arn:aws:states:::lambda:invoke",
        Parameters = {
          FunctionName = local.arns.lambda_validation,
          Payload = {
            "run_id.$"      = "$.lectura.manifiesto.run_id",
            "tipo_carga.$"  = "$.lectura.manifiesto.tipo_carga",
            "dominios.$"    = "$.lectura.manifiesto.dominios",
            "tabla_nueva.$" = "$.tabla_nueva.nombre",
            "importacion.$" = "$.importacion.estado.descripcion"
          }
        },
        ResultSelector = {
          "resultado.$" = "$.Payload"
        },
        ResultPath = "$.validacion",
        Retry      = local.sfn_lambda_retry,
        Next       = "ValidacionFullOk"
      },
      ValidacionFullOk = {
        Type = "Choice",
        Choices = [{
          Variable     = "$.validacion.resultado.estado",
          StringEquals = "OK",
          Next         = "HayTablaAnterior"
        }],
        Default = "ValidacionFallida"
      },
      ValidacionFallida = {
        Type  = "Fail",
        Error = "ValidacionFallida",
        Cause = "La Validation no aprobo la carga FULL: el puntero no se cambio y la tabla nueva queda para revision."
      },
      HayTablaAnterior = {
        Type = "Choice",
        Choices = [{
          And = [
            { Variable = "$.validacion.resultado.tabla_anterior", IsPresent = true },
            { Variable = "$.validacion.resultado.tabla_anterior", IsString = true },
            { Variable = "$.validacion.resultado.tabla_anterior", StringMatches = "${var.dynamodb_reconocer_master_prefix}*" },
            { Not = { Variable = "$.validacion.resultado.tabla_anterior", StringEqualsPath = "$.tabla_nueva.nombre" } }
          ],
          Next = "EsperarAntesDeBorrar"
        }],
        Default = "Fin"
      },
      EsperarAntesDeBorrar = {
        Type    = "Wait",
        Seconds = var.sfn_delete_wait_seconds,
        Next    = "BorrarTablaAnterior"
      },
      BorrarTablaAnterior = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:dynamodb:deleteTable",
        Parameters = {
          "TableName.$" = "$.validacion.resultado.tabla_anterior"
        },
        ResultPath = null,
        Retry = [{
          ErrorEquals     = ["DynamoDb.ResourceInUseException", "DynamoDb.LimitExceededException"],
          IntervalSeconds = 30,
          MaxAttempts     = 5,
          BackoffRate     = 2
        }],
        Catch = [{
          ErrorEquals = ["DynamoDb.ResourceNotFoundException"],
          ResultPath  = null,
          Next        = "Fin"
        }],
        Next = "Fin"
      },
      Fin = {
        Type = "Succeed"
      },

      # ---------------- DELTA ----------------
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
              Retry      = local.sfn_lambda_retry,
              End        = true
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
