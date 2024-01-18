data "aws_ami" "ubuntu22_lookup" {
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

resource "aws_instance" "search-pilot" {
  ami               = data.aws_ami.ubuntu22_lookup.id
  instance_type     = var.instance_type
  availability_zone = "us-east-2a"
  #    associate_public_ip_address = true
  vpc_security_group_ids = ["sg-0a22ccc3b8f221d80", "sg-065b34352d2cdb8dc"]
  key_name          = var.key_pair
  subnet_id         = "subnet-024d3f2e0efeb4201"
  root_block_device {
    volume_size = "32"
  }
  tags = {
    "Name" = "search-pilot.access-ci.org"
  }
}
