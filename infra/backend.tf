terraform {
  backend "s3" {
    bucket       = "fayazur-tfstate"
    key          = "laravel-shop-api/infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
