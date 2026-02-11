terraform {
  source = "tfr:///terraform-aws-modules/ecr/aws?version=1.6.0"
}

inputs = {
  repository_name = "chaos-platform-app"
  repository_image_scan_on_push = true
  repository_image_tag_mutability = "IMMUTABLE"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection    = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
