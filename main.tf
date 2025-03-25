provider "aws" {
  region = "us-east-1"
}

# 1 יצירת VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main_vpc_nk"
  }
}

# חיבור ל-Public Subnet 1 (CIDR 10.0.102.0/24)
data "aws_subnet" "public_subnet_1" {
  id = "subnet-0ce80abd307eac787"
}

# חיבור ל-Public Subnet 2 (CIDR 10.0.101.0/24)
data "aws_subnet" "public_subnet_2" {
  id = "subnet-00124604db2fbc34c"
}

# חיבור ל-Private Subnet 1 (CIDR 10.0.2.0/24) - קיימת
data "aws_subnet" "private_subnet_1" {
  id = "subnet-057de053ba24e6eb8"
}

# יצירת Private Subnet 2 חדשה
resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.103.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false # פרטית

  tags = {
    Name = "PrivateSubnet2"
  }
}

# חיבור ל-Private Subnet 2 (CIDR 10.0.102.0/24)
data "aws_subnet" "private_subnet_2" {
  id = "subnet-0ce80abd307eac787"
}


# 3 Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"
}

# 4 יצירת Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "MainInternetGateway"
  }
}
# 5 הקצאת Elastic IP
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# 5 יצירת NAT Gateway ב-Public Subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id # חייב להיות בסאבנט ציבורי

  tags = {
    Name = "NAT-Gateway"
  }
}

# 6 חיבור Internet Gateway ל-Route Table של ה-Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Public-RT"
  }
}

# 7 הוספת חוק ניתוב שמפנה את כל התעבורה החוצה דרך ה-IGW
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# 8
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Private-RT"
  }
}

# 9 יצירת חוק ניתוב שגורם לכל התעבורה מה-Private Subnets לעבור דרך ה-NAT Gateway
resource "aws_route" "private_to_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}


# 10 חיבור ה-Route Table של ה-Public Subnets
# חיבור Public Subnets ל-Route Table הציבורי
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = data.aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = data.aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# חיבור Private Subnets ל-Route Table הפרטי
resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = data.aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}



# 12 Security Group עבור ה-Bastion
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # יש להחליף בכתובת IP ספציפית לגישה מאובטחת יותר
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5️⃣ יצירת Bastion Host
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

# 6️⃣ Security Group עבור השרתים הפרטיים
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # SSH רק מ-Bastion
  }

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # חיבור רק מה-LB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7️⃣ יצירת שרתים פרטיים (Ubuntu)
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
  subnet_id       = aws_subnet.private_subnet_2.id # פרטית חדשה
  security_groups = [aws_security_group.private_sg.id]
  key_name        = "noakirel-keypair"

  tags = {
    Name  = "PrivateServer2"
    owner = "meitaveini"
  }
}

# 8️⃣ Security Group עבור Load Balancer
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # חשיפה לכולם (רצוי לשנות לפי הצורך)
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
  cidr_block              = "10.0.101.0/24" # שינוי הכתובת
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

# Public Subnet 2 (AZ2)
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.102.0/24" # שינוי הכתובת
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
}
# Load Balancer עם שתי תתי-רשתות
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

# 🔟 יצירת Target Group
resource "aws_lb_target_group" "web_tg" {
  name        = "web-target-group"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"
}

# 1️⃣1️⃣ חיבור השרתים ל-TG
resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.private_instance_1.id
}

resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.private_instance_2.id
}

# 1️⃣2️⃣ יצירת Listener ב-LB להפניה ל-TG
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

