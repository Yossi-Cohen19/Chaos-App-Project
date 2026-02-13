include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_env/addons-integrations.hcl"
}

# Import Common K8s Config
include "k8s" {
  path = "${get_terragrunt_dir()}/../../../../_env/k8s_addons.hcl"
}

# Specific dependencies
dependency "addons_networking" {
  config_path = "../addons"
  skip_outputs = true
}

dependency "external_secrets_irsa" {
  config_path = "../external-secrets-irsa"
  
  mock_outputs = {
    iam_role_arn = "arn:aws:iam::${get_aws_account_id()}:role/external-secrets-operator-prod-mock"
  }
  
  skip_outputs = false
}

# Inputs are merged. K8s inputs come from k8s_addons.hcl
inputs = {
  # Pass IRSA role ARN for External Secrets
  external_secrets = {
    service_account_role_arn = dependency.external_secrets_irsa.outputs.iam_role_arn
  }

  gitops_apps = [
    "${get_terragrunt_dir()}/../../../../../argocd-apps/ingress-nginx.yaml",
    "${get_terragrunt_dir()}/../../../../../argocd-apps/prod-cluster-apps.yaml",
    "${get_terragrunt_dir()}/../../../../../argocd-apps/prometheus.yaml"
  ]
}
