# Buckets del flujo de actualizacion de Base_Online (libreria eits-tf-aws-s3).
# Nombre final: <prefix>-<bucket_name>-s3.

# Triggers_reconocer: recibe el UNLOAD del Redshift Reconocer (cuenta 147) +
# manifiesto, y desde aqui el Redshift Bureau (cuenta Procesos Batch) hace COPY.
data "aws_iam_policy_document" "triggers_access" {
  dynamic "statement" {
    for_each = length(var.triggers_writer_principal_arns) > 0 ? [1] : []
    content {
      sid       = "AllowUnloadWriters"
      actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation", "s3:AbortMultipartUpload"]
      resources = [local.arns.s3_triggers, "${local.arns.s3_triggers}/*"]

      principals {
        type        = "AWS"
        identifiers = var.triggers_writer_principal_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.triggers_reader_principal_arns) > 0 ? [1] : []
    content {
      sid       = "AllowCopyReaders"
      actions   = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
      resources = [local.arns.s3_triggers, "${local.arns.s3_triggers}/*"]

      principals {
        type        = "AWS"
        identifiers = var.triggers_reader_principal_arns
      }
    }
  }
}

locals {
  triggers_has_access_policy = length(var.triggers_writer_principal_arns) + length(var.triggers_reader_principal_arns) > 0
}

module "s3_triggers" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-s3.git?ref=2.19.2"

  prefix                  = local.name_prefix
  bucket_name             = "triggers-reconocer" # => dev-647096294147-rcncr-ws5-triggers-reconocer-s3
  sse_algorithm           = local.kms_key_arn == null ? "AES256" : "aws:kms"
  kms_key_arn             = local.kms_key_arn
  source_policy_documents = local.triggers_has_access_policy ? [data.aws_iam_policy_document.triggers_access.json] : []

  tags = local.default_tags
}

# EventBridge Update escucha los "Object Created" de este bucket.
resource "aws_s3_bucket_notification" "triggers" {
  bucket      = module.s3_triggers.s3_bucket_id
  eventbridge = true
}

# Upload_Staging: datos transformados y validados (checkpoint / re-derivacion).
module "s3_staging" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-s3.git?ref=2.19.2"

  prefix        = local.name_prefix
  bucket_name   = "upload-staging" # => dev-647096294147-rcncr-ws5-upload-staging-s3
  sse_algorithm = local.kms_key_arn == null ? "AES256" : "aws:kms"
  kms_key_arn   = local.kms_key_arn

  tags = local.default_tags
}
