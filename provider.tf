terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  region = var.region
  # profile     = "pro_test"
  access_key = var.access_key
  secret_key = var.secret_key
}