resource "aws_ssm_parameter" "catalogue_ami_id" {
  name  = "/${var.project_name}/${var.env}/catalogue_ami_id"
  type  = "String"
  value = aws_ami_from_instance.catalogue.id
}