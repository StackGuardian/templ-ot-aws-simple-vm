output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP of the instance"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Elastic IP of the instance, null if disabled"
  value       = one(aws_eip.this[*].public_ip)
}

output "ssm_command" {
  description = "Command to open a shell through SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.this.id} --region ${var.region}"
}

output "ssh_command" {
  description = "SSH command, null unless the public IP and an SSH key are set"
  value       = var.enable_public_ip && var.ssh_public_key != null ? "ssh ec2-user@${one(aws_eip.this[*].public_ip)}" : null
}
