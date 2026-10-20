resource "aws_vpc" "vpc_main" {

  cidr_block           = var.cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc_main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.public_ip

  tags = each.value.tags
}

resource "aws_subnet" "private_subnet" {
  for_each                = var.private_subnets
  vpc_id                  = aws_vpc.vpc_main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
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
  # route {
  #   cidr_block = "0.0.0.0/0"
  #   gateway_id = aws_internet_gateway.igw.id
  # }

  tags = {
    Name = "main-private-rt"
  }
}

resource "aws_route_table_association" "public_subnet_route_table_association" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_route_table_association" {
  for_each       = aws_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}


resource "aws_vpc_endpoint" "interface_endpoint_ecr_api" {
  vpc_id            = aws_vpc.vpc_main.id
  service_name      = "com.amazonaws.eu-north-1.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [for subnet in aws_subnet.public_subnet : subnet.id]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true
}


resource "aws_vpc_endpoint" "interface_endpoint_ecr_dkr" {
  vpc_id            = aws_vpc.vpc_main.id
  service_name      = "com.amazonaws.eu-north-1.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [for subnet in aws_subnet.public_subnet : subnet.id]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "gateway_endpoint_ecr_s3" {
  vpc_id            = aws_vpc.vpc_main.id
  service_name      = "com.amazonaws.eu-north-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_route_table.id]

}

resource "aws_vpc_endpoint" "gateway_endpoint_ecr_secrets" {
  vpc_id            = aws_vpc.vpc_main.id
  service_name      = "com.amazonaws.eu-north-1.secretsmanager"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [for subnet in aws_subnet.public_subnet : subnet.id]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "gateway_endpoint_ecr_logs" {
  vpc_id            = aws_vpc.vpc_main.id
  service_name      = "com.amazonaws.eu-north-1.logs"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [for subnet in aws_subnet.public_subnet : subnet.id]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]
  private_dns_enabled = true
}


resource "aws_security_group" "endpoint_sg" {
  name        = "endpoint_sg"
  description = "Allow HTTPS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc_main.id

  tags = {
    Name = "endpoint_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_endpoint" {
  security_group_id            = aws_security_group.endpoint_sg.id
  referenced_security_group_id = aws_security_group.ecs_allow_http.id
  from_port                    = 443
  ip_protocol                  = "tcp"
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_endpoint" {
  security_group_id = aws_security_group.endpoint_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
