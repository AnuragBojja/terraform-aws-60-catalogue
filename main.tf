resource "aws_instance" "catalogue" {
  ami           = local.ami_id
  instance_type = var.instance_type
  vpc_security_group_ids = [local.catalogue_sg_id]
  subnet_id = local.private_subnet_id
  iam_instance_profile = aws_iam_instance_profile.catalogue-SSM-Role.name

  tags = merge(
    local.common_tags,
    {
        Name = "${local.common_name}-catalogue"
    }
  )
}

resource "aws_iam_instance_profile" "catalogue-SSM-Role" {
  name = "catalogue-SSM-Role"
  role = "EC2SSMParameterStore"
  }

resource "terraform_data" "catalogue" {
  triggers_replace = [
    aws_instance.catalogue.id
  ]

  connection {
    type = "ssh"
    user = "ec2-user"
    password = local.shh_loginpass
    host = aws_instance.catalogue.private_ip
  }

  provisioner "file" {
    source = "catalogue.sh"
    destination = "/tmp/catalogue.sh"
  }

  provisioner "remote-exec" {
    inline = [ 
        "chmod +x /tmp/catalogue.sh",
        "sudo /tmp/catalogue.sh catalogue ${var.env}"
     ]
  }
}

resource "aws_ec2_instance_state" "catalogue" {
  instance_id = aws_instance.catalogue.id
  state       = "stopped"
  depends_on = [ terraform_data.catalogue ]
}
resource "aws_ami_from_instance" "catalogue" {
  name               = "${local.common_name}-catalogue-ami"
  source_instance_id = aws_instance.catalogue.id
  depends_on = [ aws_ec2_instance_state.catalogue ]
}