variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA role trust policies"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL (https://...) for IRSA condition keys"
  type        = string
}

variable "addon_versions" {
  description = "Version for each EKS managed add-on — check aws eks describe-addon-versions for latest"
  type        = map(string)
  default = {
    "vpc-cni"               = "v1.18.1-eksbuild.3"
    "coredns"               = "v1.11.1-eksbuild.9"
    "kube-proxy"            = "v1.29.3-eksbuild.2"
    "aws-ebs-csi-driver"    = "v1.30.0-eksbuild.1"
    "eks-pod-identity-agent" = "v1.3.0-eksbuild.1"
  }
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
