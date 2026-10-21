# API Gateway REST privado, con recursos nativos de Terraform.
#   API Int -> RecLineaCloud      GET  /v1/sujetos/{tipo}/{numero}/reporte/{perfil}
#              Consumidor: Portal Reconocer. Sin authorizer: lo protege el API
#              PRIVATE y la resource policy (solo entra por el VPC endpoint).
#   API Ext -> RecMicroservicios  POST /v1/microservicios/{operacion}
#              Consumidor: Apigee. Con Lambda Authorizer (JWT Okta).
#              (Lambda EXISTENTE, no se despliega aqui; ruta solo si se da su nombre)
# Rutas tomadas del HLD.
#
# Por que no la libreria eits-tf-aws-api-gateway: sus "resources" solo admiten
# rutas de un nivel y las rutas anidadas exigen importar OpenAPI (PutRestApi). El
# rol de Jenkins solo puede crear/modificar APIs PRIVATE (condicion
# apigateway:Request/EndpointType) y la importacion de OpenAPI no llega como
# PRIVATE (build 74280: AccessDenied en apigateway:PUT /restapis/{id}). Con
# recursos nativos no hay importacion: cada recurso/metodo es un PUT sobre una
# subruta del API. Se replica lo que hacia la libreria: API PRIVATE expuesto por
# el VPC endpoint e-Connect v3, resource policy que solo admite ese endpoint,
# client certificate, rol de CloudWatch de la cuenta y un unico stage.
locals {
  api_enabled       = var.enable_lambdas
  apigw_ext_enabled = local.api_enabled && var.recmicroservicios_function_name != ""
}

# Lo creado por la libreria en builds anteriores pasa a estos recursos sin
# destruirse. (El REST API f5n3zwmioc quedo a medio crear y se reemplaza.)
moved {
  from = module.api[0].aws_api_gateway_rest_api.this
  to   = aws_api_gateway_rest_api.this[0]
}

moved {
  from = module.api[0].aws_api_gateway_client_certificate.this
  to   = aws_api_gateway_client_certificate.this[0]
}

moved {
  from = module.api[0].aws_api_gateway_account.global_settings
  to   = aws_api_gateway_account.this[0]
}

# --- Configuracion de cuenta/region: rol de CloudWatch (iam-apigw-cloudwatch.tf) ---
resource "aws_api_gateway_account" "this" {
  count = local.api_enabled ? 1 : 0

  cloudwatch_role_arn = module.apigw_cloudwatch_role.role_arn
}

# --- REST API privado ---
resource "aws_api_gateway_rest_api" "this" {
  count = local.api_enabled ? 1 : 0

  name        = "${local.names.api}-api" # => dev-647096294147-rcncr-ws5-reconocer-linea-api
  description = "Reconocer Master - consumo en linea (API Int y Ext)"

  endpoint_configuration {
    ip_address_type  = "dualstack"
    types            = ["PRIVATE"]
    vpc_endpoint_ids = var.apigw_vpc_endpoint_ids
  }

  tags = local.default_tags
}

data "aws_iam_policy_document" "apigw_resource_policy" {
  count = local.api_enabled ? 1 : 0

  statement {
    sid       = "AllowInvoke"
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.this[0].execution_arn}/*/*/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    sid       = "DenyOutsideVpce"
    effect    = "Deny"
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.this[0].execution_arn}/*/*/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = var.apigw_vpc_endpoint_ids
    }
  }
}

resource "aws_api_gateway_rest_api_policy" "this" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  policy      = data.aws_iam_policy_document.apigw_resource_policy[0].json
}

resource "aws_api_gateway_client_certificate" "this" {
  count = local.api_enabled ? 1 : 0

  description = "${local.names.api}-client-cert"
  tags        = local.default_tags
}

# --- Authorizer (Okta JWT): solo para los accesos desde Apigee (API Ext) ---
resource "aws_api_gateway_authorizer" "okta" {
  count = local.apigw_ext_enabled ? 1 : 0

  name                             = "${local.names.api}-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.this[0].id
  type                             = "TOKEN"
  identity_source                  = "method.request.header.Authorization"
  authorizer_uri                   = module.lambda["authorizer"].invoke_arn
  authorizer_result_ttl_in_seconds = 300
}

# --- Rutas: /v1/sujetos/{tipo}/{numero}/reporte/{perfil} ---
resource "aws_api_gateway_resource" "v1" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_rest_api.this[0].root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "sujetos" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.v1[0].id
  path_part   = "sujetos"
}

resource "aws_api_gateway_resource" "tipo" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.sujetos[0].id
  path_part   = "{tipo}"
}

