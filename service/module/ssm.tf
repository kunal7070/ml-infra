resource "aws_ssm_document" "eks_names" {
  count           = var.create_ssm_documents ? 1 : 0
  name            = "SG-AWS-RunKubeCtlEKSNamesShellScript"
  document_type   = "Command"
  document_format = "JSON"
  target_type     = "/AWS::EC2::Instance"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Service Graph AWS - kubectl script to get EKS Cluster Names"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "runShellScript"
        inputs = {
          timeoutSeconds = "3600"
          runCommand     = split("\n", trimspace(templatefile("${path.module}/templates/ssm-doc.sh.tpl", {})))
        }
      }
    ]
  })
}

resource "aws_ssm_document" "eks_kubectl" {
  count           = var.create_ssm_documents ? 1 : 0
  name            = "SG-AWS-RunKubeCtlShellScript"
  document_type   = "Command"
  document_format = "JSON"
  target_type     = "/AWS::EC2::Instance"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Service Graph AWS - kubectl script to get EKS data into CMDB"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "runShellScript"
        inputs = {
          timeoutSeconds = "3600"
          runCommand     = split("\n", trimspace(templatefile("${path.module}/templates/ssm-doc-kubectl.sh.tpl", {})))
        }
      }
    ]
  })
}

resource "aws_ssm_association" "eks_names" {
  count = var.create_ssm_documents && var.create_ssm_associations ? 1 : 0
  name  = aws_ssm_document.eks_names[0].name

  targets {
    key    = "tag:${var.ssm_target_tag_key}"
    values = [var.ssm_target_tag_value]
  }

  schedule_expression = var.association_schedule_expression
}

resource "aws_ssm_association" "eks_kubectl" {
  count = var.create_ssm_documents && var.create_ssm_associations ? 1 : 0
  name  = aws_ssm_document.eks_kubectl[0].name

  targets {
    key    = "tag:${var.ssm_target_tag_key}"
    values = [var.ssm_target_tag_value]
  }

  schedule_expression = var.association_schedule_expression
}