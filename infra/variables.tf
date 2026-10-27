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

variable "image_tag" {
  description = "Image tag to run for both app and web images."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{7,40}$", var.image_tag))
    error_message = "image_tag must be a git commit SHA (7-40 hex characters), never 'latest'."
  }
}

variable "app_key" {
  description = "Laravel App key passed via tf_var_app_key, never a tfvars file."
  type        = string
  sensitive   = true

  validation {
    condition     = startswith(var.app_key, "base64:")
    error_message = "app_key must look like base64:... (output of php artisan key:generate --show)."
  }
}

variable "web_desired_count" {
  description = "Number of web containers to run"
  type        = number
  default     = 1

  validation {
    condition     = var.web_desired_count >= 1 && var.web_desired_count <= 3
    error_message = "web_desired_count must be between 1 and 3"
  }
}