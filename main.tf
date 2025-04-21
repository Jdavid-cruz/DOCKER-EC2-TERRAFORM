# Configuro el proveedor para trabajar con AWS en la región us-east-1
provider "aws" {
  region = "us-east-1"
}

# Creo una VPC personalizada con soporte para DNS y nombres de host
resource "aws_vpc" "cloudgram_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cloudgram-vpc"
  }
}

# Subredes públicas en dos zonas de disponibilidad distintas
resource "aws_subnet" "subred_publica_1" {
  vpc_id                  = aws_vpc.cloudgram_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cloudgram-subred-publica-1"
  }
}

resource "aws_subnet" "subred_publica_2" {
  vpc_id                  = aws_vpc.cloudgram_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "cloudgram-subred-publica-2"
  }
}

# Subredes privadas (una en cada AZ), sin IPs públicas
resource "aws_subnet" "subred_privada_1" {
  vpc_id                  = aws_vpc.cloudgram_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "cloudgram-subred-privada-1"
  }
}

resource "aws_subnet" "subred_privada_2" {
  vpc_id                  = aws_vpc.cloudgram_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "cloudgram-subred-privada-2"
  }
}

# Internet Gateway para permitir salida a Internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cloudgram_vpc.id

  tags = {
    Name = "cloudgram-igw"
  }
}

# Tabla de rutas pública
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cloudgram_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "cloudgram-public-rt"
  }
}

# Asociaciones de subredes públicas con la tabla de rutas
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.subred_publica_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.subred_publica_2.id
  route_table_id = aws_route_table.public_rt.id
}

# IP elástica para el NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# NAT Gateway en una subred pública
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subred_publica_1.id

  tags = {
    Name = "cloudgram-nat-gw"
  }
}

# Tabla de rutas para subredes privadas
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.cloudgram_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "cloudgram-private-rt"
  }
}

# Asociación de subredes privadas con la tabla privada
resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.subred_privada_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.subred_privada_2.id
  route_table_id = aws_route_table.private_rt.id
}

# SG para el Bastion Host (solo SSH desde mi IP)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Permitir SSH solo desde mi IP"
  vpc_id      = aws_vpc.cloudgram_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["92.59.51.182/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudgram-bastion-sg"
  }
}

# Par de claves para conectarme al Bastion Host
resource "aws_key_pair" "cloudgram_key" {
  key_name   = "cloudgram-clave"

  public_key = <<EOF
ssh-rsa AAAA...
EOF

  tags = {
    Name = "clave-bastion"
  }
}

# Grupo de subredes para instancias RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "cloudgram-rds-subnet-group"

  subnet_ids = [
    aws_subnet.subred_privada_1.id,
    aws_subnet.subred_privada_2.id
  ]

  tags = {
    Name = "cloudgram-rds-subnet-group"
  }
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subred_publica_1.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.cloudgram_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "cloudgram-bastion"
  }
}

# SG para el servidor web
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Permitir HTTP, SSH y puerto 5000"
  vpc_id      = aws_vpc.cloudgram_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["92.59.51.182/32"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudgram-web-sg"
  }
}

# Instancia EC2 para la app web (con Docker)
resource "aws_instance" "web_server" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subred_publica_2.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = aws_key_pair.cloudgram_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "cloudgram-web-server"
  }
}

# Security Group para RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Permitir PostgreSQL desde Bastion y Web Server"
  vpc_id      = aws_vpc.cloudgram_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudgram-rds-sg"
  }
}

# Permitir a Web Server acceder a RDS
resource "aws_security_group_rule" "allow_rds_from_web" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.web_sg.id
  description              = "Permitir PostgreSQL desde el Web Server"
}

# Instancia RDS PostgreSQL
resource "aws_db_instance" "cloudgram_db" {
  identifier              = "cloudgram-db"
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "17.2"
  instance_class          = "db.t3.micro"
  username                = "postgres"
  password                = "cloudgram123"
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
  storage_encrypted       = true

  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  tags = {
    Name = "cloudgram-db"
  }
}