resource "aws_api_gateway_resource" "numero" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.tipo[0].id
  path_part   = "{numero}"
}

resource "aws_api_gateway_resource" "reporte" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.numero[0].id
  path_part   = "reporte"
}

resource "aws_api_gateway_resource" "perfil" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.reporte[0].id
  path_part   = "{perfil}"
}

resource "aws_api_gateway_method" "reclinea" {
  count = local.api_enabled ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  resource_id   = aws_api_gateway_resource.perfil[0].id
  http_method   = "GET"
  authorization = "NONE" # Portal Reconocer: acceso por VPC endpoint, sin authorizer

  request_parameters = {
    "method.request.path.tipo"   = true
    "method.request.path.numero" = true
    "method.request.path.perfil" = true
  }
}

resource "aws_api_gateway_integration" "reclinea" {
  count = local.api_enabled ? 1 : 0

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.perfil[0].id
  http_method             = aws_api_gateway_method.reclinea[0].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = module.lambda["reclineacloud"].invoke_arn
  timeout_milliseconds    = 29000
}

# --- Rutas: /v1/microservicios/{operacion} (solo con RecMicroservicios) ---
resource "aws_api_gateway_resource" "microservicios" {
  count = local.apigw_ext_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.v1[0].id
  path_part   = "microservicios"
}

resource "aws_api_gateway_resource" "operacion" {
  count = local.apigw_ext_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.microservicios[0].id
  path_part   = "{operacion}"
}

resource "aws_api_gateway_method" "microservicios" {
  count = local.apigw_ext_enabled ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  resource_id   = aws_api_gateway_resource.operacion[0].id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.okta[0].id

  request_parameters = {
    "method.request.path.operacion" = true
  }
}

resource "aws_api_gateway_integration" "microservicios" {
  count = local.apigw_ext_enabled ? 1 : 0

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.operacion[0].id
  http_method             = aws_api_gateway_method.microservicios[0].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = data.aws_lambda_function.recmicroservicios[0].invoke_arn
  timeout_milliseconds    = 29000
}

# --- Deployment + stage ---
resource "aws_api_gateway_deployment" "this" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id

  # Redeploy cuando cambian rutas, metodos, integraciones o el authorizer.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.perfil,
      aws_api_gateway_method.reclinea,
      aws_api_gateway_integration.reclinea,
      aws_api_gateway_resource.operacion,
      aws_api_gateway_method.microservicios,
      aws_api_gateway_integration.microservicios,
      aws_api_gateway_authorizer.okta,
      aws_api_gateway_rest_api_policy.this,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.reclinea,
    aws_api_gateway_integration.microservicios,
    aws_api_gateway_rest_api_policy.this,
  ]
}

resource "aws_cloudwatch_log_group" "apigw_access" {
  count = local.api_enabled ? 1 : 0

  name              = "/aws/apigateway/${local.names.api}-api/access"
  retention_in_days = 90
  kms_key_id        = local.kms_key_arn
}

resource "aws_api_gateway_stage" "this" {
  count = local.api_enabled ? 1 : 0

  rest_api_id           = aws_api_gateway_rest_api.this[0].id
  deployment_id         = aws_api_gateway_deployment.this[0].id
  stage_name            = local.env_short
  client_certificate_id = aws_api_gateway_client_certificate.this[0].id
  xray_tracing_enabled  = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_access[0].arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      latency        = "$context.responseLatency"
      authorizerErr  = "$context.authorizer.error"
    })
  }

  tags = local.default_tags

  # El rol de CloudWatch de la cuenta debe estar configurado antes del stage.
  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_method_settings" "all" {
  count = local.api_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  stage_name  = aws_api_gateway_stage.this[0].stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = false
  }
}

# --- Permisos para que API Gateway invoque las Lambdas ---
resource "aws_lambda_permission" "apigw_authorizer" {
  count = local.apigw_ext_enabled ? 1 : 0

  statement_id  = "AllowApiGatewayAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda["authorizer"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[0].execution_arn}/authorizers/*"
}

resource "aws_lambda_permission" "apigw_reclineacloud" {
  count = local.api_enabled ? 1 : 0

  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda["reclineacloud"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[0].execution_arn}/*/GET/v1/sujetos/*"
}

# Agrega un statement a la resource policy de la Lambda existente RecMicroservicios.
resource "aws_lambda_permission" "apigw_recmicroservicios" {
  count = local.apigw_ext_enabled ? 1 : 0

  statement_id  = "AllowApiGatewayInvoke-${local.names.api}"
  action        = "lambda:InvokeFunction"
  function_name = var.recmicroservicios_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[0].execution_arn}/*/POST/v1/microservicios/*"
}
