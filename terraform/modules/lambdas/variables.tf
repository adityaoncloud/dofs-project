variable "function_name" {}
variable "handler" {}
variable "runtime" {}
variable "filename" {}
variable "lambda_role_arn" {}
variable "environment_variables" {
  type    = map(string)
  default = {}
}
