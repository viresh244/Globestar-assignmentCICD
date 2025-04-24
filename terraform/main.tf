# AWS Provider configuration
provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "secure-vm-vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "secure-vm-subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "secure-vm-igw"
  }
}

# Create a route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "secure-vm-route-table"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a security group for the VM
resource "aws_security_group" "vm_sg" {
  name        = "secure-vm-sg"
  description = "Security group for the secure VM"
  vpc_id      = aws_vpc.main.id

  # SSH access from your IP only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH access from my IP"
  }


# Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "secure-vm-sg"
  }
}

# Generate a key pair for SSH access
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key to a file
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "secure-vm-key.pem"
  file_permission = "0600"
}

# Create AWS key pair
resource "aws_key_pair" "vm_key_pair" {
  key_name   = "secure-vm-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Create the EC2 instance
resource "aws_instance" "secure_vm" {
  ami                    = var.ami_id # Amazon Linux 2 AMI
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.vm_sg.id]
  key_name               = aws_key_pair.vm_key_pair.key_name

  root_block_device {
    volume_size = 20
    encrypted   = true
  }

