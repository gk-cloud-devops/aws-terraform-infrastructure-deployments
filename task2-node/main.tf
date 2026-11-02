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

# 1. Custom VPC
resource "aws_vpc" "node_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "interview-node-vpc"
  }
}

# 2. Public Subnet
resource "aws_subnet" "node_subnet" {
  vpc_id                  = aws_vpc.node_vpc.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-2a"

  tags = {
    Name = "interview-node-subnet"
  }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "node_igw" {
  vpc_id = aws_vpc.node_vpc.id

  tags = {
    Name = "interview-node-igw"
  }
}

# 4. Route Table & Association
resource "aws_route_table" "node_rt" {
  vpc_id = aws_vpc.node_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.node_igw.id
  }

  tags = {
    Name = "interview-node-rt"
  }
}

resource "aws_route_table_association" "node_assoc" {
  subnet_id      = aws_subnet.node_subnet.id
  route_table_id = aws_route_table.node_rt.id
}

# 5. Security Group
resource "aws_security_group" "node_sg" {
  name        = "interview-node-sg"
  description = "Allow HTTP inbound"
  vpc_id      = aws_vpc.node_vpc.id

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
    Name = "interview-node-sg"
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

# 7. EC2 (t3.micro for Free Tier)
resource "aws_instance" "node_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.node_subnet.id
  vpc_security_group_ids      = [aws_security_group.node_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Create 'node' user
              useradd -m -s /bin/bash node

              # 2. Install Docker & Nginx
              apt update -y
              DEBIAN_FRONTEND=noninteractive apt install -y docker.io nginx git
              systemctl enable --now docker
              usermod -aG docker node

              # 3. Create workspace
              mkdir -p /home/node/app
              chown -R node:node /home/node/app

              # 4. Create Node.js sample code
              cat << 'SUB_EOF' > /home/node/app/package.json
              {
                "name": "sample-node-app",
                "version": "1.0.0",
                "main": "server.js",
                "scripts": {
                  "start": "node server.js"
                },
                "dependencies": {
                  "express": "^4.18.2"
                }
              }
              SUB_EOF

              cat << 'SUB_EOF' > /home/node/app/server.js
              const express = require('express');
              const app = express();
              const PORT = 3000;

              app.get('/', (req, res) => {
                  res.json({
                      status: "Success",
                      task: "Task 2 - Node.js App via Docker",
                      user: "node",
                      message: "Reverse proxied via Nginx on Port 80!"
                  });
              });

              app.listen(PORT, () => {
                  console.log(`Server running on port $${PORT}`);
              });
              SUB_EOF

              # 5. Write Dockerfile
              cat << 'SUB_EOF' > /home/node/app/Dockerfile
              FROM node:18-alpine
              WORKDIR /app
              COPY package*.json ./
              RUN npm install --production
              COPY . .
              EXPOSE 3000
              USER node
              CMD ["node", "server.js"]
              SUB_EOF

              chown -R node:node /home/node/app

              # 6. Build & Run Docker Container
              cd /home/node/app
              docker build -t sample-node-app:v1 .
              docker run -d --name node-service --restart always -p 3000:3000 sample-node-app:v1

              # 7. Setup Nginx Reverse Proxy
              cat << NGINX_EOF > /etc/nginx/sites-available/node-app
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;
                  server_name _;

                  location / {
                      proxy_pass http://127.0.0.1:3000;
                      proxy_http_version 1.1;
                      proxy_set_header Upgrade \$http_upgrade;
                      proxy_set_header Connection 'upgrade';
                      proxy_set_header Host \$host;
                      proxy_cache_bypass \$http_upgrade;
                  }
              }
              NGINX_EOF

              rm -f /etc/nginx/sites-enabled/default
              ln -s /etc/nginx/sites-available/node-app /etc/nginx/sites-enabled/
              nginx -t
              systemctl restart nginx
              EOF

  tags = {
    Name = "interview-task2-node"
  }
}

output "task2_public_ip" {
  value = aws_instance.node_server.public_ip
}

output "task2_url" {
  value = "http://${aws_instance.node_server.public_ip}"
}
