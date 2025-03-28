resource "aws_db_subnet_group" "main" {
  name       = var.db_subnet_group_name
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_db_instance" "main" {
  identifier              = "${lower(var.tag_org_short_name)}-${var.environment}-postgres"
  engine                  = "postgres"
  engine_version          = "14.7"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  max_allocated_storage   = 100
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [var.db_sg_id]
  skip_final_snapshot     = true
  backup_retention_period = 7
  multi_az                = false  # Single AZ as requested

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-postgres"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }

  lifecycle {
    prevent_destroy = false
  }
}