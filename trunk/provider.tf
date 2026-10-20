terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.51.1"
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
