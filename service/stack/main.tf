provider "aws" {
  region = var.region
}

module "servicenow_eks_jumphost" {
  source = "../../modules/servicenow_eks_jumphost"

  name_prefix                 = var.name_prefix
  environment                 = var.environment
  region                      = var.region
  vpc_id                      = var.vpc_id
  subnet_id                   = var.subnet_id
  ami_id                      = var.ami_id
  instance_type               = var.instance_type
  associate_public_ip_address = var.associate_public_ip_address

  cluster_names        = var.cluster_names
  create_ssm_documents = true
  ssm_target_tag_key   = var.ssm_target_tag_key
  ssm_target_tag_value = var.ssm_target_tag_value

  create_security_group = var.create_security_group
  security_group_ids    = var.security_group_ids
  egress_cidrs          = var.egress_cidrs

  extra_linux_users                  = var.extra_linux_users
  extra_linux_users_passwordless_sudo = var.extra_linux_users_passwordless_sudo
}