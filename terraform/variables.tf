locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
}

variable "aws_region" {
  description = "AWS region used by Floci (local emulator)"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
  default     = "localdbpassword"
}

variable "grafana_password" {
  description = "Password for the Grafana dashboard"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the app instance (kept for compatibility)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ec2_ami_id" {
  description = "AMI/container image identifier used for the emulated EC2 instance in Floci"
  type        = string
  default     = "ami-local-floci"
}

variable "ec2_public_key" {
  description = "Public key material for the EC2 key pair (Floci local mode)"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQayGmRVl5v8gBDd96OP99kt0jJnDvOAdF3raB8PsVE floci@local"
}
