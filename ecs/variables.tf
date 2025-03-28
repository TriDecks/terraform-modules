variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "ID of the security group for ECS instances"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tag_org_short_name" {
  description = "Organization short name for resource tagging"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for ECS"
  type        = string
}

variable "min_size" {
  description = "Minimum size of the auto scaling group"
  type        = number
}

variable "max_size" {
  description = "Maximum size of the auto scaling group"
  type        = number
}

variable "desired_capacity" {
  description = "Desired capacity of the auto scaling group"
  type        = number
}

variable "db_endpoint" {
  description = "Endpoint of the RDS instance"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}