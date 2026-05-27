variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name — used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "team" {
  description = "Owning team name"
  type        = string
  default     = "platform"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "endpoint_public_access" {
  description = "Enable public EKS API endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_groups" {
  description = "EKS node group configurations"
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
  description = "EKS managed addon versions"
  type        = map(string)
  default = {
    "vpc-cni"                = "v1.18.1-eksbuild.3"
    "coredns"                = "v1.11.1-eksbuild.9"
    "kube-proxy"             = "v1.29.3-eksbuild.2"
    "aws-ebs-csi-driver"     = "v1.30.0-eksbuild.1"
    "eks-pod-identity-agent" = "v1.3.0-eksbuild.1"
  }
}
