# Glue Job RecMas_Transform_and_Upload (libreria eits-tf-aws-glue). Una ejecucion
# por dominio, lanzada desde el Distributed Map de la Step Function. El script
# vive en otro repo y lo publica otro proceso: este repo NO sube archivos .py,
# solo apunta a su ubicacion en S3.
# La libreria siempre crea una base del Glue Data Catalog.
module "glue" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-glue.git?ref=1.5.1"

  database_name_prefix = local.name_prefix
  database_name        = "recmaster" # => dev-647096294147-rcncr-ws5-recmaster-glue
  database_description = "Reconocer Master Linea - catalogo de la carga de Base_Online"

  # Rol creado con eits-tf-aws-iam (nomenclatura BURoleFor-...), no el del modulo.
  create_service_role = false
  service_role_arn    = module.glue_transform_role.role_arn

  cloudwatch_log_group_name = local.names.glue_log_group

  jobs = {
    (local.names.glue_transform) = {
      description = "Transforma el Parquet de un dominio al modelo single-table, valida y escribe en Base_Online"
      command = {
        name            = "glueetl"
        script_location = local.glue_script_location
        python_version  = "3"
      }
      glue_version      = var.glue_job.glue_version
      worker_type       = var.glue_job.worker_type
      number_of_workers = var.glue_job.number_of_workers
      timeout           = var.glue_job.timeout
      max_retries       = var.glue_job.max_retries
      execution_property = {
        max_concurrent_runs = var.sfn_max_concurrency
      }
      default_arguments = merge(
        {
          "--job-language"    = "python"
          "--TempDir"         = "s3://${local.names.s3_staging}/glue-tmp/"
          "--BUCKET_TRIGGERS" = local.names.s3_triggers
          "--BUCKET_STAGING"  = local.names.s3_staging
        },
        { for k, v in local.dynamodb_env : "--${k}" => v }
      )
    }
  }

  tags = local.default_tags
}
