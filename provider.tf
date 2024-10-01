terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.26.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.11.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}