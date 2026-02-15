terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks?version=5.48.0"
}

include "root" {
  path = find_in_parent_folders()
}

# Generate IAM policy for Route53 access automatically
generate "route53_policy" {
  path      = "route53-policy.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    # Create Route53 IAM policy for external-dns
    resource "aws_iam_role_policy" "route53_access" {
      name = "Route53Access"
      role = aws_iam_role.this[0].name

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
  EOT
}


dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::${get_aws_account_id()}:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  }
}

inputs = {
  role_name = "external-dns-${basename(dirname(dirname(get_terragrunt_dir())))}"

  oidc_providers = {
    main = {
      provider_arn               = dependency.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns-sa"]  # Fixed: correct SA name from Helm chart
    }
  }

  role_policy_arns = {}

  # Custom policy for Route 53 access
  role_policies = {
    Route53Access = jsonencode({
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

  tags = {
    Environment = basename(dirname(dirname(get_terragrunt_dir())))
    Purpose     = "External DNS for Route 53"
  }
}
