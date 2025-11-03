# Busca as Zonas de Disponibilidade disponíveis na região
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. VPC
resource "aws_vpc" "monitoring_vpc" {
  cidr_block = "10.10.0.0/16"
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2. Internet Gateway
resource "aws_internet_gateway" "monitoring_igw" {
  vpc_id = aws_vpc.monitoring_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 3. Sub-rede pública
resource "aws_subnet" "monitoring_subnet" {
  vpc_id                  = aws_vpc.monitoring_vpc.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # Essencial para a instância ter IP público

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# 4. Tabela de Rotas para a Internet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.monitoring_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.monitoring_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 5. Associação da Rota
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.monitoring_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Security Group
resource "aws_security_group" "monitoring_sg" {
  name        = "${var.project_name}-sg"
  description = "Permite acesso ao Prometheus, Grafana e SSH"
  vpc_id      = aws_vpc.monitoring_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}