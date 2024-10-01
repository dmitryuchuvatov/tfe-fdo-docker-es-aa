variable "aws_region" {
  description = "TFE region where to deploy the resources"
}

variable "environment_name" {
  type        = string
  description = "Name used to create and tag resources"
}

variable "vpc_cidr" {
  type        = string
  description = "The IP range for the VPC in CIDR format"
}

variable "instance_type" {
  description = "The instance type of the EC2 instance"
}

variable "tfe_domain" {
  description = "The Route 53 hosted zone name"
}

variable "tfe_subdomain" {
  description = "The Route 53 subdomain"
}

variable "email" {
  description = "The email address for Let's Encrypt certificate"
}

variable "pem_file" {
  description = "The name of the file that contains the key pair"
}

variable "key_pair" {
  description = "The name of the Key Pair for EC2 instances"
}

variable "tfe_version" {
  description = "The TFE version release from https://developer.hashicorp.com/terraform/enterprise/releases"
}

variable "tfe_license" {
  description = "Value of the TFE FDO License"
}

variable "enc_password" {
  description = "The encryption password for my TFE installation"
}

variable "db_identifier" {
  description = "The DB identifier name"
}

variable "db_name" {
  description = "The DB name"
}

variable "db_username" {
  description = "The DB username"
}

variable "db_password" {
  description = "The DB password"
}








