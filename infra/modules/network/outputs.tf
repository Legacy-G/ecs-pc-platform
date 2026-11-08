output "vpc_id" {
  description = "ID of the provisioned VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs across two Availability Zones."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs across two Availability Zones."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Two Availability Zones selected for the VPC subnets."
  value       = local.azs
}
