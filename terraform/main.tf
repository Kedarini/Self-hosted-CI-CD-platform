terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# ------------------------------------------------------------------------------
# VPC & NETWORK
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "url-shortener-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = { Name = "url-shortener-public-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = { Name = "url-shortener-public-subnet-2" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "url-shortener-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "url-shortener-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "url-shortener-app-sg"
  description = "Security group for the app EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # if variable is set to some ip's it will not work with github actions
  }

  ingress {
    description = "App port"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "url-shortener-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "url-shortener-db-sg"
  description = "Security group for the RDS instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "url-shortener-db-sg" }
}

# ------------------------------------------------------------------------------
# EC2 INSTANCE & EIP (USING PACKER AMI)
# ------------------------------------------------------------------------------
resource "aws_key_pair" "deployer" {
  key_name   = "url-shortener-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

data "aws_ami" "custom_ubuntu" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["custom-ubuntu-docker-*"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.custom_ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ecr_profile.name

  user_data = <<-EOF
    #!/bin/bash
    REPO_DIR="/home/ubuntu/Self-hosted-CI-CD-platform"
    su - ubuntu -c "git clone https://github.com/Kedarini/Self-hosted-CI-CD-platform.git $REPO_DIR"
    chown -R ubuntu:ubuntu $REPO_DIR
  EOF

  tags = { Name = "url-shortener-app" }
}

resource "aws_eip" "app" {
  domain = "vpc"

  tags = { Name = "url-shortener-eip" }
}

resource "aws_eip_association" "app_eip_assoc" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}

# ------------------------------------------------------------------------------
# RDS POSTGRES
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "url-shortener-db-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.public_2.id]

  tags = {
    Name = "url-shortener-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier             = "url-shortener-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "urlshortener"
  username               = "postgres"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = { Name = "url-shortener-db" }
}

# ------------------------------------------------------------------------------
# ECR REPOSITORY
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "url-shortener"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = { Name = "url-shortener-ecr" }
}

resource "aws_ecr_lifecycle_policy" "app_policy" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Store only 3 latest images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# IAM ROLE
# ------------------------------------------------------------------------------
resource "aws_iam_role" "ec2_ecr_role" {
  name = "ec2_ecr_read_role"

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
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_policy" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "ec2_secrets_policy" {
  name = "ec2_secrets_read_policy"
  role = aws_iam_role.ec2_ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.grafana_password.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_rds_describe_policy" {
  name = "ec2_rds_describe_policy"
  role = aws_iam_role.ec2_ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances"]
        Resource = [aws_db_instance.main.arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_ecr_profile" {
  name = "ec2_ecr_profile"
  role = aws_iam_role.ec2_ecr_role.name
}

# ------------------------------------------------------------------------------
# Secrets Manager
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "db_password" {
  name = "url-shortener/db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

resource "aws_secretsmanager_secret" "grafana_password" {
  name = "url-shortener/grafana-password"
}


resource "aws_secretsmanager_secret_version" "grafana_password" {
  secret_id     = aws_secretsmanager_secret.grafana_password.id
  secret_string = var.grafana_password
}
