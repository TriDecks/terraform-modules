output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "autoscaling_group_name" {
  description = "Name of the auto scaling group"
  value       = aws_autoscaling_group.ecs.name
}