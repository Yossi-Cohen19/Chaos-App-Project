terraform {
  source = "tfr:///terraform-aws-modules/secrets-manager/aws?version=1.1.2"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "rds" {
  config_path = "../rds"
  mock_outputs = {
    db_instance_endpoint = "chaos-prod-db.xxxxx.us-east-1.rds.amazonaws.com:5432"
  }
}

inputs = {
  name = "chaos-prod-db"
  description = "Database credentials for Chaos Platform Prod"
  recovery_window_in_days = 0
  
  ignore_secret_changes = true
  
  secret_string = jsonencode({
    DATABASE_URL = "postgresql://chaos_admin:PASSWORD@${dependency.rds.outputs.db_instance_endpoint}/postgres"
  })

  tags = {
    Environment = "Prod"
    Purpose     = "Chaos App Database Secret"
  }
}
