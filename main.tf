# Provider Block
provider "aws" {
  region = var.aws_region
}

# Locals block
locals {
  vpc_id = aws_vpc.main.id
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Data source block
data "aws_availability_zones" "available" {
  state = "available"
}

# Create the vpc
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = var.resource_tags
}

# Create the public subnets
resource "aws_subnet" "public_subnets" {
  vpc_id = local.vpc_id
  count  = var.public_subnet_count

  availability_zone = local.azs[count.index]
  cidr_block        = var.public_subnet_cidr_blocks[count.index]

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }

  map_public_ip_on_launch = true
}

# Create the internet gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = local.vpc_id

  tags = var.resource_tags
}

# Create route table for the public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = local.vpc_id

  route {
    cidr_block = var.route_table_cidr
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Associates public subnets with route table
resource "aws_route_table_association" "public_rta" {
  count = length(aws_subnet.public_subnets)

  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Create the security group for the internet facing load balancer
resource "aws_security_group" "alb_sg" {
  name        = var.alb_sg_name
  description = "application load balancer security group"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allows http traffic from my ip"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.resource_tags
}

# Create the security group for the nginx instances
resource "aws_security_group" "nginx_sg" {
  name        = var.nginx_sg_name
  description = "SG for the nginx instances"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Allows http traffic from the application load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "Allows http traffic from my ip"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.resource_tags

  depends_on = [aws_security_group.alb_sg]
}


# Data block
data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Create the nginx instances
resource "aws_instance" "nginx_instances" {
  count = length(aws_subnet.public_subnets)

  ami                    = data.aws_ami.ami.id
  instance_type          = var.nginx_instance_type
  subnet_id              = aws_subnet.public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  user_data              = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo amazon-linux-extras install nginx1 -y
                sudo systemctl enable nginx
                sudo systemctl start nginx
                EOF

  tags = {
    name = "nginx_instance-${count.index + 1}"
  }
}

# Create the target group for the internet facing load balancer listener
resource "aws_lb_target_group" "alb_tg" {
  name        = var.alb_tg_name
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3

  }
}

# Create the alb target group attachment
resource "aws_lb_target_group_attachment" "alb_attachment" {
  count = length(aws_instance.nginx_instances)

  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.nginx_instances[count.index].id
  port             = 80
}


# Create the internet facing load balancer for the nginx instances
resource "aws_lb" "alb" {
  name               = var.alb_name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  tags = var.resource_tags
}

# Create the internet facing load balancer listener for routing 
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }

  depends_on = [aws_lb_target_group.alb_tg]
}

# Output the url of the application load balancer
output "public_web_lb_url" {
  description = "URL of public web tier load balancer"
  value       = "http://${aws_lb.alb.dns_name}/"
}

# Output the instance id of the nginx instances
output "nginx_instance_id_1" {
  description = "ID of the EC2 instance"
  value       = aws_instance.nginx_instances[0].id
}

output "nginx_instance_id_2" {
  description = "ID of the EC2 instance"
  value       = aws_instance.nginx_instances[1].id
}

