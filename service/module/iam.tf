data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "jump_host" {
  count              = var.create_instance_role ? 1 : 0
  name               = "${local.base_name}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = var.create_instance_role ? 1 : 0
  role       = aws_iam_role.jump_host[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "jump_host_eks" {
  statement {
    sid    = "EKSReadDiscovery"
    effect = "Allow"

    actions = [
      "eks:ListClusters",
      "eks:DescribeCluster",
      "sts:GetCallerIdentity"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "jump_host_eks" {
  count  = var.create_instance_role ? 1 : 0
  name   = "${local.base_name}-eks-read"
  role   = aws_iam_role.jump_host[0].id
  policy = data.aws_iam_policy_document.jump_host_eks.json
}

resource "aws_iam_role_policy" "jump_host_additional" {
  count  = var.create_instance_role && var.additional_instance_policy_json != null ? 1 : 0
  name   = "${local.base_name}-additional"
  role   = aws_iam_role.jump_host[0].id
  policy = var.additional_instance_policy_json
}

resource "aws_iam_instance_profile" "jump_host" {
  count = var.create_instance_role ? 1 : 0
  name  = "${local.base_name}-profile"
  role  = aws_iam_role.jump_host[0].name
}