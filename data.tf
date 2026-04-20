data "aws_ami" "roboshop_ami" {
  most_recent      = true
  owners           = ["973714476881"]

  filter {
    name   = "name"
    values = ["Redhat-9-DevOps-Practice"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project_name}/${var.env}/vpc_id"
}
data "aws_ssm_parameter" "catalogue_sg_id" {
  name = "/${var.project_name}/${var.env}/catalogue_sg_id"
}
data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.project_name}/${var.env}/private_subnet_ids"
}
data "aws_ssm_parameter" "shh_loginpass" {
  name = "/roboshop/${var.env}/ssh/loginpass"
}
data "aws_ssm_parameter" "backend_alb_listener_arn" {
  name = "/${var.project_name}/${var.env}/backend_alb_listener_arn"
}