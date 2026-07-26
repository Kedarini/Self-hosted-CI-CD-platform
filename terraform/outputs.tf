output "ec2_public_ip" {
    description = "Public IP of the app EC2 instance"
    value = aws_instance.app.public_ip
}

output "rds_endpoint" {
    description = "RDS connection endpoint"
    value = aws_db_instance.main.endpoint
}