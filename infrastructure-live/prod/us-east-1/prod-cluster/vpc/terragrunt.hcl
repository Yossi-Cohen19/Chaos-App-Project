include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_env/vpc.hcl"
}

inputs = {
  name = "chaos-prod-vpc"
  cidr = "10.1.0.0/16"
  azs  = ["us-east-1a", "us-east-1b"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  private_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  database_subnets = ["10.1.201.0/24", "10.1.202.0/24"]
  public_subnets   = ["10.1.101.0/24", "10.1.102.0/24"]

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/chaos-prod-cluster"  = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/chaos-prod-cluster"  = "shared"
    "karpenter.sh/discovery"                    = "chaos-prod-cluster"
  }
}
