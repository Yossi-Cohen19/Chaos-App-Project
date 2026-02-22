include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_env/rds.hcl"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id                     = "vpc-00000000"
    database_subnet_group_name = "default"
    default_security_group_id  = "sg-00000000"
    vpc_cidr_block             = "10.1.0.0/16"
  }
}

dependency "security_group" {
  config_path = "../rds-sg"
  mock_outputs = {
    security_group_id = "sg-00000000"
  }
}

inputs = {
  identifier           = "chaos-prod-db"
  db_subnet_group_name = dependency.vpc.outputs.database_subnet_group_name

  create_db_security_group = false
  vpc_security_group_ids   = [dependency.security_group.outputs.security_group_id]

  # Production overrides (from _env/rds.hcl best-practice TODOs)
  multi_az                = true   # Multi-AZ for high availability
  skip_final_snapshot     = false  # Protect data on destroy
  backup_retention_period = 30     # 30-day retention for compliance
}
