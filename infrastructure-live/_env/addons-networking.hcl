terraform {
  source = "tfr:///aws-ia/eks-blueprints-addons/aws?version=1.16.2"
}

inputs = {
  enable_metrics_server = true 
  enable_aws_load_balancer_controller = true 
  
  # Configure ALB controller to not block non-ALB ingress classes (e.g. nginx)
  aws_load_balancer_controller = {
    set = [
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
      }
    ]
  }

  # Ensure we don't enable integration addons here
  enable_external_secrets = false
  enable_argocd = false
}
