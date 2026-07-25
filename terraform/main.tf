terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = "eu-central-1"
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "url-shortener-vpc"
    }
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-central-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "url-shortener-public-subnet"
    }
}

resource "aws_subnet" "public_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-central-1b"
    map_public_ip_on_launch = true

    tags = {
        Name = "url-shortener-public-subnet"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    
    tags = {
        Name = "url-shortener-igw"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }

    tags = {
        Name = "url-shortener-public-rt"
    }
}

resource "aws_route_table_association" "public" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
    subnet_id = aws_subnet.public_2.id
    route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
    name = "url-shortener-app-sg"
    description = "Security group for the app EC2 instance"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "App port"
        from_port = 8000
        to_port = 8000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "url-shortener-app-sg"
    }
}

resource "aws_security_group" "db" {
    name = "url-shortener-db-sg"
    description = "Security group for the RDS instance"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "Postgres from app"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        security_groups = [aws_security_group.app.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "url-shortener-db-sg"
    }
}

resource "aws_key_pair" "deployer" {
    key_name = "url-shortener-key"
    public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "url-shortener-app"
  }
}

data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["099720109477"]

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }
}

resource "aws_db_subnet_group" "main" {
    name = "url-shortener-db-subnet-group"
    subnet_ids = [aws_subnet.public.id, aws_subnet.public_2.id]

    tags = {
        Name = "url-shortener-db-subnet-group"
    }
}

resource "aws_db_instance" "main" {
    identifier = "url-shortener-db"
    engine = "postgres"
    engine_version = "16"
    instance_class = "db.t3.micro"
    allocated_storage = 20
    db_name = "urlshortener"
    username = "postgres"
    password = var.db_password
    db_subnet_group_name = aws_db_subnet_group.main.name
    vpc_security_group_ids = [aws_security_group.db.id]
    skip_final_snapshot = true
    publicly_accessible = false

    tags = {
        Name = "url-shortener-db"
    }
}
