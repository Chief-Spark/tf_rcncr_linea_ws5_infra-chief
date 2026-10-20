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
  description = "Nombre de la tabla DynamoDB Base_Online (reconocer_master)."
  type        = string
}

variable "dynamodb_metadata_control_table" {
  description = "Nombre de la tabla DynamoDB de Metadata & Control (puntero de version activa)."
  type        = string
}

variable "recmicroservicios_function_name" {
  description = "Nombre de la Lambda RecMicroservicios existente (destino del API Ext). Requerido si enable_lambdas = true."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_lambdas || var.recmicroservicios_function_name != ""
    error_message = "recmicroservicios_function_name es requerido cuando enable_lambdas = true (lo usa el API Gateway)."
  }
}

# --- Transversales ---
variable "kms_key_arn" {
  description = "ARN de la CMK (KMS) para S3/SQS/logs. Vacio = cifrado administrado por AWS (SSE-S3 / SSE-SQS)."
  type        = string
  default     = ""
}

variable "s3_source_ip_exception" {
  description = <<EOF
  La bucket policy de eits-tf-aws-s3 niega el acceso fuera de IPs de Experian / VPC endpoints. Glue, la Step Function
  y la Lambda Validation llaman a S3 desde la red de AWS, asi que sus roles llevan el tag eec:SourceIPException
  (excepcion prevista por la libreria). Poner false si se usa VPC + gateway endpoint de S3.
  EOF
  type        = bool
  default     = true
}

# --- Lambdas (el codigo vive en otros repos; aqui solo se apunta al paquete en S3) ---
variable "enable_lambdas" {
  description = "Crea las Lambdas y el API Gateway. Dejar en false hasta que los paquetes de codigo existan en S3."
  type        = bool
  default     = false
}

variable "lambdas" {
  description = "Configuracion por Lambda. Claves esperadas: authorizer, reclineacloud, validation."
  type = map(object({
    runtime                        = string
    handler                        = string
    s3_bucket                      = string
    s3_key                         = string
    memory_size                    = optional(number, 512)
    timeout                        = optional(number, 30)
    reserved_concurrent_executions = optional(number, 5)
    environment_variables          = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = !var.enable_lambdas || alltrue([for k in ["authorizer", "reclineacloud", "validation"] : contains(keys(var.lambdas), k)])
    error_message = "Con enable_lambdas = true, var.lambdas debe definir authorizer, reclineacloud y validation."
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
variable "apigw_create_cloudwatch_role" {
  description = "true solo si la cuenta NO tiene aun el rol BURoleForAPIGatewayCloudwatchGlobal (configuracion a nivel cuenta)."
  type        = bool
  default     = false
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
variable "triggers_writer_principal_arns" {
  description = "ARNs de los roles que escriben el UNLOAD + manifiesto en Triggers_reconocer (p. ej. el rol de Redshift)."
  type        = list(string)
  default     = []
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
