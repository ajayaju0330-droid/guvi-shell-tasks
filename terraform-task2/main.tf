terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "region1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "region2"
  region = "ap-south-1"
}

resource "aws_security_group" "web_sg_region1" {
  provider    = aws.region1
  name        = "nginx-sg-region1"
  description = "Allow SSH and HTTP"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_sg_region2" {
  provider    = aws.region2
  name        = "nginx-sg-region2"
  description = "Allow SSH and HTTP"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "server_region1" {
  provider               = aws.region1
  ami                    = "ami-0360c520857e3138f"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_region1.id]

  user_data = <<-EOF2
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF2

  tags = {
    Name = "terraform-nginx-us-east-1"
  }
}

resource "aws_instance" "server_region2" {
  provider               = aws.region2
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_region2.id]

  user_data = <<-EOF2
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF2

  tags = {
    Name = "terraform-nginx-ap-south-1"
  }
}

output "region1_public_ip" {
  value = aws_instance.server_region1.public_ip
}

output "region2_public_ip" {
  value = aws_instance.server_region2.public_ip
}
