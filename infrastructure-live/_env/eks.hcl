terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=20.31.0"
}

inputs = {
  cluster_version = "1.29"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  cluster_addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  eks_managed_node_groups = {
    general_spot = {
      name          = "general-spot-nodes"
      min_size      = 1
      max_size      = 3
      desired_size  = 2
      instance_types = ["t3.medium", "t3a.medium"]
      capacity_type  = "SPOT"
      
      labels = {
        lifecycle = "Ec2Spot"
        intent    = "apps"
      }
      disk_size = 20

      iam_role_additional_policies = {
         AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" 
      }
    }
  }
}
