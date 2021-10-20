#Main Config 

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=3.42.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "DogoAL" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name        = "${var.prefix}-vpc-${var.region}"
    environment = "DogProduction"
  }
}

resource "aws_subnet" "DogoAL" {
  vpc_id     = aws_vpc.DogoAL.id
  cidr_block = var.subnet_prefix

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource "aws_security_group" "DogoAL" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.DogoAL.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-security-group"
  }
}

resource "aws_internet_gateway" "DogoAL" {
  vpc_id = aws_vpc.DogoAL.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource "aws_route_table" "DogoAL" {
  vpc_id = aws_vpc.DogoAL.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.DogoAL.id
  }
}

resource "aws_route_table_association" "DogoAL" {
  subnet_id      = aws_subnet.DogoAL.id
  route_table_id = aws_route_table.DogoAL.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "DogoAL" {
  instance = aws_instance.DogoAL.id
  vpc      = true
}

resource "aws_eip_association" "DogoAL" {
  instance_id   = aws_instance.DogoAL.id
  allocation_id = aws_eip.DogoAL.id
}

resource "aws_instance" "DogoAL" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.DogoAL.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.DogoAL.id
  vpc_security_group_ids      = [aws_security_group.DogoAL.id]

  tags = {
    Name = "${var.prefix}-DogoAL-instance"
  }
}


# Run the deploy_app.sh script.
resource "null_resource" "configure-dog-app" {
  depends_on = [aws_eip_association.DogoAL]

  triggers = {
    build_number = timestamp()
  }

  provisioner "file" {
    source      = "file/"
    destination = "/home/ubuntu/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.DogoAL.private_key_pem
      host        = aws_eip.DogoAL.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt -y update",
      "sleep 15",
      "sudo apt -y update",
      "sudo apt -y install apache2",
      "sudo systemctl start apache2",
      "sudo chown -R ubuntu:ubuntu /var/www/html",
      "chmod +x *.sh",
      "PLACEHOLDER=${var.placeholder} PREFIX=${var.prefix} ./deploy_app.sh",
      "sudo apt -y install cowsay",
      "cowsay -f tux I am not a Dog!",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.DogoAL.private_key_pem
      host        = aws_eip.DogoAL.public_ip
    }
  }
}

resource "tls_private_key" "DogoAL" {
  algorithm = "RSA"
}

locals {
  private_key_filename = "${var.prefix}-ssh-key.pem"
}

resource "aws_key_pair" "DogoAL" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.DogoAL.public_key_openssh
}
