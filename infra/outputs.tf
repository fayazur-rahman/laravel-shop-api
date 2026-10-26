output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}


output "web_log_group" {
  value = aws_cloudwatch_log_group.web.name
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