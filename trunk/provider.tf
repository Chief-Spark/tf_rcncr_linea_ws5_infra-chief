terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Las librerias eits-tf-aws-* exigen provider 6.x (lambda >= 6.48.0).
      version = "~> 6.48"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }
}

# Cuenta 147 (647096294147): Reconocer Master Linea.
provider "aws" {
  region = var.region

  assume_role {
    role_arn    = var.assume_role_arn
    external_id = var.assume_role_external_id
  }

  default_tags {
    tags = local.default_tags
  }
}
