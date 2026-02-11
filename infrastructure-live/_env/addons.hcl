terraform {
  source = "tfr:///aws-ia/eks-blueprints-addons/aws?version=1.16.2"
}

inputs = {
  enable_metrics_server = true 
  enable_aws_load_balancer_controller = true 
  enable_external_secrets = true
  enable_argocd = true
  argocd = {
    namespace = "argocd"
  }
}
