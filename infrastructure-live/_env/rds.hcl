# infrastructure-live/_env/rds.hcl

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.4.0"
}

inputs = {
  identifier = "chaos-db"
  engine               = "postgres"
  engine_version       = "16" 
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  username = "chaos_admin"
  port     = 5432

  # Using AWS Secrets Manager for password management
  manage_master_user_password = true
  
  # High Availability & Security
  multi_az               = false  # Set to true for production
  publicly_accessible    = false
  
  # Encryption at rest (production requirement)
  storage_encrypted      = true
  
  # Backup Configuration
  backup_retention_period = 7  # Increase to 30 for production compliance
  backup_window          = "03:00-04:00"  # UTC
  maintenance_window     = "Mon:04:00-Mon:05:00"  # UTC
  copy_tags_to_snapshot  = true
  
  # Final snapshot - CRITICAL: Set to false only for dev, true for production
  skip_final_snapshot    = true  # Override in prod to false
  
  # Performance Insights (optional, adds cost)
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
}
