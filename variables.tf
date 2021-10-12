
# General

variable "access_key" {}
variable "secret_key" {}
variable "project" {  }

variable "region" {  }

variable "project_env" { }

# VPC

variable "vpc_cidr" {  }

# SG 
variable "port" {  }
variable "resource_name" {  }
variable "desc" { }

# VM
variable "public_key" {}

variable "ami" {  }

variable "instance_type" { }

variable "vm_volume_size" { }

# Lambda name