terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Melhor prática: Adicione um backend S3 para manter seu estado (state)
  # backend "s3" {
  #   bucket = "meu-bucket-terraform-state"
  #   key    = "monitoring/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}