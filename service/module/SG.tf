resource "aws_security_group" "jump_host" {
  count       = var.create_security_group ? 1 : 0
  name        = "${local.base_name}-sg"
  description = "Security group for ServiceNow EKS discovery host"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "jump_host" {
  for_each = var.create_security_group ? {
    for idx, cidr in var.egress_cidrs : idx => cidr
  } : {}

  security_group_id = aws_security_group.jump_host[0].id
  cidr_ipv4         = each.value
  ip_protocol       = "-1"
  description       = "Controlled outbound access for SSM and EKS"
}