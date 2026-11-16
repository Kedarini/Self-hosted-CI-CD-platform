terraform {
  backend "s3" {
    bucket = "tfstate"
    key    = "terraform.tfstate"
    region = var.aws_region
    endpoints = {
      s3 = "http://localhost:4566"
    }
    access_key                  = "test"
    secret_key                  = "test"
    use_lockfile                = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
  required_version = ">= 1.10.0"
}
