project     = "daas"
environment = "dev"
team        = "platform"
aws_region  = "us-east-1"

vpc_cidr        = "10.2.0.0/16"
cluster_version = "1.29"

node_groups = {
  general = {
    instance_types = ["t3.medium", "t3a.medium"]
    capacity_type  = "SPOT"
    desired_size   = 2
    min_size       = 1
    max_size       = 4
    disk_size      = 50
    labels = {
      role = "general"
    }
  }
}
