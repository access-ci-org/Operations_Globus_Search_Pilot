terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.28.0"
    }
  }
  backend "s3" {
    bucket         = "access-ci-org-operations-terraform-state-storage"
    key            = "terraform/Operations_Globus_Search_Pilot/us-east-2/terraform-state-storage/state/terraform.tfstate"
    encrypt        = true
    region         = "us-east-2"
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-2"
  default_tags {
    tags = {
      "WBS"       = "ACCESS CONECT 1.2"
      "workspace" = "terraform - ${terraform.workspace}"
    }

  }
}
