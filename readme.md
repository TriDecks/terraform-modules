# PayD Terraform Modules

This repository contains reusable Terraform modules for deploying infrastructure on AWS.

## Modules

### VPC Module

Creates a complete VPC setup with public and private subnets, NAT gateway, internet gateway, route tables, security groups, and an optional bastion host.

#### Usage

```hcl
module "vpc" {
  source = "git::https://github.com/PayD/terraform-modules.git//vpc?ref=v1.0.0"
  
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  environment          = "dev"
  tag_org_short_name   = "PayD"
  bastion_enabled      = true
  bastion_key_name     = "my-key-pair" # Optional
}
```

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_cidr | CIDR block for the VPC | string | - | Yes |
| availability_zones | List of availability zones | list(string) | - | Yes |
| environment | Environment name (e.g., dev, staging, prod) | string | - | Yes |
| tag_org_short_name | Organization short name for resource tagging | string | - | Yes |
| bastion_enabled | Whether to deploy a bastion host | bool | true | No |
| bastion_key_name | SSH key name for bastion host | string | null | No |

#### Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_cidr_block | The CIDR block of the VPC |
| public_subnet_ids | List of IDs of public subnets |
| private_subnet_ids | List of IDs of private subnets |
| nat_gateway_id | ID of the NAT Gateway |
| ecs_security_group_id | ID of the security group for ECS instances |
| db_security_group_id | ID of the security group for RDS instances |
| bastion_security_group_id | ID of the security group for bastion host |
| bastion_public_ip | Public IP address of bastion host |

---

### Database Module

Creates an RDS PostgreSQL database instance in a single availability zone with default encryption.

#### Usage

```hcl
module "database" {
  source = "git::https://github.com/PayD-organization/terraform-modules.git//database?ref=v1.0.0"
  
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_sg_id             = module.vpc.db_security_group_id
  db_subnet_group_name = "payd-dev-db-subnet-group"
  db_instance_class    = "db.t3.medium"
  db_name              = "appdb"
  db_username          = "dbadmin"
  db_password          = "securepassword"
  environment          = "dev"
  tag_org_short_name   = "PayD"
}
```

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_id | ID of the VPC | string | - | Yes |
| private_subnet_ids | List of private subnet IDs | list(string) | - | Yes |
| db_sg_id | ID of the security group for the RDS instance | string | - | Yes |
| db_subnet_group_name | Name of the DB subnet group | string | - | Yes |
| db_instance_class | RDS instance class | string | - | Yes |
| db_name | Database name | string | - | Yes |
| db_username | Database master username | string | - | Yes |
| db_password | Database master password | string | - | Yes |
| environment | Environment name (e.g., dev, staging, prod) | string | - | Yes |
| tag_org_short_name | Organization short name for resource tagging | string | - | Yes |

#### Outputs

| Name | Description |
|------|-------------|
| db_endpoint | Endpoint of the RDS instance |
| db_name | Name of the database |
| db_instance_id | ID of the RDS instance |

---

### ECS Module

Creates an ECS cluster with EC2 instances and auto-scaling capabilities. Deploys Node.js, .NET, and Python services on the same instances.

#### Usage

```hcl
module "ecs" {
  source = "git::https://github.com/PayD-organization/terraform-modules.git//ecs?ref=v1.0.0"
  
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  ecs_sg_id            = module.vpc.ecs_security_group_id
  environment          = "dev"
  tag_org_short_name   = "PayD"
  instance_type        = "t3.medium"
  min_size             = 1
  max_size             = 5
  desired_capacity     = 2
  db_endpoint          = module.database.db_endpoint
  db_name              = "appdb"
  db_username          = "dbadmin" 
  db_password          = "securepassword"
}
```

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_id | ID of the VPC | string | - | Yes |
| private_subnet_ids | List of private subnet IDs | list(string) | - | Yes |
| ecs_sg_id | ID of the security group for ECS instances | string | - | Yes |
| environment | Environment name (e.g., dev, staging, prod) | string | - | Yes |
| tag_org_short_name | Organization short name for resource tagging | string | - | Yes |
| instance_type | EC2 instance type for ECS | string | - | Yes |
| min_size | Minimum size of the auto scaling group | number | - | Yes |
| max_size | Maximum size of the auto scaling group | number | - | Yes |
| desired_capacity | Desired capacity of the auto scaling group | number | - | Yes |
| db_endpoint | Endpoint of the RDS instance | string | - | Yes |
| db_name | Database name | string | - | Yes |
| db_username | Database master username | string | - | Yes |
| db_password | Database master password | string | - | Yes |

#### Outputs

| Name | Description |
|------|-------------|
| ecs_cluster_id | ID of the ECS cluster |
| ecs_cluster_name | Name of the ECS cluster |
| autoscaling_group_name | Name of the auto scaling group |

## Module Versioning

This repository uses Git tags for module versioning. Always use a specific tag version in your module source references:

```hcl
source = "git::https://github.com/PayD-organization/terraform-modules.git//MODULE_NAME?ref=vX.Y.Z"
```

### Version History

#### v1.0.0
- Initial release with vpc, database, and ecs modules

## Development

### Adding a New Module

1. Create a new directory for your module
2. Add the following files:
   - `main.tf` - Main module resources
   - `variables.tf` - Input variables
   - `outputs.tf` - Output variables
   - Any additional required files (e.g., scripts)

### Releasing a New Version

1. Make your changes and ensure they work correctly
2. Update version information in this README
3. Commit your changes
4. Create and push a new tag:

```bash
git tag -a vX.Y.Z -m "Version X.Y.Z description"
git push origin vX.Y.Z
```

## Best Practices

- Use consistent naming conventions across modules
- Add proper descriptions for variables and outputs
- Tag all resources with environment and organization tags
- Use sensitive = true for secret variables like passwords
- Follow semantic versioning (MAJOR.MINOR.PATCH)
  - MAJOR: incompatible API changes
  - MINOR: backwards-compatible functionality
  - PATCH: backwards-compatible bug fixes
