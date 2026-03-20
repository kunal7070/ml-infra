locals {
  base_name         = "${var.name_prefix}-${var.environment}-servicenow-eks-discovery-host"
  instance_name     = "${var.environment}-eks-jumphost"
  cluster_names_csv = join(",", var.cluster_names)
  extra_users_csv   = join(",", var.extra_linux_users)
}