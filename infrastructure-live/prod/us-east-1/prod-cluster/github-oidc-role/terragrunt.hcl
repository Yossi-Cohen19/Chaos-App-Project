terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-github-oidc-role?version=5.48.0"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "oidc_provider" {
  config_path = "../github-oidc-provider"
  skip_outputs = true
}

dependency "ecr" {
  config_path = "../ecr"
  
  mock_outputs = {
    repository_arn = "arn:aws:ecr:us-east-1:${get_aws_account_id()}:repository/chaos-platform-app-prod-mock"
  }
}

inputs = {
  name = "github-actions-ecr-push-prod"

  subjects = ["${get_env("GITHUB_REPO", "Yossi-Cohen19/Chaos-App-Project")}:*"]

  role_policy_arns = {}
  
  create_role = true
  
  force_detach_policies = true
  
  tags = {
    Environment = "Prod"
    Purpose     = "GitHub Actions ECR Push"
  }
}

generate "ecr_policy" {
  path      = "ecr-policy.tf"
  if_exists = "overwrite"
  contents  = <<EOF
resource "aws_iam_policy" "ecr_push_prod" {
  name        = "github-actions-ecr-push-prod-policy"
  description = "Policy for GitHub Actions to push to ECR (Prod)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "${dependency.ecr.outputs.repository_arn}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_push_prod" {
  role       = "github-actions-ecr-push-prod"
  policy_arn = aws_iam_policy.ecr_push_prod.arn
  
  depends_on = [aws_iam_policy.ecr_push_prod]
}
EOF
}
