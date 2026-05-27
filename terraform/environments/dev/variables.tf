variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "team" {
  type    = string
  default = "platform"
}

variable "vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size      = number
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
}

variable "addon_versions" {
  type = map(string)
  default = {
    "vpc-cni"                = "v1.18.1-eksbuild.3"
    "coredns"                = "v1.11.1-eksbuild.9"
    "kube-proxy"             = "v1.29.3-eksbuild.2"
    "aws-ebs-csi-driver"     = "v1.30.0-eksbuild.1"
    "eks-pod-identity-agent" = "v1.3.0-eksbuild.1"
  }
}
