provider "aws" {
  region = "us-east-1"
}

# 1 create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main_vpc_nk"
  }
}

# connect to-Public Subnet 1 (CIDR 10.0.102.0/24)
data "aws_subnet" "public_subnet_1" {
  id = "subnet-0ce80abd307eac787"
}

# connect to-Public Subnet 2 (CIDR 10.0.101.0/24)
data "aws_subnet" "public_subnet_2" {
  id = "subnet-00124604db2fbc34c"
}

# connect to-Private Subnet 1 (CIDR 10.0.2.0/24) - exist
data "aws_subnet" "private_subnet_1" {
  id = "subnet-057de053ba24e6eb8"
}

# create Private Subnet 2 new
resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.103.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "PrivateSubnet2"
  }
}

# connect to-Private Subnet 2 (CIDR 10.0.102.0/24)
data "aws_subnet" "private_subnet_2" {
  id = "subnet-0ce80abd307eac787"
}


# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"
}

# create Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "MainInternetGateway"
  }
}
# attached Elastic IP
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# create NAT Gateway in-Public Subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id 

  tags = {
    Name = "NAT-Gateway"
  }
}

# connect Internet Gateway to-Route Table ofPublic Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Public-RT"
  }
}

# IGW
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# route_table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Private-RT"
  }
}

# create NAT Gateway
resource "aws_route" "private_to_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}


# connect-Route Table of Public Subnets
# connect Public Subnets to-Route Table public
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = data.aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = data.aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# connect Private Subnets to-Route Table private
resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = data.aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}



# Security Group for-Bastion
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create Bastion Host
resource "aws_instance" "bastion_host" {
  ami                         = "ami-08d4ac5b634553e16" # Ubuntu 22.04
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  security_groups             = [aws_security_group.bastion_sg.id]
  key_name                    = "noakirel-keypair"
  associate_public_ip_address = true

  tags = {
    Name  = "BastionHost"
    owner = "meitaveini"
  }
}

# Security Group for private instances
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # SSH only from-Bastion
  }

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # connect only from-LB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create private instances (Ubuntu)
resource "aws_instance" "private_instance_1" {
  ami             = "ami-08d4ac5b634553e16"
  instance_type   = "t2.medium"
  subnet_id       = data.aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.private_sg.id]
  key_name        = "noakirel-keypair"

  tags = {
    Name  = "PrivateServer1"
    owner = "meitaveini"
  }
}

resource "aws_instance" "private_instance_2" {
  ami             = "ami-08d4ac5b634553e16"
  instance_type   = "t2.medium"
  subnet_id       = aws_subnet.private_subnet_2.id 
  security_groups = [aws_security_group.private_sg.id]
  key_name        = "noakirel-keypair"

  tags = {
    Name  = "PrivateServer2"
    owner = "meitaveini"
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Public Subnet 1 (AZ1)
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.101.0/24" 
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

# Public Subnet 2 (AZ2)
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.102.0/24" 
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
}
# Load Balancer with 2 subnets
resource "aws_lb" "web_lb" {
  name               = "web-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]

  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
}

# create Target Group
resource "aws_lb_target_group" "web_tg" {
  name        = "web-target-group"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"
}

# connect the instances to-TG
resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.private_instance_1.id
}

resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.private_instance_2.id
}

# create Listener in-LB for-TG
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
# AWS Auto Scaling Group with User Data and Tag Filtering

resource "aws_launch_template" "statuspage_lt" {
  name_prefix   = "statuspage-lt-"
  image_id      = "ami-08d4ac5b634553e16" # Ubuntu 22.04
  instance_type = "t2.medium"
  key_name      = "noakirel-keypair"

  # Load user-data script (base64 encoded)
  user_data = filebase64("${path.module}/docs/user-data.sh")

  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name  = "statuspage-prod"
      owner = "meitaveini"
      role  = "statuspage"
    }
  }
}

resource "aws_autoscaling_group" "statuspage_asg" {
  name                      = "statuspage-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 2
  vpc_zone_identifier       = [data.aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  health_check_type         = "EC2"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.statuspage_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "statuspage-prod"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "owner"
    value               = "meitaveini"
    propagate_at_launch = true
  }

  tag {
    key                 = "role"
    value               = "statuspage"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
