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

# Define variables
variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "root_pass" {
  type    = string
  default = "ansible"
}

variable "instance_name" {
  type    = string
  default = "server"
}

variable "ssh_private_key" {
  type    = string
  default = "/var/lib/jenkins/.ssh/id_ed25519"
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA8sAMf6gNWEHRWfBZIemM2GqUc46MeaH64LZAbTT9ad"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "allowed_ip" {
  description = "IP allowed for SSH access"
  type        = string
  default     = "3.85.104.164/32"  # Replace with your actual IP address
}

# Create or import the AWS key pair
resource "aws_key_pair" "example" {
  key_name   = "key09"
  public_key = var.ssh_public_key

  lifecycle {
    prevent_destroy = true  # Prevent keypair from being destroyed
    ignore_changes  = [key09]  # Ignore changes to key_name to avoid recreation issues
  }
}

# Security group to allow SSH
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]  # Restrict SSH to the allowed IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance configuration
resource "aws_instance" "server" {
  ami           = "ami-0522ab6e1ddcc7055"  # Use a valid Ubuntu AMI
  instance_type = var.instance_type
  key_name      = aws_key_pair.example.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  tags = {
    Name = var.instance_name
  }

  # SSH connection configuration
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key)
  }

  # Remote-exec provisioner to configure the instance
  provisioner "remote-exec" {
    inline = [
      "cat /etc/os-release",
      "mkdir -p /home/ubuntu/.ssh",
      "echo '${var.ssh_public_key}' >> /home/ubuntu/.ssh/authorized_keys",
      "chmod 600 /home/ubuntu/.ssh/authorized_keys",
      "chown -R ubuntu:ubuntu /home/ubuntu/.ssh"
    ]
    retries  = 5        # Retry up to 5 times in case of SSH connection issues
    timeout  = "5m"     # Set a 5-minute timeout for the remote execution
    interval = "30s"    # Wait for 30 seconds between retries
  }

  # Local-exec provisioner to generate an Ansible inventory file
  provisioner "local-exec" {
    command = "echo '${self.public_ip} ansible_user=ubuntu ansible_private_key_file=${var.ssh_private_key}' > inventory.ini"
  }

  # Run the Ansible playbook
  provisioner "local-exec" {
    command = "ansible-playbook -u ubuntu -i inventory.ini -e 'ansible_python_interpreter=/usr/bin/python3' ansible-playbook.yml"
  }
}
