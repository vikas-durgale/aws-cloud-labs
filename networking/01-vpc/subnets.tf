resource "aws_subnet" "subnets" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.lab.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.tier == "public"

  tags = {
    Name = "${local.name_prefix}-${each.key}"
    Tier = each.value.tier
  }
}