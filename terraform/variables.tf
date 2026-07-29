variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "grafana_password" {
  description = "Password for the Grafana dashboard"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the app instance"
  type        = string
}
