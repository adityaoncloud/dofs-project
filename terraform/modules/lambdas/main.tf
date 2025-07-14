resource "aws_lambda_function" "this" {
  function_name = var.function_name
  handler       = var.handler
  runtime       = var.runtime
  role          = var.lambda_role_arn
  filename      = var.filename

  source_code_hash = filebase64sha256(var.filename)

  environment {
    variables = var.environment_variables
  }

  timeout = 30
}

resource "aws_cloudwatch_log_group" "log" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
}
