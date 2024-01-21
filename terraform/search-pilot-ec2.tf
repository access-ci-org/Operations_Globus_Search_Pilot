resource "aws_instance" "search-pilot" {
  ami               = "ami-02f278ae3ad20eb32"
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

output "current_operations1_ami" {
  value = aws_instance.search-pilot.ami
}

resource "aws_eip_association" "search-pilot-eip-association" {
  instance_id   = aws_instance.search-pilot.id
  allocation_id = var.elastic_ip_search_pilot
}
