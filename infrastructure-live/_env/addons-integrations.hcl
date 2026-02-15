terraform {
  source = "tfr:///aws-ia/eks-blueprints-addons/aws?version=1.16.2"
}

inputs = {
  # Core networking is handled in addons-networking module
  enable_metrics_server = false
  enable_aws_load_balancer_controller = false
  
  # Enable integrations here
  enable_external_secrets = true
  enable_argocd = true
  
  # Disable cert-manager - SSL handled by ACM at NLB
  enable_cert_manager = false
  
  # Enable external-dns for automatic Route53 DNS record creation
  enable_external_dns = true
  
  argocd = {
    namespace = "argocd"
  }

  gitops_apps = [] # To be overridden in child terragrunt.hcl
}

generate "gitops" {
  path      = "gitops.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "gitops_apps" {
  description = "List of absolute paths to ArgoCD Application manifests to bootstrap"
  type        = list(string)
  default     = []
}

data "kubectl_file_documents" "app_docs" {
  for_each = toset(var.gitops_apps)
  content  = file(each.value)
}

locals {
  # Merge all parsed manifests into a single map
  all_docs = merge([
    for file_path, docs in data.kubectl_file_documents.app_docs : docs.manifests
  ]...)
}

resource "kubectl_manifest" "gitops_apps" {
  for_each  = local.all_docs
  yaml_body = each.value
  depends_on = [module.argocd]
}
EOF
}
