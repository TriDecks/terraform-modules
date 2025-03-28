resource "aws_ecs_cluster" "main" {
  name = "${var.tag_org_short_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-cluster"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

# IAM Role for ECS
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.tag_org_short_name}-${var.environment}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-ecs-instance-role"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${var.tag_org_short_name}-${var.environment}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# IAM roles for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.tag_org_short_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-ecs-task-execution-role"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Logs policy for ECS tasks
resource "aws_iam_policy" "ecs_cloudwatch_logs" {
  name        = "${var.tag_org_short_name}-${var.environment}-ecs-cloudwatch-logs"
  description = "Allow ECS tasks to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_logs_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_cloudwatch_logs.arn
}

# EC2 Launch Template
resource "aws_launch_template" "ecs" {
  name                   = "${var.tag_org_short_name}-${var.environment}-ecs-lt"
  image_id               = data.aws_ami.amazon_linux_2_ecs.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.ecs_sg_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = aws_ecs_cluster.main.name
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.tag_org_short_name}-${var.environment}-ecs-instance"
      Environment = var.environment
      Organization = var.tag_org_short_name
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.tag_org_short_name}-${var.environment}-ecs-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.tag_org_short_name}-${var.environment}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Organization"
    value               = var.tag_org_short_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_capacity_provider" "ecs_capacity" {
  name = "${var.tag_org_short_name}-${var.environment}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-capacity-provider"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_ecs_cluster_capacity_providers" "cluster_capacity" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity.name
    weight            = 1
    base              = 1
  }
}

# CloudWatch Log Groups for each service
resource "aws_cloudwatch_log_group" "nodejs" {
  name              = "/ecs/${var.tag_org_short_name}/${var.environment}/nodejs-service"
  retention_in_days = 30

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-nodejs-logs"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_cloudwatch_log_group" "dotnet" {
  name              = "/ecs/${var.tag_org_short_name}/${var.environment}/dotnet-service"
  retention_in_days = 30

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-dotnet-logs"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_cloudwatch_log_group" "python" {
  name              = "/ecs/${var.tag_org_short_name}/${var.environment}/python-service"
  retention_in_days = 30

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-python-logs"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

# Task Definitions for each service
resource "aws_ecs_task_definition" "nodejs" {
  family                   = "${var.tag_org_short_name}-${var.environment}-nodejs"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "nodejs-app"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/nodejs-app:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = split(":", var.db_endpoint)[0]
        },
        {
          name  = "DB_PORT"
          value = split(":", var.db_endpoint)[1]
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "DB_PASSWORD"
          value = var.db_password
        },
        {
          name  = "NODE_ENV"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.nodejs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      memory = 512
      cpu    = 256
    }
  ])

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-nodejs-task"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_ecs_task_definition" "dotnet" {
  family                   = "${var.tag_org_short_name}-${var.environment}-dotnet"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "dotnet-app"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/dotnet-app:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ConnectionStrings__DefaultConnection"
          value = "Host=${split(":", var.db_endpoint)[0]};Port=${split(":", var.db_endpoint)[1]};Database=${var.db_name};Username=${var.db_username};Password=${var.db_password}"
        },
        {
          name  = "ASPNETCORE_ENVIRONMENT"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dotnet.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      memory = 512
      cpu    = 256
    }
  ])

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-dotnet-task"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_ecs_task_definition" "python" {
  family                   = "${var.tag_org_short_name}-${var.environment}-python"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "python-app"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/python-app:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = split(":", var.db_endpoint)[0]
        },
        {
          name  = "DB_PORT"
          value = split(":", var.db_endpoint)[1]
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "DB_PASSWORD"
          value = var.db_password
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.python.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      memory = 512
      cpu    = 256
    }
  ])

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-python-task"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

# ECS Services
resource "aws_ecs_service" "nodejs" {
  name            = "nodejs-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nodejs.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity.name
    weight            = 1
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-nodejs-service"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_ecs_service" "dotnet" {
  name            = "dotnet-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.dotnet.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity.name
    weight            = 1
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-dotnet-service"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_ecs_service" "python" {
  name            = "python-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.python.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity.name
    weight            = 1
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-python-service"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

# Get AWS account ID and region for ECR repository reference
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get the latest ECS-optimized Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2_ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}