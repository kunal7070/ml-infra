region      = "us-east-1"
name_prefix = "cloudinfra"
environment = "dev"

vpc_id    = "vpc-xxxxxxxx"
subnet_id = "subnet-xxxxxxxx"
ami_id    = "ami-xxxxxxxx"

instance_type               = "t3.small"
associate_public_ip_address = false

cluster_names = [
  "dev-eks-cluster-01"
]

ssm_target_tag_key   = "ServiceNowTarget"
ssm_target_tag_value = "dev-eks-jumphost"

create_security_group = false
security_group_ids    = ["sg-xxxxxxxx"]

extra_linux_users = [
  "yourusername"
]

extra_linux_users_passwordless_sudo = true