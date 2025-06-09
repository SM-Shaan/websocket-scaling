output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.websocket.dns_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.websocket_tg.arn
} 