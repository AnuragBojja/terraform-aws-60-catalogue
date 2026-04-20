#creating ec2 instance for catalogue
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

#attaching iam role to catalogue instance
resource "aws_iam_instance_profile" "catalogue-SSM-Role" {
  name = "catalogue-SSM-Role"
  role = "EC2SSMParameterStore"
  }

#this will run every time the instance created or changed 
resource "terraform_data" "catalogue" {
  triggers_replace = [
    aws_instance.catalogue.id
  ]
#connection block to connect catalogue from bastein 
  connection {
    type = "ssh"
    user = "ec2-user"
    password = local.shh_loginpass
    host = aws_instance.catalogue.private_ip
  }
# running catalogue.sh scripts
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
#Stoping configured instance
resource "aws_ec2_instance_state" "catalogue" {
  instance_id = aws_instance.catalogue.id
  state       = "stopped"
  depends_on = [ terraform_data.catalogue ]
}

# creating ami using instance 
resource "aws_ami_from_instance" "catalogue" {
  name               = "${local.common_name}-catalogue-ami"
  source_instance_id = aws_instance.catalogue.id
  depends_on = [ aws_ec2_instance_state.catalogue ]
  tags = merge(
    local.common_tags,
    {
        Name = "${local.common_name}-catalogue-ami"
    }
  )
}
#source:: https://registry.terraform.io/providers/-/aws/6.3.0/docs/resources/launch_template
resource "aws_launch_template" "catalogue" {
  name = "${local.common_name}-catalogue"

  image_id = aws_ami_from_instance.catalogue.id

  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.catalogue_sg_id]
  #when ever we do terraform init new version of ami will be created with new ami id
  update_default_version = true
  
  #tags attached to instance 
  tag_specifications {
    resource_type = "instance"

    tags = merge(
    local.common_tags,
    {
        Name = "${local.common_name}-catalogue"
    }
  )
  }

#tags attached to volume 
  tag_specifications {
    resource_type = "volume"

    tags = merge(
    local.common_tags,
    {
        Name = "${local.common_name}-catalogue"
    }
  )
  }
#tags attached to lanch template 
  tags = merge(
    local.common_tags,
    {
        Name = "${local.common_name}-catalogue"
    }
  )

}

#source:: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
resource "aws_lb_target_group" "catalogue" {
  name     = "${local.common_name}-catalogue"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  deregistration_delay = 60
  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = 8080
    matcher             = "200-299"
    interval            = 100
    timeout             = 2
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#source :: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
resource "aws_autoscaling_group" "catalogue" {
  name                      = "${local.common_name}-catalogue"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  vpc_zone_identifier       = local.private_subnet_ids
  launch_template {
    id = aws_launch_template.catalogue.id
    version = aws_launch_template.catalogue.latest_version
    name = aws_launch_template.catalogue.name
  }
  target_group_arns = [ aws_lb_target_group.catalogue.arn ]
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  
  timeouts {
    delete = "15m"
  }

  dynamic "tag" {
    for_each = merge(
                        local.common_tags,
                        {
                            Name = "${local.common_name}-catalogue"
                        }
                    )
    content {
        key                 = tag.key
        value               = tag.value
        propagate_at_launch = false
        }
  }
}


#source :: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy
resource "aws_autoscaling_policy" "catalogue" {
  name = "${local.common_name}-catalogue"
  autoscaling_group_name = aws_autoscaling_group.catalogue.name
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}

#source :: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule
resource "aws_lb_listener_rule" "catalogue" {
  listener_arn = local.backend_alb_listener_arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalogue.arn
  }
  condition {
    host_header {
      values = ["catalogue.backend-alb-${var.env}.${var.domain_name}"]
    }
  }
}



resource "terraform_data" "catalogue_local" {
  triggers_replace = [
    aws_instance.catalogue.id
  ]
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.catalogue.id}"
  }
  depends_on = [ aws_autoscaling_policy.catalogue ]
}