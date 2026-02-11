include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_env/ecr.hcl"
}

inputs = {
  repository_name = "chaos-platform-app-dev"
  
  repository_image_tag_mutability = "MUTABLE"
}
