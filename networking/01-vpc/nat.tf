resource "aws_eip" "lab" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-eip"
  }
}

resource "aws_nat_gateway" "lab" {
  allocation_id = aws_eip.lab.id
  subnet_id     = aws_subnet.subnets["public-a"].id

  depends_on = [aws_internet_gateway.lab]

  tags = {
    Name = "${local.name_prefix}-nat-gw"
  }
}