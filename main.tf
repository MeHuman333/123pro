terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_private_key" {
  description = "Path to your private SSH key"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_public_key" {
  description = "Path to your public SSH key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

resource "aws_key_pair" "example" {
  key_name   = "key09"
  public_key = file(var.ssh_public_key)
  lifecycle {
    ignore_changes = [key_name]
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["your_ip/32"]  # Replace with your public IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "server" {
  ami           = "ami-0522ab6e1ddcc7055"
  instance_type = var.instance_type
  key_name      = aws_key_pair.example.key_name

  tags = {
    Name = "${terraform.workspace}_server"
  }

  provisioner "remote-exec" {
    inline = [
      "cat /etc/os-release",
      "mkdir -p /home/ubuntu/.ssh",
      "echo '${var.ssh_public_key}' >> /home/ubuntu/.ssh/authorized_keys",
      "chmod 600 /home/ubuntu/.ssh/authorized_keys",
      "chown -R ubuntu:ubuntu /home/ubuntu/.ssh"
    ]
    retries  = 5
    timeout  = "5m"
    interval = "30s"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key)
  }

  provisioner "local-exec" {
    command = "echo '${self.public_ip} ansible_user=ubuntu ansible_private_key_file=${var.ssh_private_key}' > inventory.ini"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -u ubuntu -i inventory.ini -e 'ansible_python_interpreter=/usr/bin/python3' ansible-playbook.yml"
  }
}
