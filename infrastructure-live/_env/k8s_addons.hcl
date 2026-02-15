# _env/k8s_addons.hcl

# 1. Common Dependency
dependency "eks" {
  config_path = "${get_terragrunt_dir()}/../eks"
  
  mock_outputs = {
    cluster_name                       = "chaos-dev-cluster"
    cluster_endpoint                   = "https://mock-endpoint"
    cluster_certificate_authority_data = "bW9jaw=="
    oidc_provider_arn                  = "arn:aws:iam::111111111111:oidc-provider/mock"
    cluster_version                    = "1.29"
  }
}

# 2. Common Provider Generation
terraform {
  before_hook "patch_kubectl_provider" {
    commands = ["init", "plan", "apply", "destroy"]
    execute  = ["/bin/bash", "-c", "cat > versions.tf <<EOF\nterraform {\n  required_version = \">= 1.3\"\n  required_providers {\n    aws = { source = \"hashicorp/aws\", version = \">= 5.38\" }\n    helm = { source = \"hashicorp/helm\", version = \"~> 2.0\" }\n    kubernetes = { source = \"hashicorp/kubernetes\", version = \">= 2.20\" }\n    kubectl = { source = \"gavinbunney/kubectl\", version = \"~> 1.14\" }\n    time = { source = \"hashicorp/time\", version = \">= 0.9.1\" }\n    random = { source = \"hashicorp/random\", version = \">= 3.0.0\" }\n  }\n}\nEOF"]
  }
}

generate "helm_provider" {
  path      = "helm-provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_eks_cluster_auth" "cluster" {
  name = "${dependency.eks.outputs.cluster_name}"
}

provider "helm" {
  kubernetes {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "kubectl" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}
EOF
}

# 3. Common Inputs
inputs = {
  cluster_name      = dependency.eks.outputs.cluster_name
  cluster_endpoint  = dependency.eks.outputs.cluster_endpoint
  cluster_version   = dependency.eks.outputs.cluster_version
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
}
