output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_certificate_authority" {
  description = "Base64-encoded cluster CA"
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — use this to create additional IRSA roles"
  value       = module.eks.oidc_provider_arn
}

output "node_role_arn" {
  description = "Node IAM role ARN"
  value       = module.node_groups.node_role_arn
}
