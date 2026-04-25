terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "shashi-terraform-state-2026"
    key            = "07-alb-asg/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-south-1"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "shashi-terraform-state-2026"
    key    = "04-vpc/terraform.tfstate"
    region = "ap-south-1"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "flask_app" {
  name_prefix   = "flask-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

iam_instance_profile {
  name = aws_iam_instance_profile.ssm_profile.name
}
  vpc_security_group_ids = [
    data.terraform_remote_state.vpc.outputs.web_security_group_id
  ]

user_data = base64encode(<<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y docker.io

systemctl start docker
systemctl enable docker

sudo docker pull shashikarandev/flask-webapp:v1
sudo docker run -d -p 5000:5000 shashikarandev/flask-webapp:v1

# Install SSM agent
snap install amazon-ssm-agent --classic
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service

# Install CloudWatch agent
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb || apt-get install -f -y
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

cat <<CONFIG > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/*/*.log",
            "log_group_name": "docker-logs",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CONFIG
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
EOF
)
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "flask-app"
    }
  }
}

resource "aws_lb_target_group" "flask_tg" {
  name     = "flask-target-group"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.vpc.outputs.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "flask_alb" {
  name               = "flask-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    data.terraform_remote_state.vpc.outputs.web_security_group_id
  ]

  subnets = [
    data.terraform_remote_state.vpc.outputs.public_subnet_id,
    data.terraform_remote_state.vpc.outputs.public_subnet_2_id
  ]
}

resource "aws_lb_listener" "flask_listener" {
  load_balancer_arn = aws_lb.flask_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_tg.arn
  }
}

resource "aws_autoscaling_group" "flask_asg" {
  desired_capacity = 2
  min_size         = 1
  max_size         = 3

  depends_on = [aws_lb_listener.flask_listener]

  vpc_zone_identifier = [
    data.terraform_remote_state.vpc.outputs.public_subnet_id,
    data.terraform_remote_state.vpc.outputs.public_subnet_2_id
  ]

  target_group_arns = [
    aws_lb_target_group.flask_tg.arn
  ]

  launch_template {
    id      = aws_launch_template.flask_app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "flask-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm-profile"
  role = aws_iam_role.ssm_role.name
}