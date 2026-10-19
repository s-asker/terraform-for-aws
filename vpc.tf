resource "aws_vpc" "vpc_main" {

  cidr_block       = var.cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  for_each = var.public_subnets
  vpc_id     = aws_vpc.vpc_main.id
  cidr_block = each.value.cidr_block
  map_public_ip_on_launch = each.value.public_ip

  tags = each.value.tags
}

resource "aws_subnet" "private_subnet" {
  for_each = var.private_subnets
  vpc_id     = aws_vpc.vpc_main.id
  cidr_block = each.value.cidr_block
  map_public_ip_on_launch = each.value.public_ip

  tags = each.value.tags
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_main.id

  tags = {
    Name = "main-igw"
  }
}


resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc_main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "main-public-rt"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc_main.id

  tags = {
    Name = "main-private-rt"
  }
}

resource "aws_route_table_association" "public_subnet_route_table_association" {
  for_each = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_route_table_association" {
  for_each = aws_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}
