terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Configure Repo owner
provider "github" {
  owner = "Ritvik-S-Rao"
}


# RSA key of size 4096 bits
resource "tls_private_key" "app_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "python-app-deployer"
  public_key = tls_private_key.app_key.public_key_openssh
}

# Create Security Group
resource "aws_security_group" "app_sg" {
  name        = "python_app_sg"
  description = "Allow SSH and Flask traffic"


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 5000
    to_port          = 5000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

# Fetch the latest Ubuntu AMI from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true

  # Filter by name pattern (e.g., Ubuntu 24.04 LTS)
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Canonical's official AWS Account ID (constant across all public regions)
  owners = ["099720109477"] 
}

# Reference the fetched AMI inside your EC2 instance
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "Python-DemoApp-Server"
  }
}

# Inject Secrets into GitHub Repository
resource "github_actions_secret" "ec2_ip" {
  repository      = "python-demoapp-cicd"
  secret_name     = "EC2_HOST_IP"
  plaintext_value = aws_instance.web_server.public_ip
}

resource "github_actions_secret" "ec2_ssh_key" {
  repository      = "python-demoapp-cicd"
  secret_name     = "EC2_SSH_KEY"
  plaintext_value = tls_private_key.app_key.private_key_pem
}


