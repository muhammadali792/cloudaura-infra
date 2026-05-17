terraform {
  required_version = ">= 1.5.7"
  backend "s3" {
    bucket         = "cloudaura-io-prod-tfstate"
    key            = "infrastructure/eks.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-lock-table"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
locals {
  region = "us-east-2"
  name   = "my-eks-cluster"
  tags = {
    Project     = "my-eks-cluster"
    Environment = "Production"
  }
}
provider "aws" {
  region = local.region
}
data "terraform_remote_state" "vpc_data" {
  backend = "s3"
  config = {
    bucket = "cloudaura-io-prod-tfstate"
    key    = "networking/vpc.tfstate"
    region = "us-east-2"
  }
}
