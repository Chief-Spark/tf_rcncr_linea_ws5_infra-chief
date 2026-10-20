# Roles de Redshift sobre Triggers_reconocer. Se crean aqui (uno por operacion,
# minimo privilegio) en vez de reusar los roles existentes de la cuenta:
# RedshiftScheduler es para pausa/reanudacion y reconocerbatch-redshift-xacctRole
# es de otro equipo.

# --- UNLOAD: Redshift Reconocer (cuenta 147) escribe el UNLOAD + manifiesto. ---
# Misma cuenta que el bucket: basta con esta policy, sin bucket policy.
# El rol se ASOCIA al namespace de Redshift fuera de este repo (lo hace quien lo
# administra): gestionarlo aqui pisaria los roles que el namespace ya tiene.
data "aws_iam_policy_document" "redshift_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["redshift.amazonaws.com", "redshift-serverless.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "redshift_unload" {
  source_policy_documents = [data.aws_iam_policy_document.kms_use.json]

  statement {
    sid       = "ListTriggers"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [local.arns.s3_triggers]
  }

  # DeleteObject: UNLOAD con ALLOWOVERWRITE / CLEANPATH.
  statement {
    sid = "UnloadTriggers"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${local.arns.s3_triggers}/*"]
  }
}

module "redshift_unload_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-redshift-unload" # BURoleFor-dev-647096294147-rcncr-ws5-redshift-unload
  role_description     = "Role for Redshift Reconocer to UNLOAD into Triggers_reconocer"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.redshift_assume_role.json

  policy_name        = "-${local.name_prefix}-redshift-unload" # BUPolicyFor-dev-647096294147-rcncr-ws5-redshift-unload
  policy_description = "Write access to Triggers_reconocer for Redshift UNLOAD"
  policy_documents   = [data.aws_iam_policy_document.redshift_unload.json]

  # Redshift llama a S3 desde su red: excepcion a la bucket policy de eits-tf-aws-s3.
  tags = merge(local.default_tags, local.s3_exception_tags)
}

# --- COPY: Redshift Bureau (cuenta Procesos Batch) lee Triggers_reconocer. ---
# Role chaining: IAM_ROLE '<rol Bureau en su cuenta>,<este rol>'. El acceso al
# bucket queda dentro de la 147. La otra punta (sts:AssumeRole sobre este rol en
# la policy del rol del Bureau) se configura en la otra cuenta.
# Se crea solo cuando se conoce el ARN del rol del Bureau.
data "aws_iam_policy_document" "redshift_copy_trust" {
  count = var.redshift_bureau_role_arn != "" ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.redshift_bureau_role_arn]
    }
  }
}

data "aws_iam_policy_document" "redshift_copy" {
  source_policy_documents = [data.aws_iam_policy_document.kms_use.json]

  statement {
    sid       = "ListTriggers"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [local.arns.s3_triggers]
  }

  statement {
    sid       = "ReadTriggers"
    actions   = ["s3:GetObject"]
    resources = ["${local.arns.s3_triggers}/*"]
  }
}

module "redshift_copy_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = var.redshift_bureau_role_arn != "" ? 1 : 0

  create_role          = var.enable_create_role
  role_name            = "-${local.name_prefix}-redshift-copy-xacct" # BURoleFor-dev-647096294147-rcncr-ws5-redshift-copy-xacct
  role_description     = "Cross-account role chained by Redshift Bureau to COPY from Triggers_reconocer"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.redshift_copy_trust[0].json

  policy_name        = "-${local.name_prefix}-redshift-copy-xacct" # BUPolicyFor-dev-647096294147-rcncr-ws5-redshift-copy-xacct
  policy_description = "Read access to Triggers_reconocer for Redshift Bureau COPY"
  policy_documents   = [data.aws_iam_policy_document.redshift_copy.json]

  tags = merge(local.default_tags, local.s3_exception_tags)
}
