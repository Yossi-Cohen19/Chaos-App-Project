terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider?version=5.48.0"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  tags = {
    Environment = "Dev"
    Purpose     = "GitHub Actions OIDC"
  }
}
