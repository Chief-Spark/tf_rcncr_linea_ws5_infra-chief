# API Gateway REST privado (libreria eits-tf-aws-api-gateway). La libreria crea
# siempre un API PRIVATE expuesto por el VPC endpoint e-Connect v3 de la region.
#   API Int -> RecLineaCloud      GET  /v1/sujetos/{tipo}/{numero}/reporte/{perfil}
#   API Ext -> RecMicroservicios  POST /v1/microservicios/{operacion}
#              (Lambda EXISTENTE, no se despliega aqui; ruta solo si se da su nombre)
# Rutas tomadas del HLD. Se define por OpenAPI porque los "resources" de la
# libreria solo admiten rutas de un nivel.
locals {
  apigw_ext_enabled = var.enable_lambdas && var.recmicroservicios_function_name != ""
}

locals {
  apigw_lambda_uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/%s/invocations"

  openapi = var.enable_lambdas ? jsonencode({
    openapi = "3.0.1"
    info = {
      title   = local.names.api
      version = "1.0"
    }
    paths = merge({
      "/v1/sujetos/{tipo}/{numero}/reporte/{perfil}" = {
        get = {
          parameters = [for p in ["tipo", "numero", "perfil"] : { name = p, in = "path", required = true, schema = { type = "string" } }]
          security   = [{ okta = [] }]
          x-amazon-apigateway-integration = {
            type                = "aws_proxy"
            httpMethod          = "POST"
            uri                 = format(local.apigw_lambda_uri, module.lambda["reclineacloud"].arn)
            passthroughBehavior = "when_no_match"
          }
        }
      } }, local.apigw_ext_enabled ? {
      "/v1/microservicios/{operacion}" = {
        post = {
          parameters = [{ name = "operacion", in = "path", required = true, schema = { type = "string" } }]
          security   = [{ okta = [] }]
          x-amazon-apigateway-integration = {
            type                = "aws_proxy"
            httpMethod          = "POST"
            uri                 = format(local.apigw_lambda_uri, data.aws_lambda_function.recmicroservicios[0].arn)
            passthroughBehavior = "when_no_match"
          }
        }
      }
    } : {})
    components = {
      securitySchemes = {
        okta = {
          type                         = "apiKey"
          name                         = "Authorization"
          in                           = "header"
          x-amazon-apigateway-authtype = "custom"
          x-amazon-apigateway-authorizer = {
            type                         = "token"
            authorizerUri                = format(local.apigw_lambda_uri, module.lambda["authorizer"].arn)
            authorizerResultTtlInSeconds = 300
          }
        }
      }
    }
  }) : null
}

module "api" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-api-gateway.git?ref=1.4.2"
  count  = var.enable_lambdas ? 1 : 0

  name          = local.names.api # => dev-647096294147-rcncr-ws5-reconocer-linea-api
  open_api_json = local.openapi

  create_cloudwatch_role = var.apigw_create_cloudwatch_role
  permissions_boundary   = local.permissions_boundary_arn

  deployment = {
    # Redeploy del stage cuando cambia la especificacion.
    triggers = { openapi = sha1(local.openapi) }
    stage = {
      stage_name           = local.env_short
      xray_tracing_enabled = true
    }
  }

  tags = local.default_tags
}

locals {
  api_execution_arn = var.enable_lambdas ? "arn:aws:execute-api:${var.region}:${var.account_id}:${module.api[0].id}" : null
}

resource "aws_lambda_permission" "apigw_authorizer" {
  count = var.enable_lambdas ? 1 : 0

  statement_id  = "AllowApiGatewayAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda["authorizer"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${local.api_execution_arn}/authorizers/*"
}

resource "aws_lambda_permission" "apigw_reclineacloud" {
  count = var.enable_lambdas ? 1 : 0

  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda["reclineacloud"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${local.api_execution_arn}/*/GET/v1/sujetos/*"
}

# Agrega un statement a la resource policy de la Lambda existente RecMicroservicios.
resource "aws_lambda_permission" "apigw_recmicroservicios" {
  count = local.apigw_ext_enabled ? 1 : 0

  statement_id  = "AllowApiGatewayInvoke-${local.names.api}"
  action        = "lambda:InvokeFunction"
  function_name = var.recmicroservicios_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${local.api_execution_arn}/*/POST/v1/microservicios/*"
}
