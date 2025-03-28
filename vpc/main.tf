# Networking Resources
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-vpc"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

# Create one public and one private subnet in one AZ (minimizing as requested)
resource "aws_subnet" "public" {
  count             = 1
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_subnet" "private" {
  count             = 1
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(aws_subnet.public))
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-igw"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-nat-eip"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-nat-gateway"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-public-route-table"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-private-route-table"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Resources
resource "aws_security_group" "ecs" {
  name        = "${var.tag_org_short_name}-${var.environment}-ecs-sg"
  description = "Security group for ECS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within the security group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-ecs-sg"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_security_group" "db" {
  name        = "${var.tag_org_short_name}-${var.environment}-db-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "Allow PostgreSQL traffic from ECS instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-db-sg"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

resource "aws_security_group" "bastion" {
  count       = var.bastion_enabled ? 1 : 0
  name        = "${var.tag_org_short_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to specific IPs in production
    description = "Allow SSH from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-bastion-sg"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

# Add ingress rule to DB security group for bastion if enabled
resource "aws_security_group_rule" "bastion_to_db" {
  count                    = var.bastion_enabled ? 1 : 0
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.bastion[0].id
  description              = "Allow PostgreSQL traffic from bastion host"
}

# Bastion host (optional)
resource "aws_instance" "bastion" {
  count                       = var.bastion_enabled ? 1 : 0
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  associate_public_ip_address = true
  key_name                    = var.bastion_key_name

  tags = {
    Name        = "${var.tag_org_short_name}-${var.environment}-bastion"
    Environment = var.environment
    Organization = var.tag_org_short_name
  }
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}