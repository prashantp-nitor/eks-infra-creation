project     = "daas"
environment = "staging"
team        = "platform"
aws_region  = "us-east-1"

vpc_cidr        = "10.1.0.0/16"
cluster_version = "1.29"

endpoint_public_access = true
public_access_cidrs    = ["0.0.0.0/0"]

node_groups = {
  system = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 2
    min_size       = 2
    max_size       = 3
    disk_size      = 50
    labels = {
      role = "system"
    }
    taints = [{
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }

  application = {
    instance_types = ["m5.large", "m5a.large"]
    capacity_type  = "SPOT"
    desired_size   = 2
    min_size       = 2
    max_size       = 6
    disk_size      = 50
    labels = {
      role = "application"
    }
  }
}
