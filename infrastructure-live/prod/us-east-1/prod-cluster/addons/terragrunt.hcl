include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_env/addons-networking.hcl"
}

# Import Common K8s Config
include "k8s" {
  path = "${get_terragrunt_dir()}/../../../../_env/k8s_addons.hcl"
}

# Dependencies and inputs are inherited from k8s_addons.hcl
