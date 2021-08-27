terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure AWS provider and Access/Secret keys
provider "aws" {
  region = "eu-west-2"
  
}

# 1. Create a VPC

resource "aws_vpc" "assignment_vpc" {
  cidr_block = "10.0.0.0/16"
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "assignment_gateway" {
  vpc_id = aws_vpc.assignment_vpc.id

  tags = {
    Name = "main"
  }
}

# 3. Create Custom Route Table

resource "aws_route_table" "assignment_routeTable" {
  vpc_id = aws_vpc.assignment_vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.assignment_gateway.id
  }
    
  tags = {
    Name = "example"
  }

}


# 4. Create a subnet

resource "aws_subnet" "assignment_subnet" {
  vpc_id = aws_vpc.assignment_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "subnet_dev"
  }
}

# 5. Associate subnet with Route Table

resource "aws_route_table_association" "route_association" {
  subnet_id = aws_subnet.assignment_subnet.id
  route_table_id = aws_route_table.assignment_routeTable.id
}

# 6. Create Security Group to allow port 22,80,443

resource "aws_security_group" "assignment_security_group" {
  name = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id = aws_vpc.assignment_vpc.id

  ingress {
      description = "TLS from VPC"
      from_port = 433
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

  ingress  {
      description = "SHH"
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
      description = "HTTP"
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "assignment_route" {
  subnet_id       = aws_subnet.assignment_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.assignment_security_group.id]

}
# 8. Assign an elastic IP to the network interface created n step 7

resource "aws_eip" "lb" {
  network_interface = aws_network_interface.assignment_route.id
  associate_with_private_ip = "10.0.1.50"
  vpc      = true
  depends_on = [
    aws_internet_gateway.assignment_gateway
  ]
}

# 9. Create Ubuntu Server and install/enable apache2

resource "aws_instance" "aws-web-instance" {
  ami = "ami-0194c3e07668a7e36"
  instance_type = "t2.micro"
  availability_zone = "eu-west-2a"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.assignment_route.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server wow > /var/www/html/index.html'
              EOF
      
  tags = {
    Name = "Web-server"
  }
}