packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "custom-ubuntu-docker-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  instance_type = "t3.micro"
  region        = "eu-central-1"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"
}

build {
  name = "build-docker-ami"
  sources = [
    "sources.amazon-ebs.ubuntu",
  ]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for apt/dpkg locks...'",
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done",
      "while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 2; done",

      "export DEBIAN_FRONTEND=noninteractive",
      "sudo apt-get update -y",
      "sudo apt-get install -y software-properties-common",
      "sudo add-apt-repository universe -y",
      "sudo apt-get update -y",

      "sudo apt-get install -y docker.io docker-compose-v2 awscli netcat-openbsd",

      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu",

      "sudo snap install amazon-ssm-agent --classic",
      "sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service",
      "sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service"
    ]
  }
}