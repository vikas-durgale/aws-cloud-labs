output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.lab.id
}

output "subnet_ids" {
  description = "Map of subnet key to subnet ID"
  value = {
    for key, subnet in aws_subnet.subnets : key => subnet.id
  }
}