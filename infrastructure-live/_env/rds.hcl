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

#Using AWS Secrets manager 
  manage_master_user_password = true
  multi_az               = false 
  publicly_accessible    = false 
  backup_retention_period = 7
  skip_final_snapshot     = true 
}
