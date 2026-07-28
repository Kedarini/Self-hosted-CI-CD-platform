output "ec2_public_ip" {
  description = "Public (Elastic) IP of the app EC2 instance"
  value       = aws_eip.app.public_ip
}

output "rds_endpoint" {
  description = "RDS connection address"
  value       = aws_db_instance.main.address
}

output "ec2_ssh_command" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${aws_eip.app.public_ip}"
}
