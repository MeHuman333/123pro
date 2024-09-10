terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# Define Key Pair
resource "aws_key_pair" "example" {
  key_name   = "key-pair"
  public_key = file("~/.ssh/id_ed25519.pub")
}

# Define Security Group to Allow SSH
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["54.225.23.141/32"]  # Replace with Jenkins or local machine IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define EC2 Instance
resource "aws_instance" "server" {
  ami           = "ami-0522ab6e1ddcc7055"
  instance_type = var.instance_type
  key_name      = aws_key_pair.example.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  tags = {
    Name = "${terraform.workspace}_server"
  }

  # Provisioner for remote execution
  provisioner "remote-exec" {
    inline = [
      "cat /etc/os-release",
      "mkdir -p /home/ubuntu/.ssh",
      "echo '${var.ssh_public_key}' >> /home/ubuntu/.ssh/authorized_keys",
      "chmod 600 /home/ubuntu/.ssh/authorized_keys",
      "chown -R ubuntu:ubuntu /home/ubuntu/.ssh"
    ]

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key)
      timeout     = "10m"  # Increased timeout to allow instance initialization
    }
  }

  # Provisioner for local execution
  provisioner "local-exec" {
    command = "echo '${self.public_ip} ansible_user=ubuntu ansible_private_key_file=~/.ssh/id_ed25519' > inventory.ini"
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i inventory.ini -e 'ansible_python_interpreter=/usr/bin/python3' ansible-playbook.yml"
  }
}

