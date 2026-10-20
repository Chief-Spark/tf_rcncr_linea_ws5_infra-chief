variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (develop, qa, demo, production)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID where the stack is deployed (147)"
  type        = string
}

variable "app_id" {
  description = "Application ID for tagging"
  type        = string
}

variable "cost_string" {
  description = "Cost string for billing"
  type        = string
  default     = ""
}

variable "permissions_boundary" {
  description = "IAM permissions boundary policy name"
  type        = string
}

variable "project" {
  description = "Project identifier"
  type        = string
}

variable "enable_create_role" {
  description = "Toggle role creation in the eits-tf-aws-iam module."
  type        = bool
  default     = true
}

# --- Provider assume role (injected by Jenkins as TF_VAR_*) ---
variable "assume_role_arn" {
  description = "IAM role ARN the AWS provider assumes (Jenkins TF_VAR_assume_role_arn)"
  type        = string
  default     = ""
}

variable "assume_role_external_id" {
  description = "External ID for the provider assume role (Jenkins TF_VAR_assume_role_external_id)"
  type        = string
  default     = ""
}

# --- Recursos existentes (NO se despliegan en este repo) ---
variable "dynamodb_reconocer_master_table" {
  description = "Nombre de la tabla DynamoDB Base_Online (reconocer_master). Se crea por otro proceso; vacio = roles sin acceso a esta tabla."
  type        = string
  default     = ""
}

variable "dynamodb_metadata_control_table" {
  description = "Nombre de la tabla DynamoDB de Metadata & Control (puntero de version activa). Se crea por otro proceso; vacio = roles sin acceso a esta tabla."
  type        = string
  default     = ""
}

variable "recmicroservicios_function_name" {
  description = "Nombre de la Lambda RecMicroservicios EXISTENTE (no se despliega aqui). Se usa para la ruta del API Ext y para que su rol pueda publicar en la cola de facturacion."
  type        = string
  default     = ""
}

# --- Transversales ---
variable "kms_key_arn" {
  description = "ARN de la CMK (KMS) para S3/SQS/logs. Vacio = cifrado administrado por AWS (SSE-S3 / SSE-SQS)."
  type        = string
  default     = ""
}

variable "s3_disable_source_ip_check" {
  description = <<EOF
  La bucket policy por defecto de eits-tf-aws-s3 niega el acceso fuera de IPs de Experian / VPC endpoints. Glue, la
  Step Function, la Lambda Validation y Redshift llaman a S3 desde la red de AWS, asi que se desactiva esa regla en los
  buckets de este stack (la libreria lo deja registrado con el tag eitsce:sourceipcheck=disabled). Se mantienen la
  exigencia de HTTPS/TLS 1.2 y el control de acceso por IAM.
  EOF
  type        = bool
  default     = true
}

variable "s3_source_ip_exception" {
  description = "Tag eec:SourceIPException en los roles. NO usar en la 147: una SCP niega iam:TagRole con ese tag (build 74279)."
  type        = bool
  default     = false
}

# --- Lambdas (el codigo vive en otros repos; aqui solo se apunta al paquete en S3) ---
variable "enable_lambdas" {
  description = "Crea las Lambdas y el API Gateway. Interruptor para desactivarlos si hiciera falta."
  type        = bool
  default     = true
}

variable "lambdas" {
  description = <<EOF
  Ajustes por Lambda (claves: authorizer, reclineacloud, validation). Todo es opcional: lo omitido toma el
  default de lambda.tf. runtime y handler deben coincidir con el codigo real que publica el repo de codigo:
  update-function-code solo cambia el codigo, la configuracion la mantiene este repo.
  EOF
  type = map(object({
    runtime                        = optional(string)
    handler                        = optional(string)
    memory_size                    = optional(number)
    timeout                        = optional(number)
    reserved_concurrent_executions = optional(number)
    environment_variables          = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.lambdas) : contains(["authorizer", "reclineacloud", "validation"], k)])
    error_message = "Las claves de var.lambdas deben ser authorizer, reclineacloud o validation."
  }
}

variable "lambda_vpc_config" {
  description = "Subnets y security groups si las Lambdas van en VPC. null = fuera de VPC."
  type = object({
    security_group_ids = list(string)
    subnet_ids         = list(string)
  })
  default = null
}

variable "lambda_log_retention_days" {
  description = "Retencion de los log groups de las Lambdas."
  type        = number
  default     = 90
}

variable "reclinea_output_bucket" {
  description = "Bucket donde RecLineaCloud escribe los PDF (modo pdf_s3). Vacio = sin permiso."
  type        = string
  default     = ""
}

# --- API Gateway ---
variable "apigw_vpc_endpoint_ids" {
  description = "VPC endpoints (execute-api) por los que se expone el API privado. Default: e-Connect v3 interno de us-east-1 (el mismo que usa eits-tf-aws-api-gateway)."
  type        = list(string)
  default     = ["vpce-099b9bad5f18ee5a1"]
}

# --- Facturacion (la Lambda consumidora vive en otra cuenta) ---
variable "facturacion_consumer_principal_arns" {
  description = "ARNs de los roles (otra cuenta) que consumen la cola de facturacion. Vacio = sin acceso cross-account."
  type        = list(string)
  default     = []
}

variable "facturacion_visibility_timeout_seconds" {
  description = "Visibility timeout de la cola de facturacion (>= timeout de la Lambda consumidora)."
  type        = number
  default     = 60
}

variable "facturacion_max_receive_count" {
  description = "Intentos antes de mover el mensaje a la DLQ."
  type        = number
  default     = 5
}

# --- Triggers_reconocer ---
variable "redshift_bureau_role_arn" {
  description = "ARN del rol IAM asociado al Redshift Bureau (cuenta Procesos Batch) que hace el COPY. Vacio = no se crea el rol redshift-copy-xacct."
  type        = string
  default     = ""
}

variable "manifest_key_suffix" {
  description = "Sufijo de la key del manifiesto que dispara la Step Function."
  type        = string
  default     = "manifest.json"
}

# --- Glue ---
variable "glue_script_location" {
  description = "URI S3 del script del job. null = s3://<upload-staging>/glue-scripts/recmas_transform_and_upload.py"
  type        = string
  default     = null
}

variable "glue_job" {
  description = "Capacidad del Glue Job RecMas_Transform_and_Upload."
  type = object({
    glue_version      = optional(string, "5.0")
    worker_type       = optional(string, "G.1X")
    number_of_workers = optional(number, 10)
    timeout           = optional(number, 480)
    max_retries       = optional(number, 0)
  })
  default = {}
}

# --- Step Functions ---
variable "sfn_max_concurrency" {
  description = "Ramas paralelas del Distributed Map (una por dominio; el HLD define 7)."
  type        = number
  default     = 7
}
