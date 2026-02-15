locals {
  # Extract environment from directory path: infrastructure-live/dev/... or infrastructure-live/prod/...
  # Returns "dev" or "prod" based on directory structure
  env_name = try(basename(dirname(dirname(get_terragrunt_dir()))), "dev")
  region   = "us-east-1"
  
  # SSL/TLS and DNS Configuration
  acm_certificate_arn = "arn:aws:acm:us-east-1:462645401469:certificate/f4a86e96-338c-4d0b-86d1-a2b38ee85a5c"
  route53_zone_id     = "Z07304452C813SOZ11CMZ"
  domain_name         = "yossi.site"
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket  = "chaos-platform-tf-state-${get_aws_account_id()}"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = local.region
    encrypt = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = {
      Project     = "ChaosEngineeringPlatform"
      Owner       = "Yossi_Cohen"
      ManagedBy   = "Terragrunt"
      Environment = "${local.env_name}"
    }
  }
}
EOF
}

generate "versions" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF
}