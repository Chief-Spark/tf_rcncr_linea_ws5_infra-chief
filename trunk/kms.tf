# CMK del stack (libreria eits-tf-aws-kms). Cifra S3, SQS, logs, variables de
# entorno de las Lambdas y las tablas que crea el S3 Import.
# Alias: alias/<prefix>-recmaster-kms.
#
# Politica de la llave:
# - Administracion: la libreria agrega BUAdministratorAccessRole y el rol que
#   ejecuta Terraform (Jenkins).
# - Uso: se delega en IAM de esta cuenta (cada rol lleva kms_use en su policy).
#   Asi la llave no depende de que los roles existan ni crea ciclos rol <-> llave.
# - CloudWatch Logs: el servicio cifra los log groups de esta cuenta.
# El COPY de Bureau usa un rol de esta cuenta (redshift-copy-xacct), por eso no
# hace falta abrir la llave a la cuenta Batch.
module "kms" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git?ref=1.10.5"
  count  = var.create_kms_key ? 1 : 0

  prefix      = local.name_prefix
  aliases     = ["recmaster"] # => alias/dev-647096294147-rcncr-ws5-recmaster-kms
  description = "CMK de Reconocer Master Linea: S3, SQS, logs, Lambdas y DynamoDB"

  key_statements = {
    cuenta = {
      sid       = "UsoDelegadoEnIamDeLaCuenta"
      actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"]
      resources = ["*"]
      principals = [{
        type        = "AWS"
        identifiers = ["arn:aws:iam::${var.account_id}:root"]
      }]
    }
    logs = {
      sid       = "CloudWatchLogs"
      actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
      resources = ["*"]
      principals = [{
        type        = "Service"
        identifiers = ["logs.${var.region}.amazonaws.com"]
      }]
      condition = [{
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:*"]
      }]
    }
  }

  tags = local.default_tags
}
