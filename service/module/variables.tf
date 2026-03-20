variable "region" {
  description = "AWS region."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the jump host will be deployed."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the jump host will be deployed."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the Linux jump host."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP."
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root volume type."
  type        = string
  default     = "gp3"
}

variable "kms_key_id" {
  description = "Optional KMS key ID for EBS encryption."
  type        = string
  default     = null
}

variable "create_security_group" {
  description = "Whether to create a dedicated SG in this stack."
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "Existing approved security groups to attach."
  type        = list(string)
  default     = []
}

variable "egress_cidrs" {
  description = "Controlled egress CIDRs used only if create_security_group = true."
  type        = list(string)
  default     = []
}

variable "cluster_names" {
  description = "List of EKS clusters this jump host should process."
  type        = list(string)
  default     = []
}

variable "create_instance_role" {
  description = "Whether to create the EC2 IAM role/profile for the jump host."
  type        = bool
  default     = true
}

variable "existing_instance_profile_name" {
  description = "Existing instance profile name when create_instance_role is false."
  type        = string
  default     = null
}

variable "additional_instance_policy_json" {
  description = "Optional additional inline policy JSON for the jump host role."
  type        = string
  default     = null
}

variable "create_ssm_documents" {
  description = "Whether to create the EKS SSM documents."
  type        = bool
  default     = true
}

variable "create_ssm_associations" {
  description = "Whether to create SSM associations."
  type        = bool
  default     = false
}

variable "association_schedule_expression" {
  description = "Optional schedule expression for SSM associations."
  type        = string
  default     = null
}

variable "ssm_target_tag_key" {
  description = "Target tag key used by ServiceNow/SSM."
  type        = string
  default     = "ServiceNowTarget"
}

variable "ssm_target_tag_value" {
  description = "Target tag value used by ServiceNow/SSM."
  type        = string
}

variable "extra_linux_users" {
  description = "Additional local Linux users to create."
  type        = list(string)
  default     = []
}

variable "extra_linux_users_passwordless_sudo" {
  description = "Whether extra Linux users should get passwordless sudo."
  type        = bool
  default     = false
}