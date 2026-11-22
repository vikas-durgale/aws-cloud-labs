resource "aws_route_table" "lab" {
  for_each = local.route_tables
  vpc_id   = aws_vpc.lab.id

  tags = {
    Name = "${local.name_prefix}-${each.value.name}"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.lab["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab.id
}

resource "aws_route" "private_app" {
  route_table_id         = aws_route_table.lab["app"].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.lab.id
}

resource "aws_route_table_association" "lab" {
  for_each = local.subnets

  subnet_id = aws_subnet.subnets[each.key].id

  route_table_id = aws_route_table.lab[each.value.tier].id
}