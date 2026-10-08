variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone_1" {
  description = "Availability zone for the first public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_2" {
  description = "Availability zone for the second public subnet"
  type        = string
  default     = "us-east-1b"
}

variable "ssh_key_name" {
description = "The name of the SSH key pair to be created"
type = string
default = "deployer_key"
}
# EC2 Instance Type
variable "instance_type" {
description = "The type of EC2 instance"
type = string
default = "t2.micro"
}
# EC2 AMI ID
variable "ec2_ami_id" {
description = "The AMI ID for the EC2 instance"
type = string
default = "ami-0866a3c8686eaeeba"
}

