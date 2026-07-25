terraform {
    required_providers {
      aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

module "app" {
    source = "../../modules/app"
    environment = "stage"
    resource_name_prefix = "fsl-challenge-cristian"
}

output "cloudfront_url" {
    value = module.app.cloudfront_url
}

terraform {
  backend "s3" {
    bucket = "fsl-challenge-cristian-tfstate"
    key    = "stage/terraform.tfstate"
    region = "us-east-1"
  }
}

