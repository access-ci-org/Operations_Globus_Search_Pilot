variable "instance_type" {
          default = "t4g.medium"
}

variable "key_pair" {
          default = "accessops-aws-root"
}

variable "elastic_ip_search_pilot" {
  default = null
}

variable "default_tags" {
  default = {
    "WBS"       = "ACCESS CONECT 1.2"
  }
  type = map(string)
}

data "aws_ami" "ubuntu22_ami_id" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

output "latest_ubuntu22_ami" {
  value = data.aws_ami.ubuntu22_ami_id.image_id
}
