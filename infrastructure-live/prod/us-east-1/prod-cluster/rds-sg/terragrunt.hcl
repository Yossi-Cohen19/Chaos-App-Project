include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_env/rds-sg.hcl"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id         = "vpc-00000000000000000"
    vpc_cidr_block = "10.1.0.0/16"
  }
}

inputs = {
  name        = "chaos-prod-db-sg"
  description = "Security group for Chaos Prod RDS instance"
  vpc_id      = dependency.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = dependency.vpc.outputs.vpc_cidr_block
    }
  ]
  
  egress_rules = ["all-all"]
}
