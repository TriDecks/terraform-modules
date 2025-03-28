# Networking outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

# Security outputs
output "ecs_security_group_id" {
  description = "ID of the security group for ECS instances"
  value       = aws_security_group.ecs.id
}

output "db_security_group_id" {
  description = "ID of the security group for RDS instances"
  value       = aws_security_group.db.id
}

output "bastion_security_group_id" {
  description = "ID of the security group for bastion host"
  value       = var.bastion_enabled ? aws_security_group.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Public IP address of bastion host"
  value       = var.bastion_enabled ? aws_instance.bastion[0].public_ip : null
}