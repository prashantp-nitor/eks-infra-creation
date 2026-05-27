output "vpc_cni_role_arn" {
  description = "IRSA IAM role ARN for vpc-cni addon"
  value       = aws_iam_role.vpc_cni.arn
}

output "ebs_csi_role_arn" {
  description = "IRSA IAM role ARN for aws-ebs-csi-driver addon"
  value       = aws_iam_role.ebs_csi.arn
}
