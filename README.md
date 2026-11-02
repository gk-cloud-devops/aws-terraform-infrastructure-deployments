# Automated AWS Infrastructure Deployment with Terraform

This project demonstrates automated provisioning of AWS cloud infrastructure and application deployments using Infrastructure as Code (Terraform).

## Architecture Overview

### Task 1: PHP Application Deployment
* Custom VPC, Public Subnet, Internet Gateway, and Route Table
* EC2 Instance running Ubuntu with Nginx and PHP-FPM
* Automated configuration via user_data script

### Task 2: Containerized Node.js Microservice
* Custom VPC network with automated security rules
* Dockerized Node.js application running in an isolated environment
* Nginx configured as a reverse proxy on Port 80

## Tools & Technologies
* AWS (VPC, Subnet, IGW, EC2, Security Groups)
* Terraform (IaC)
* Docker & Containerization
* Nginx Reverse Proxy
* Ubuntu Linux & Shell Scripting
