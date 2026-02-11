# infrastructure-live/_env/vpc.hcl

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.5.2"
}

inputs = {
  enable_dns_hostnames = true
  enable_dns_support   = true

  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false

  tags = {
    Module = "VPC"
  }
}