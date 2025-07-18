provider "aws" {
  region = var.aws_region
}

##########################
# 1. DynamoDB Tables
##########################
module "dynamodb" {
  source = "./modules/dynamodb"
}

data "aws_caller_identity" "current" {}

##########################
# 2. SQS Queues
##########################
module "sqs" {
  source = "./modules/sqs"
}

##########################
# 3. IAM Roles (Admin Access for Testing)
##########################
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = "testing"
    Purpose     = "lambda-execution-with-admin-access"
  }
}

# Administrator access for testing purposes - gives full AWS permissions
resource "aws_iam_role_policy_attachment" "lambda_admin_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Basic Lambda execution policy (CloudWatch Logs access)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##########################
# 4. Lambda Functions
##########################
module "api_handler_lambda" {
  source              = "./modules/lambdas"
  function_name       = "api_handler"
  handler             = "handler.lambda_handler"
  runtime             = "python3.12"
  filename            = "${path.module}/../lambdas/api_handler/function.zip"
  lambda_role_arn     = aws_iam_role.lambda_exec_role.arn
  environment_variables = {
    STATE_MACHINE_ARN = module.stepfunctions.state_machine_arn
  }
}

module "validator_lambda" {
  source              = "./modules/lambdas"
  function_name       = "validator"
  handler             = "handler.lambda_handler"
  runtime             = "python3.12"
  filename            = "${path.module}/../lambdas/validator/function.zip"
  lambda_role_arn     = aws_iam_role.lambda_exec_role.arn
}

module "order_storage_lambda" {
  source              = "./modules/lambdas"
  function_name       = "order_storage"
  handler             = "handler.lambda_handler"
  runtime             = "python3.12"
  filename            = "${path.module}/../lambdas/order_storage/function.zip"
  lambda_role_arn     = aws_iam_role.lambda_exec_role.arn
  environment_variables = {
    ORDERS_TABLE = module.dynamodb.orders_table_name
  }
}

module "fulfill_order_lambda" {
  source              = "./modules/lambdas"
  function_name       = "fulfill_order"
  handler             = "handler.lambda_handler"
  runtime             = "python3.12"
  filename            = "${path.module}/../lambdas/fulfill_order/function.zip"
  lambda_role_arn     = aws_iam_role.lambda_exec_role.arn
  environment_variables = {
    ORDERS_TABLE      = module.dynamodb.orders_table_name
    FAILURE_THRESHOLD = "0.3"
  }
}

##########################
# 5. API Gateway
##########################
module "api_gateway" {
  source     = "./modules/api_gateway"
  lambda_uri = module.api_handler_lambda.lambda_function_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.api_handler_lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.api_arn}/*/*"
}

# Fallback permission - allows any API Gateway in the account/region
resource "aws_lambda_permission" "api_gateway_lambda_fallback" {
  statement_id  = "AllowAPIGatewayInvokeFallback"
  action        = "lambda:InvokeFunction"
  function_name = module.api_handler_lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
}

##########################
# 6. Step Functions
##########################
resource "aws_iam_role" "stepfunctions_exec_role" {
  name = "stepfunctions_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = "testing"
    Purpose     = "stepfunctions-execution-with-admin-access"
  }
}

# Administrator access for Step Functions as well
resource "aws_iam_role_policy_attachment" "stepfn_admin_access" {
  role       = aws_iam_role.stepfunctions_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

module "stepfunctions" {
  source            = "./modules/stepfunctions"
  sfn_role_arn      = aws_iam_role.stepfunctions_exec_role.arn
  validator_arn     = module.validator_lambda.lambda_function_arn
  storage_arn       = module.order_storage_lambda.lambda_function_arn
  order_queue_url   = module.sqs.queue_url
}

module "dlq_lambda" {
  source              = "./modules/lambdas"
  function_name       = "dlq_handler"
  handler             = "handler.lambda_handler"
  runtime             = "python3.12"
  filename            = "${path.module}/../lambdas/dlq_handler/function.zip"
  lambda_role_arn     = aws_iam_role.lambda_exec_role.arn
  environment_variables = {
    FAILED_ORDERS_TABLE = module.dynamodb.failed_orders_table_name
  }
}

# SQS Event Source Mapping for DLQ
resource "aws_lambda_event_source_mapping" "dlq_trigger" {
  event_source_arn  = module.sqs.dlq_arn
  function_name     = module.dlq_lambda.lambda_function_name
  batch_size        = 1
  enabled           = true
}

##########################
# 7. CloudWatch Monitoring
##########################
resource "aws_cloudwatch_metric_alarm" "dlq_alert" {
  alarm_name          = "DLQDepthExceeded"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggered when DLQ depth > 1"
  dimensions = {
    QueueName = "order_dlq"
  }
}

##########################
# 8. API Gateway CloudWatch Role
##########################
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

##########################
# 9. CI/CD Module
##########################
module "cicd" {
  source = "./cicd"
}

##########################
# 10. Debugging Outputs
##########################
output "lambda_function_arn" {
  value = module.api_handler_lambda.lambda_function_arn
}

output "api_gateway_arn" {
  value = module.api_gateway.api_arn
}

output "lambda_permission_source_arn" {
  value = "${module.api_gateway.api_arn}/*/*"
}

output "fallback_permission_arn" {
  value = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
}