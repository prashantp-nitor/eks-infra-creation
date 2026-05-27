output "node_role_arn" {
  description = "IAM role ARN shared by all node groups"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "IAM role name shared by all node groups"
  value       = aws_iam_role.node.name
}

output "node_security_group_id" {
  description = "Security group ID attached to all worker nodes"
  value       = aws_security_group.node.id
}

output "node_groups" {
  description = "Map of node group resources created"
  value       = aws_eks_node_group.this
}
