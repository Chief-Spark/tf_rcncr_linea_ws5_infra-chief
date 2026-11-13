# State de Terraform en la cuenta del ambiente (667397050561), mismo patron que
# DEV (dto-terraform-<cuenta>). No va en trunk/: el pipeline copia trunk/* a la
# carpeta del ambiente y pisaria este archivo.
terraform {
  backend "s3" {
    bucket  = "dto-terraform-667397050561"
    key     = "rcncr-linea-ws5/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
