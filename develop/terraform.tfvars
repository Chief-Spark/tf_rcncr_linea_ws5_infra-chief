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

# --- Recursos existentes (NO se despliegan aqui; solo se referencian) ---
# Tablas DynamoDB: se crean por otro proceso. Vacio = roles sin acceso a la
# tabla; poner el nombre cuando exista y redesplegar.
dynamodb_reconocer_master_table = ""
dynamodb_metadata_control_table = ""

# Lambda RecMicroservicios existente: conecta la ruta del API Ext y permite que
# su rol publique en la cola de facturacion. Vacio = sin ruta Ext ni permiso.
recmicroservicios_function_name = ""

# --- Transversales ---
# CMK que cifra S3/SQS/logs. Vacio = cifrado administrado por AWS (SSE-S3 / SSE-SQS).
kms_key_arn = ""

# Glue, Step Function, Validation y Redshift llaman a S3 desde la red de AWS: se
# desactiva la regla de IPs de origen de eits-tf-aws-s3 en nuestros buckets.
# (El tag eec:SourceIPException en los roles lo niega una SCP: build 74279.)
s3_disable_source_ip_check = true
s3_source_ip_exception     = false

# --- Lambdas ---
# Se crean con un paquete placeholder; el codigo real lo publica el pipeline de
# cada repo de codigo (update-function-code). Defaults en trunk/lambda.tf:
#   authorizer    python3.13  handler.lambda_handler
#   reclineacloud python3.13  handler.lambda_handler
#   validation    python3.13  handler.lambda_handler
# runtime y handler deben coincidir con el codigo real. Solo definir lo que cambie:
# lambdas = {
#   reclineacloud = { handler = "app.main.lambda_handler" }
# }
enable_lambdas = true

# null = fuera de VPC.
# lambda_vpc_config = { security_group_ids = ["sg-..."], subnet_ids = ["subnet-...", "subnet-..."] }

# Bucket de salida de PDFs de RecLineaCloud (modo pdf_s3). Vacio = sin permiso.
reclinea_output_bucket = ""

# --- Facturacion (consumidor en otra cuenta) ---
# PENDIENTE: ARN del rol de la Lambda de facturacion en la otra cuenta. Vacio =
# la cola se crea pero nadie de afuera la puede consumir todavia.
facturacion_consumer_principal_arns = []

# --- Triggers_reconocer ---
# El rol redshift-unload se crea siempre; asociarlo al namespace del Redshift
# Reconocer (8eac1c32-7d63-4570-9906-334aa9903dc5) fuera de este repo.
# PENDIENTE: ARN del rol IAM del Redshift Bureau (cuenta Procesos Batch) que hace
# el COPY. Vacio = no se crea el rol redshift-copy-xacct.
redshift_bureau_role_arn = ""
