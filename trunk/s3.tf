# Buckets del flujo de actualizacion de Base_Online (libreria eits-tf-aws-s3).
# Nombre final: <prefix>-<bucket_name>-s3.

# Triggers_reconocer: recibe el UNLOAD del Redshift Reconocer + manifiesto, y
# desde aqui el Redshift Bureau hace COPY. Ambos acceden con roles de esta cuenta
# (iam-redshift.tf), por eso no hace falta abrir la bucket policy.
module "s3_triggers" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-s3.git?ref=2.19.2"

  prefix        = local.name_prefix
  bucket_name   = "triggers-reconocer" # => dev-647096294147-rcncr-ws5-triggers-reconocer-s3
  sse_algorithm = local.kms_key_arn == null ? "AES256" : "aws:kms"
  kms_key_arn   = local.kms_key_arn

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
