terraform {
  backend "s3" {
    bucket  = "dto-terraform-647096294147"
    key     = "rcncr-linea-ws5/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
