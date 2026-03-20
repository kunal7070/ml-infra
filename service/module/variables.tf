variable "region" {
  type        = string
  description = "AWS region."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the jump host will be deployed."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the jump host will be deployed."
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the Linux jump host."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.small"
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IP."
  default     = false
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GiB."
  default     = 30
}

variable "root_volume_type" {
  type        = string
  description = "Root volume type."
  default     = "gp3"
}

variable "kms_key_id" {
  type        = string
  description = "Optional KMS key ID for EBS encryption."
  default     = null
}

variable "create_security_group" {
  type        = bool
  description = "Whether to create a dedicated SG in this stack."
  default     = false
}

variable "security_group_ids" {
  type        = list(string)
  description = "Existing approved security groups to attach."
  default     = []
}

variable "egress_cidrs" {
  type        = list(string)
  description = "Controlled egress CIDRs used only if create_security_group = true."
  default     = []
}

variable "cluster_names" {
  type        = list(string)
  description = "List of EKS clusters this jump host should process."
  default     = []
}

variable "create_instance_role" {
  type        = bool
  description = "Whether to create the EC2 IAM role/profile for the jump host."
  default     = true
}

variable "existing_instance_profile_name" {
  type        = string
  description = "Existing instance profile name when create_instance_role is false."
  default     = null
}

variable "additional_instance_policy_json" {
  type        = string
  description = "Optional additional inline policy JSON for the jump host role."
  default     = null
}

variable "create_ssm_documents" {
  type        = bool
  description = "Whether to create the EKS SSM documents."
  default     = true
}

variable "create_ssm_associations" {
  type        = bool
  description = "Whether to create SSM associations."
  default     = false
}

variable "association_schedule_expression" {
  type        = string
  description = "Optional schedule expression for SSM associations."
  default     = null
}

variable "ssm_target_tag_key" {
  type        = string
  description = "Target tag key used by ServiceNow/SSM."
  default     = "ServiceNowTarget"
}

variable "ssm_target_tag_value" {
  type        = string
  description = "Target tag value used by ServiceNow/SSM."
}

variable "extra_linux_users" {
  type        = list(string)
  description = "Additional local Linux users to create."
  default     = []
}

variable "extra_linux_users_passwordless_sudo" {
  type        = bool
  description = "Whether extra Linux users should get passwordless sudo."
  default     = false
}