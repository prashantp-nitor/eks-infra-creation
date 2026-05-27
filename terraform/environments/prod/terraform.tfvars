project     = "daas"
environment = "prod"
team        = "platform"
aws_region  = "us-east-1"

vpc_cidr        = "10.0.0.0/16"
cluster_version = "1.29"

# Restrict to your VPN/office IP ranges in production
endpoint_public_access = true
public_access_cidrs    = ["0.0.0.0/0"]

node_groups = {
  # Dedicated system node group for critical add-ons (CoreDNS, kube-proxy, etc.)
  system = {
    instance_types = ["m5.large"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 2
    min_size       = 2
    max_size       = 4
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

  # General-purpose application node group
  application = {
    instance_types = ["m5.xlarge", "m5a.xlarge"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 3
    min_size       = 3
    max_size       = 10
    disk_size      = 100
    labels = {
      role = "application"
    }
  }

  # Spot node group for batch/non-critical workloads
  spot = {
    instance_types = ["m5.xlarge", "m5a.xlarge", "m4.xlarge", "m5d.xlarge"]
    capacity_type  = "SPOT"
    desired_size   = 2
    min_size       = 0
    max_size       = 20
    disk_size      = 100
    labels = {
      role                            = "spot"
      "node.kubernetes.io/lifecycle"  = "spot"
    }
    taints = [{
      key    = "spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }
}
