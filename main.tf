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

# Define variables for instance_type, SSH keys
variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t2.micro"  # Default value; change as needed
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

# Create or use existing key pair
resource "aws_key_pair" "example" {
  key_name   = "key09"
  public_key = file(var.ssh_public_key)
}

resource "aws_instance" "server" {
  ami           = "ami-0522ab6e1ddcc7055"
  instance_type = var.instance_type
  key_name      = aws_key_pair.example.key_name

  tags = {
    Name = "${terraform.workspace}_server"
  }

  # Remote exec provisioner to execute commands on the instance
  provisioner "remote-exec" {
    inline = [
      "sleep 30",  # Add delay to wait for the instance to be ready
      "cat /etc/os-release",
      "mkdir -p /home/ubuntu/.ssh",
      "echo '${var.ssh_public_key}' >> /home/ubuntu/.ssh/authorized_keys",
      "chmod 600 /home/ubuntu/.ssh/authorized_keys",
      "chown -R ubuntu:ubuntu /home/ubuntu/.ssh"
    ]
  }

  # Connection configuration for remote-exec
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key)
  }

  # Local-exec provisioner to create the Ansible inventory file
  provisioner "local-exec" {
    command = "echo '${self.public_ip} ansible_user=ubuntu ansible_private_key_file=${var.ssh_private_key}' > inventory.ini"
  }

  # Local-exec provisioner to run the Ansible playbook
  provisioner "local-exec" {
    command = "ansible-playbook -u ubuntu -i inventory.ini -e 'ansible_python_interpreter=/usr/bin/python3' ansible-playbook.yml"
  }
}
