terraform {
  backend "s3" {
    bucket = "dofs-state-bucket-1"
    key    = "dofs/dev/terraform.tfstate"
    region = "ap-south-1"
    encrypt = true
    dynamodb_table = "dofs-terraform-lock"

 }
}