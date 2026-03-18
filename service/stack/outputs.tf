output "instance_id" {
  value = module.servicenow_eks_jumphost.instance_id
}

output "private_ip" {
  value = module.servicenow_eks_jumphost.private_ip
}

output "instance_role_name" {
  value = module.servicenow_eks_jumphost.instance_role_name
}

output "instance_role_arn" {
  value = module.servicenow_eks_jumphost.instance_role_arn
}

output "instance_profile_name" {
  value = module.servicenow_eks_jumphost.instance_profile_name
}

output "ssm_document_names" {
  value = module.servicenow_eks_jumphost.ssm_document_names
}

output "ssm_target_tag_key" {
  value = module.servicenow_eks_jumphost.ssm_target_tag_key
}

output "ssm_target_tag_value" {
  value = module.servicenow_eks_jumphost.ssm_target_tag_value
}