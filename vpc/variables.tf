variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tag_org_short_name" {
  description = "Organization short name for resource tagging"
  type        = string
}

variable "bastion_enabled" {
  description = "Whether to deploy a bastion host"
  type        = bool
  default     = true
}

variable "bastion_key_name" {
  description = "SSH key name for bastion host"
  type        = string
  default     = null
}