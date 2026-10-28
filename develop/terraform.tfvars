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

# --- Tablas DynamoDB (NO se crean con Terraform; solo se dan permisos) ---
# reconocer_master: en FULL la Step Function la crea con el S3 Import, una por
# corrida: <prefijo><run_id> (ej. reconocer_master_20261022T053000Z_FULL).
dynamodb_reconocer_master_prefix = "reconocer_master_"
# Metadata & Control (puntero a la tabla vigente): la crea otro proceso. No puede
# empezar por el prefijo de arriba (la Step Function borra tablas con ese prefijo).
dynamodb_metadata_control_table = "reconocer_metadata_control"

# Lambda RecMicroservicios existente: conecta la ruta del API Ext y permite que
# su rol publique en la cola de facturacion. Vacio = sin ruta Ext ni permiso.
recmicroservicios_function_name = ""

# --- Transversales ---
# CMK del stack (trunk/kms.tf): cifra S3, SQS, logs, Lambdas y las tablas del
# S3 Import. kms_key_arn solo si se usa una CMK existente (no ambos).
create_kms_key = true
kms_key_arn    = ""

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
#   reclineacloud = { handler = "<modulo>.<funcion>" }
# }
enable_lambdas = true

# null = fuera de VPC.
# lambda_vpc_config = { security_group_ids = ["sg-..."], subnet_ids = ["subnet-...", "subnet-..."] }

# Bucket de salida de PDFs de RecLineaCloud (modo pdf_s3). Vacio = sin permiso.
reclinea_output_bucket = ""

# --- Facturacion ---
# La Lambda de Facturacion (esta cuenta) lee la cola y llama al API de
# facturacion electronica (otra cuenta). PENDIENTE: URL del API y, si usa
# autenticacion IAM, su ARN execute-api. Vacio = la Lambda se crea igual.
facturacion_api_url         = ""
facturacion_api_execute_arn = ""

# --- Validacion de identidad (API de otra cuenta AWS) ---
# PENDIENTE: ARN del rol cross-account que entrega el dueno de Validacion de
# identidad. Ese rol debe confiar en BURoleFor-dev-647096294147-rcncr-ws5-lmbd-reclineacloud.
validacion_identidad_role_arn = ""

# --- Lotes (Cargue de archivos) ---
# Bucket RecMasterLotes, EventBridge, Step Function Lotes, Lambdas Parseo y
# Consolidar. Archivos de input/ y output_*/ se borran a los 30 dias; RecLineaCloud
# resuelve 5 registros a la vez; el lote falla con mas de 10 % de registros fallidos.
enable_lotes                       = true
lotes_retention_days               = 30
lotes_max_concurrency              = 5
lotes_tolerated_failure_percentage = 10
# PENDIENTE (Operacion): identidad AWS del Portal on-premise. Vacio = no se crea
# el rol portal-lotes.
lotes_portal_principal_arns = []

# --- Triggers_reconocer ---
# El rol redshift-unload se crea siempre; asociarlo al namespace del Redshift
# Reconocer (8eac1c32-7d63-4570-9906-334aa9903dc5) fuera de este repo.
# Rol del Redshift Bureau (cuenta Procesos Batch 651706752126) que hace el COPY.
# Lo crea el repo de infraestructura de la cuenta Batch CON ESTE NOMBRE y lo
# asocia al cluster Bureau. Aqui se crea redshift-copy-xacct confiando solo en
# ese rol (funciona aunque todavia no exista).
redshift_bureau_role_arn = "arn:aws:iam::651706752126:role/BURoleFor-dev-651706752126-rcncr-ws5-redshift-bureau-copy"

# --- Novedades (CTL final y reenvio a la cuenta Batch) ---
# El UNLOAD escribe <novedades_prefix><run_id>/data/<tabla>/ y al final
# <novedades_prefix><run_id>/<ctl_final_name>, que dispara los dos flujos.
novedades_prefix = "nov/"
ctl_final_name   = "7_tablas_finish.json"
# Cuenta Batch: recibe el mismo aviso en su EventBridge. Su bus debe permitir
# events:PutEvents desde esta cuenta (resource policy en la cuenta Batch).
batch_account_id     = "651706752126"
batch_event_bus_name = "default"
