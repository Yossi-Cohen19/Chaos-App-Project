include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_env/addons-integrations.hcl"
}

# Generate external-dns IRSA fixes automatically
generate "external_dns_fixes" {
  path      = "external-dns-fixes.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    # External-DNS ServiceAccount Annotation
    resource "kubernetes_annotations" "external_dns_sa_annotation" {
      api_version = "v1"
      kind        = "ServiceAccount"
      metadata {
        name      = "external-dns-sa"
        namespace = "external-dns"
      }
      annotations = {
        "eks.amazonaws.com/role-arn" = var.external_dns_role_arn
      }
      force = true
      
      depends_on = [module.external_dns]
    }

    # External-DNS Route53 IAM Policy
    resource "aws_iam_role_policy" "external_dns_route53" {
      name = "Route53Access"
      role = var.external_dns_role_name

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "route53:ChangeResourceRecordSets"
            ]
            Resource = "arn:aws:route53:::hostedzone/*"
          },
          {
            Effect = "Allow"
            Action = [
              "route53:ListHostedZones",
              "route53:ListResourceRecordSets"
            ]
            Resource = "*"
          }
        ]
      })
    }

    # Variables for external-dns fixes
    variable "external_dns_role_arn" {
      description = "IAM role ARN for external-dns IRSA"
      type        = string
    }

    variable "external_dns_role_name" {
      description = "IAM role name for external-dns"
      type        = string
    }
  EOT
}

# Import Common K8s Config
include "k8s" {
  path = "${get_terragrunt_dir()}/../../../../_env/k8s_addons.hcl"
}

# Specific dependencies
dependency "external_secrets_irsa" {
  config_path = "../external-secrets-irsa"
  
  mock_outputs = {
    iam_role_arn = "arn:aws:iam::${get_aws_account_id()}:role/external-secrets-operator-mock"
  }
  
  skip_outputs = false
}

dependency "external_dns_irsa" {
  config_path = "../external-dns-irsa"
  
  mock_outputs = {
    iam_role_arn  = "arn:aws:iam::${get_aws_account_id()}:role/external-dns-mock"
    iam_role_name = "external-dns-mock"
  }
  
  skip_outputs = false
}

# Inputs are merged. K8s inputs come from k8s_addons.hcl
inputs = {
  # Pass IRSA role ARN for External Secrets
  external_secrets = {
    service_account_role_arn = dependency.external_secrets_irsa.outputs.iam_role_arn
  }

  # Pass IRSA role ARN for External DNS
  external_dns = {
    service_account_role_arn = dependency.external_dns_irsa.outputs.iam_role_arn
    
    # Use Helm set to annotate ServiceAccount with IRSA role
    set = [
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = dependency.external_dns_irsa.outputs.iam_role_arn
      }
    ]
  }

  # ArgoCD App of Apps - Root application that auto-discovers child apps
  gitops_apps = [
    "${get_terragrunt_dir()}/../../../../../argocd-apps/clusters/dev.yaml",
  ]

  # Pass external-dns IRSA role details for automated fixes
  external_dns_role_arn  = dependency.external_dns_irsa.outputs.iam_role_arn
  external_dns_role_name = dependency.external_dns_irsa.outputs.iam_role_name
}

