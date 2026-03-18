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
  type    = bool
  default = false
}

variable "cluster_names" {
  type        = list(string)
  description = "List of EKS clusters this jump host should process."
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

variable "create_security_group" {
  type        = bool
  description = "Whether to create SG in this stack/module."
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