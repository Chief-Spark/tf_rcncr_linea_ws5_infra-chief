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
variable "dynamodb_reconocer_master_prefix" {
  description = "Prefijo de las tablas reconocer_master. En FULL la Step Function las crea con el S3 Import como <prefijo><run_id>. Vacio = roles sin acceso a estas tablas."
  type        = string
  default     = "reconocer_master_"
}

variable "dynamodb_metadata_control_table" {
  description = "Nombre de la tabla DynamoDB Metadata & Control (puntero a la tabla reconocer_master vigente). Se crea por otro proceso; vacio = roles sin acceso a esta tabla."
  type        = string
  default     = ""

  validation {
    condition     = var.dynamodb_metadata_control_table == "" || var.dynamodb_reconocer_master_prefix == "" || !startswith(var.dynamodb_metadata_control_table, var.dynamodb_reconocer_master_prefix)
    error_message = "La tabla de control no puede empezar por el prefijo de reconocer_master: la Step Function puede borrar tablas con ese prefijo."
  }
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
  Ajustes por Lambda (claves: authorizer, reclineacloud, validation, facturacion). Todo es opcional: lo omitido toma el
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
    condition     = alltrue([for k in keys(var.lambdas) : contains(["authorizer", "reclineacloud", "validation", "facturacion"], k)])
    error_message = "Las claves de var.lambdas deben ser authorizer, reclineacloud, validation o facturacion."
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

# --- Facturacion (Lambda de esta cuenta -> API de facturacion electronica) ---
variable "facturacion_api_url" {
  description = "URL del API Gateway de facturacion electronica (otra cuenta). Llega a la Lambda como FACTURACION_API_URL. Vacio = sin variable."
  type        = string
  default     = ""
}

variable "facturacion_api_execute_arn" {
  description = "ARN execute-api del API de facturacion electronica, solo si ese API usa autenticacion IAM. Vacio = sin permiso execute-api:Invoke."
  type        = string
  default     = ""

  validation {
    condition     = var.facturacion_api_execute_arn == "" || can(regex("^arn:aws:execute-api:[a-z0-9-]+:[0-9]{12}:.+$", var.facturacion_api_execute_arn))
    error_message = "facturacion_api_execute_arn debe ser un ARN execute-api (arn:aws:execute-api:<region>:<cuenta>:<api-id>/...)."
  }
}

variable "facturacion_visibility_timeout_seconds" {
  description = "Visibility timeout de la cola de facturacion (AWS recomienda >= 6 x timeout de la Lambda de Facturacion)."
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

  validation {
    condition     = var.redshift_bureau_role_arn == "" || can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.redshift_bureau_role_arn))
    error_message = "redshift_bureau_role_arn debe ser el ARN de un rol IAM (arn:aws:iam::<cuenta>:role/<nombre>)."
  }
}

variable "novedades_prefix" {
  description = "Carpeta de Triggers_reconocer donde el UNLOAD escribe cada corrida: <prefijo><run_id>/data/<tabla>/."
  type        = string
  default     = "nov/"
}

variable "ctl_final_name" {
  description = "Archivo de control que se escribe al terminar las 7 tablas (<prefijo><run_id>/<nombre>). Es el unico que dispara los flujos."
  type        = string
  default     = "7_tablas_finish.json"
}

# --- Cuenta Procesos Batch (novedades hacia Redshift Bureau) ---
variable "batch_account_id" {
  description = "Cuenta Procesos Batch que recibe el aviso del CTL final en su EventBridge. Vacio = no se crea la regla de reenvio."
  type        = string
  default     = ""
}

variable "batch_event_bus_name" {
  description = "Event bus de la cuenta Batch que recibe el aviso."
  type        = string
  default     = "default"
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

variable "sfn_import_poll_seconds" {
  description = "FULL: segundos entre cada revision del estado del S3 Import."
  type        = number
  default     = 60
}

variable "sfn_delete_wait_seconds" {
  description = "FULL: segundos de espera entre el cambio de puntero y el borrado de la tabla anterior."
  type        = number
  default     = 300
}
