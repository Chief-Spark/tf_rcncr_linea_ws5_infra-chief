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

# --- DynamoDB (NO se despliegan aqui; solo se referencian por nombre) ---
# PENDIENTE: confirmar los nombres reales. Sin estos valores el plan falla a
# proposito, para no crear policies apuntando a tablas equivocadas.
# dynamodb_reconocer_master_table = "<POR_CONFIRMAR>"
# dynamodb_metadata_control_table = "<POR_CONFIRMAR>"

# --- Transversales (opcionales) ---
# CMK que cifra S3/SQS (HLD: SSE-KMS CMK). Vacio = roles sin permisos KMS.
kms_key_arn = ""

# true si las Lambdas se despliegan en VPC (agrega permisos de ENI a sus roles).
lambda_vpc_enabled = false

# Bucket de salida de PDFs de RecLineaCloud (modo pdf_s3). Vacio = sin permiso.
reclinea_output_bucket = ""
