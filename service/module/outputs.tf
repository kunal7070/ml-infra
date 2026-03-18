output "instance_id" {
  value = aws_instance.jump_host.id
}

output "private_ip" {
  value = aws_instance.jump_host.private_ip
}

output "security_group_id" {
  value = var.create_security_group ? aws_security_group.jump_host[0].id : null
}

output "instance_role_name" {
  value = var.create_instance_role ? aws_iam_role.jump_host[0].name : null
}

output "instance_role_arn" {
  value = var.create_instance_role ? aws_iam_role.jump_host[0].arn : null
}

output "instance_profile_name" {
  value = var.create_instance_role ? aws_iam_instance_profile.jump_host[0].name : var.existing_instance_profile_name
}

output "ssm_document_names" {
  value = var.create_ssm_documents ? [
    aws_ssm_document.eks_names[0].name,
    aws_ssm_document.eks_kubectl[0].name
  ] : []
}

output "ssm_target_tag_key" {
  value = var.ssm_target_tag_key
}

output "ssm_target_tag_value" {
  value = var.ssm_target_tag_value
}