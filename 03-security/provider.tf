terraform {
  required_version = ">= 1.5.7"
  backend "s3" {
    bucket         = "cloudaura-io-prod-tfstate"
    key            = "security/users-iam.tfstate"
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
provider "aws" { region = "us-east-2" }
data "terraform_remote_state" "eks_data" {
  backend = "s3"
  config = {
    bucket = "cloudaura-io-prod-tfstate"
    key    = "infrastructure/eks.tfstate"
    region = "us-east-2"
  }
}
