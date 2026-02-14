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
    repository_arn = "arn:aws:ecr:us-east-1:${get_aws_account_id()}:repository/chaos-platform-app-dev-mock"
  }
}

inputs = {
  name = "github-actions-ecr-push"

  subjects = ["${get_env("GITHUB_REPO", "Yossi-Cohen19/Chaos-App-Project")}:*"]

  # Use role_policy_arns for inline policies (the module will create them)
  role_policy_arns = {}
  
  # Create inline policy directly
  create_role = true
  
  # Additional configuration to attach inline policy
  force_detach_policies = true
  
  tags = {
    Environment = "Dev"
    Purpose     = "GitHub Actions ECR Push"
  }
}

# We need to create the policy separately and attach it
# Let's use a different approach - generate block
generate "ecr_policy" {
  path      = "ecr-policy.tf"
  if_exists = "overwrite"
  contents  = <<EOF
resource "aws_iam_policy" "ecr_push" {
  name        = "github-actions-ecr-push-policy"
  description = "Policy for GitHub Actions to push to ECR"

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

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.ecr_push.arn
  
  depends_on = [aws_iam_policy.ecr_push]
}
EOF
}
