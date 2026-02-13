terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider?version=5.48.0"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  # Note: GitHub OIDC provider is account-global.
  # If dev-cluster already created it, this will be a no-op import.
  tags = {
    Environment = "Prod"
    Purpose     = "GitHub Actions OIDC"
  }
}
