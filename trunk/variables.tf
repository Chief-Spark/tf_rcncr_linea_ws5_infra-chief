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

# --- DynamoDB (NO se crean en este repo; solo se referencian por nombre) ---
variable "dynamodb_reconocer_master_table" {
  description = "Nombre de la tabla DynamoDB Base_Online (reconocer_master)."
  type        = string
}

variable "dynamodb_metadata_control_table" {
  description = "Nombre de la tabla DynamoDB de Metadata & Control (puntero de version activa)."
  type        = string
}

# --- Transversales ---
variable "kms_key_arn" {
  description = "ARN de la CMK (KMS) que cifra S3 y SQS. Vacio = sin permisos KMS en los roles."
  type        = string
  default     = ""
}

variable "lambda_vpc_enabled" {
  description = "Si las Lambdas van en VPC, agrega a sus roles los permisos de ENI."
  type        = bool
  default     = false
}

variable "reclinea_output_bucket" {
  description = "Bucket donde RecLineaCloud escribe los PDF (modo pdf_s3). Vacio = sin permiso."
  type        = string
  default     = ""
}
