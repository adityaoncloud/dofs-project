variable "aws_region" {
  default = "ap-south-1"
}

variable "github_token" {
  description = "OAuth token for GitHub access"
  type        = string
  sensitive   = true
}
