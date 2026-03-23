output "load_balancer_dns" {
  description = "Public DNS of the Application Load Balancer"
  value       = aws_alb.web_alb.dns_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.Chisom.id
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.web_asg.name
}