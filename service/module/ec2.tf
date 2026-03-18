resource "aws_instance" "jump_host" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address

  vpc_security_group_ids = var.create_security_group ? [
    aws_security_group.jump_host[0].id
  ] : var.security_group_ids

  iam_instance_profile = var.create_instance_role ? aws_iam_instance_profile.jump_host[0].name : var.existing_instance_profile_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    install_kubectl_version            = "v1.30.0"
    cluster_names_csv                  = local.cluster_names_csv
    extra_linux_users_csv              = local.extra_users_csv
    extra_users_passwordless_sudo_flag = var.extra_linux_users_passwordless_sudo
  })

  tags = {
    Name                      = local.instance_name
    environment               = var.environment
    service                   = "servicenow"
    component                 = "eks-jumphost"
    servicenow_discovery      = "true"
    "${var.ssm_target_tag_key}" = var.ssm_target_tag_value
  }
}