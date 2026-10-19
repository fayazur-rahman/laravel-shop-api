terraform {
  backend "s3" {
    bucket       = "fayazur-state-bucket"
    key          = "laravel-shop-api/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
