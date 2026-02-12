terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks?version=5.48.0"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::${get_aws_account_id()}:oidc-provider/oidc.eks.${get_aws_region()}.amazonaws.com/id/EXAMPLE"
  }
}

inputs = {
  role_name = "external-secrets-operator"

  oidc_providers = {
    main = {
      provider_arn               = dependency.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  role_policy_arns = {
    SecretsManagerRead = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  }

  # Custom policy for more granular control
  role_policies = {
    SecretsAccess = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
          ]
          Resource = "arn:aws:secretsmanager:${get_aws_region()}:${get_aws_account_id()}:secret:chaos-*"
        }
      ]
    })
  }

  tags = {
    Environment = "Dev"
    Purpose     = "External Secrets Operator"
  }
}
