################################################################################
# NETWORK COMPONENTS VARIABLES
################################################################################
variable "component" {
  type        = string
  description = "Name of the project we are working on"
  default     = "3-tier-architecture"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "resource_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
  default = {
    project     = "my-project",
    environment = "Dev"
  }
}

variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_count" {
  description = "Number of public web subnets."
  type        = number
  default     = 2
}

variable "public_subnet_cidr_blocks" {
  description = "Available cidr blocks for public web subnets"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24",
    "10.0.5.0/24",
    "10.0.6.0/24",
    "10.0.7.0/24",
    "10.0.8.0/24",
  ]
}

variable "route_table_cidr" {
  description = "CIDR block for route table"
  type        = string
  default     = "0.0.0.0/0"
}

variable "my_ip_cidr" {
  description = "my ip cidr block"
  type        = string
  default     = "81.100.22.164/32"
  sensitive   = true
}


################################################################################
# SECURTIY GROUP VARIABLES
################################################################################
variable "alb_sg_name" {
  description = "Name of the application load balancer security group"
  type        = string
  default     = "internet_facing_lb_sg"
}

variable "nginx_sg_name" {
  description = "Name of nginx instances security group"
  type        = string
  default     = "nginx_instances_sg"
}


################################################################################
# NGINX INSTANCE VARIABLES
################################################################################
variable "nginx_instance_type" {
  description = "instance type for the front end instances"
  type        = string
  default     = "t2.micro"
}

################################################################################
# APPLICATION LOAD BALANCER VARIABLES
################################################################################
variable "alb_name" {
  description = "Name of the application load balancer"
  type        = string
  default     = "InternetFacingLB"
}

variable "alb_tg_name" {
  description = "Name of our target group for the internet facing load balancer"
  type        = string
  default     = "AlbTargetGroup"
}