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
  
  argocd = {
    namespace = "argocd"
  }
}
