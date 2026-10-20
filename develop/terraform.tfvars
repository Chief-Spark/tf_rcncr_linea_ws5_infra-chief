# ===========================================================================
# env 'develop' -> cuenta 147 (647096294147). Stack en trunk/.
# ===========================================================================
environment          = "develop"
region               = "us-east-1"
account_id           = "647096294147"
app_id               = "29197"
cost_string          = "1850.CO.600.402014"
permissions_boundary = "BUPolicyForBoundaryDTO"
project              = "rcncr-ws5"
enable_create_role   = true

# --- Recursos existentes (NO se despliegan aqui) ---
# PENDIENTE: nombres reales de las tablas. Sin estos valores el plan falla a
# proposito, para no crear policies apuntando a tablas equivocadas.
# dynamodb_reconocer_master_table = "<POR_CONFIRMAR>"
# dynamodb_metadata_control_table = "<POR_CONFIRMAR>"

# Lambda RecMicroservicios existente (destino del API Ext). Requerida con enable_lambdas.
recmicroservicios_function_name = ""

# --- Transversales ---
# CMK que cifra S3/SQS/logs. Vacio = cifrado administrado por AWS (SSE-S3 / SSE-SQS).
kms_key_arn = ""

# Tag eec:SourceIPException en los roles de Glue, Step Function y Validation para
# pasar la bucket policy de eits-tf-aws-s3 (llaman a S3 desde la red de AWS).
s3_source_ip_exception = true

# --- Lambdas ---
# false hasta que los paquetes de codigo (otros repos) esten en S3.
enable_lambdas = false

# lambdas = {
#   authorizer    = { runtime = "<POR_CONFIRMAR>", handler = "<POR_CONFIRMAR>", s3_bucket = "<POR_CONFIRMAR>", s3_key = "<POR_CONFIRMAR>" }
#   reclineacloud = { runtime = "java21", handler = "<POR_CONFIRMAR>", s3_bucket = "<POR_CONFIRMAR>", s3_key = "<POR_CONFIRMAR>", memory_size = 2048, timeout = 29, reserved_concurrent_executions = 50 }
#   validation    = { runtime = "<POR_CONFIRMAR>", handler = "<POR_CONFIRMAR>", s3_bucket = "<POR_CONFIRMAR>", s3_key = "<POR_CONFIRMAR>", timeout = 300 }
# }

# null = fuera de VPC.
# lambda_vpc_config = { security_group_ids = ["sg-..."], subnet_ids = ["subnet-...", "subnet-..."] }

# Bucket de salida de PDFs de RecLineaCloud (modo pdf_s3). Vacio = sin permiso.
reclinea_output_bucket = ""

# --- Facturacion (consumidor en otra cuenta) ---
# PENDIENTE: ARN del rol de la Lambda de facturacion en la otra cuenta.
facturacion_consumer_principal_arns = []

# --- Triggers_reconocer ---
# PENDIENTE: ARN del rol de Redshift que hace el UNLOAD al bucket.
triggers_writer_principal_arns = []
