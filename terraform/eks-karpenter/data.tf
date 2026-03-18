data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Get data from the remote state file
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "home-assignment-terraform-backend"
    key    = "vpc.tfstate"
    region = "ap-southeast-1"
  }
}
