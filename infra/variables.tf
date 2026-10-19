variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project Name"
  type        = string
  default     = "laravel-shop-api"
}

variable "environment" {
  description = "Environment Name"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block"
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "Provide exactly two availability zones"
  }
}