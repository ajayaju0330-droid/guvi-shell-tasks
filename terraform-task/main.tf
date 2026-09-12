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

resource "aws_instance" "server_region1" {
  provider      = aws.region1
  ami           = "ami-0360c520857e3138f"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-instance-us-east-1"
  }
}

resource "aws_instance" "server_region2" {
  provider      = aws.region2
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-instance-ap-south-1"
  }
}
