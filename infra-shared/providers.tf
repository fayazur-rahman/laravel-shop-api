provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "laravel-shop-api"
      Managedby = "Terraform"
      Lifetime  = "long-term"
    }
  }
}