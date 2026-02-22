terraform {
  source = "tfr:///terraform-aws-modules/secrets-manager/aws?version=1.1.2"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "rds" {
  config_path = "../rds"
  mock_outputs = {
    db_instance_endpoint = "chaos-db.xxxxx.us-east-1.rds.amazonaws.com:5432"
  }
}

inputs = {
  name = "chaos-dev-db"
  description = "Database credentials for Chaos Platform Dev"
  recovery_window_in_days = 0
  
  # In a real scenario, we might want to ignore changes if the secret is managed externally or changed by rotation.
  # For now, we set the initial value.
  ignore_secret_changes = true
  
  secret_string = jsonencode({
    DATABASE_URL = "postgresql://chaos_admin:PASSWORD@${dependency.rds.outputs.db_instance_endpoint}/postgres"
  })

  tags = {
    Environment = "Dev"
    Purpose     = "Chaos App Database Secret"
  }
}
