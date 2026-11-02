terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# 1. VPC
resource "aws_vpc" "php_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "interview-php-vpc"
  }
}

# 2. Public Subnet
resource "aws_subnet" "php_subnet" {
  vpc_id                  = aws_vpc.php_vpc.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-2a"

  tags = {
    Name = "interview-php-subnet"
  }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "php_igw" {
  vpc_id = aws_vpc.php_vpc.id

  tags = {
    Name = "interview-php-igw"
  }
}

# 4. Route Table & Association
resource "aws_route_table" "php_rt" {
  vpc_id = aws_vpc.php_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.php_igw.id
  }

  tags = {
    Name = "interview-php-rt"
  }
}

resource "aws_route_table_association" "php_assoc" {
  subnet_id      = aws_subnet.php_subnet.id
  route_table_id = aws_route_table.php_rt.id
}

# 5. Security Group (Port 80 allow cheyyuka)
resource "aws_security_group" "php_sg" {
  name        = "interview-php-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.php_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "interview-php-sg"
  }
}

# 6. Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 7. EC2 with Automated Task 1 script
resource "aws_instance" "php_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.php_subnet.id
  vpc_security_group_ids      = [aws_security_group.php_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Create 'php' user
              useradd -m -s /bin/bash php

              # 2. Install Nginx and PHP
              apt update -y
              DEBIAN_FRONTEND=noninteractive apt install -y nginx php-fpm git

              # 3. Create web directory and sample PHP app
              mkdir -p /var/www/sample-php
              chown -R php:php /var/www/sample-php

              cat << 'SUB_EOF' > /var/www/sample-php/index.php
              <!DOCTYPE html>
              <html>
              <head>
                  <title>Sample PHP App - Task 1</title>
                  <style>
                      body { font-family: sans-serif; text-align: center; margin-top: 50px; }
                      .box { border: 2px solid #2e7d32; display: inline-block; padding: 25px 40px; border-radius: 8px; }
                  </style>
              </head>
              <body>
                  <div class="box">
                      <h1>Task 1: PHP App Deployed Successfully!</h1>
                      <p>Created by user: <b>php</b></p>
                      <p>Server Time: <?php echo date("Y-m-d H:i:s"); ?></p>
                  </div>
              </body>
              </html>
              SUB_EOF

              chown php:php /var/www/sample-php/index.php

              # 4. Configure Nginx
              PHP_SOCK=$(find /var/run/php/ -name "php*-fpm.sock" | head -n 1)

              cat << NGINX_EOF > /etc/nginx/sites-available/php-app
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;
                  root /var/www/sample-php;
                  index index.php index.html;
                  server_name _;

                  location / {
                      try_files \$uri \$uri/ =404;
                  }

                  location ~ \.php\$ {
                      include snippets/fastcgi-php.conf;
                      fastcgi_pass unix:$PHP_SOCK;
                  }
              }
              NGINX_EOF

              rm -f /etc/nginx/sites-enabled/default
              ln -s /etc/nginx/sites-available/php-app /etc/nginx/sites-enabled/
              nginx -t
              systemctl restart nginx
              EOF

  tags = {
    Name = "interview-task1-php"
  }
}

output "task1_public_ip" {
  value = aws_instance.php_server.public_ip
}

output "task1_url" {
  value = "http://${aws_instance.php_server.public_ip}"
}
