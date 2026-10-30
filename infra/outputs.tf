output "db_address" {
  description = "RDS endpoint (DNS name) - the app's DB_HOST"
  value       = aws_db_instance.mysql.address
}

output "db_instance_identifier" {
  value = aws_db_instance.mysql.identifier
}

output "db_engine_version" {
  value = aws_db_instance.mysql.engine_version_actual
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}


output "web_log_group" {
  value = aws_cloudwatch_log_group.web.name
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB: the app's address"
  value       = aws_lb.web.dns_name
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "web_target_group_arn" {
  value = aws_lb_target_group.web.arn
}

output "web_security_group_id" {
  value = aws_security_group.web.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs, keyed by AZ."
  value       = { for az, s in aws_subnet.public : az => s.id }
}


output "private_subnet_ids" {
  description = "Private subnet IDs, keyed by AZ."
  value       = { for az, s in aws_subnet.private : az => s.id }
}

output "public_subnets" {
  description = "List of public subnets"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnets" {
  description = "List of private subnets"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "nat_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}