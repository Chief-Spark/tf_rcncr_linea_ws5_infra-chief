# State de Terraform en la cuenta del ambiente (647096294147). Mismo bucket y key
# que tenia trunk/backend.tf: el state de DEV no cambia de lugar. No va en
# trunk/: el pipeline copia trunk/* a la carpeta del ambiente y pisaria este archivo.
terraform {
  backend "s3" {
    bucket  = "dto-terraform-647096294147"
    key     = "rcncr-linea-ws5/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
