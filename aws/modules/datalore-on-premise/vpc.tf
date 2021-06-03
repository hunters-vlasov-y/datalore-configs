resource "aws_eip" "datalore" {
  vpc      = true
  instance = aws_instance.datalore.id
  count    = var.use_elastic_ip ? 1 : 0
}
resource "aws_eip" "nat" {
  vpc        = true
  depends_on = [aws_internet_gateway.default]

  tags = {
    Name = "${var.name_prefix}-nat"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "on-premise" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = map(
    "Name", var.name_prefix
  )
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.on-premise.id
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.on-premise.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = {
    Name = var.name_prefix
  }
}

resource "aws_subnet" "datalore" {
  cidr_block        = var.datalore_cidr
  vpc_id            = aws_vpc.on-premise.id
  availability_zone = var.datalore_az

  tags = map(
    "Name", "${var.name_prefix}-datalore"
  )
}

resource "aws_subnet" "agents" {
  cidr_block              = var.agents_cidr
  vpc_id                  = aws_vpc.on-premise.id
  availability_zone       = var.datalore_az
  map_public_ip_on_launch = false

  tags = map(
    "Name", "${var.name_prefix}-agents"
  )
}

resource "aws_route_table" "agents" {
  vpc_id = aws_vpc.on-premise.id
  tags = {
    Name = "${var.name_prefix}-agents"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.datalore.id
  depends_on    = [aws_internet_gateway.default]
  tags = {
    Name = "${var.name_prefix}-nat"
  }
  count = var.use_nat_gateway ? 1 : 0
}

resource "aws_route" "agents" {
  route_table_id         = aws_route_table.agents.id
  destination_cidr_block = var.nat_gateway_routes[count.index]
  nat_gateway_id         = aws_nat_gateway.nat[0].id
  count                  = length(var.nat_gateway_routes)
}

resource "aws_route" "default_agents" {
  route_table_id         = aws_route_table.agents.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
  count                  = var.default_agents_route ? 1 : 0
}

resource "aws_route_table_association" "agents" {
  subnet_id      = aws_subnet.agents.id
  route_table_id = aws_route_table.agents.id
}

resource "aws_security_group" "datalore" {
  name   = "${var.name_prefix}-datalore"
  vpc_id = aws_vpc.on-premise.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    from_port   = 5050
    to_port     = 5050
    protocol    = "TCP"
    cidr_blocks = [var.agents_cidr]
  }

  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "TCP"
    cidr_blocks = [var.agents_cidr]
  }

  tags = map(
    "Name", "${var.name_prefix}-datalore"
  )
}

resource "aws_security_group" "datalore-http" {
  name   = "${var.name_prefix}-datalore-http"
  vpc_id = aws_vpc.on-premise.id

  ingress {
    from_port   = 8080
    to_port     = 8082
    protocol    = "TCP"
    cidr_blocks = var.external_cidr_blocks
  }

  tags = map(
    "Name", "${var.name_prefix}-datalore-http"
  )
}

resource "aws_security_group" "agents" {
  name   = "${var.name_prefix}-agents"
  vpc_id = aws_vpc.on-premise.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [var.datalore_cidr]
  }

  tags = map(
    "Name", "${var.name_prefix}-agents"
  )
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.on-premise.id
  cidr_block        = var.db_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  count             = length(var.db_cidrs)

  tags = {
    Name = "${var.name_prefix}-db${count.index}"
  }
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.name_prefix}-db"
  subnet_ids = aws_subnet.db.*.id
}

resource "aws_security_group" "db" {
  name   = "${var.name_prefix}-db"
  vpc_id = aws_vpc.on-premise.id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"

    cidr_blocks = [var.datalore_cidr]
  }
}
