provider "aws" {
  region = var.aws_region
}

##########################
# 1. DynamoDB Tables
##########################
module "dynamodb" {
  source = "./modules/dynamodb"
}

##########################
# 2. SQS Queues
##########################
module "sqs" {
  source = "./modules/sqs"
}

##########################
# 3. IAM Roles (Optional: can move to dedicated file later)
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
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
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
}

resource "aws_iam_role_policy_attachment" "stepfn_full_access" {
  role       = aws_iam_role.stepfunctions_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
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

resource "aws_iam_policy" "dlq_sqs_access" {
  name        = "dlq-sqs-access"
  description = "Allow DLQ Lambda to access SQS queue"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Effect   = "Allow",
        Resource = module.sqs.dlq_arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "attach_dlq_sqs_access" {
  name       = "attach_dlq_sqs_access"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.dlq_sqs_access.arn
}

resource "aws_lambda_event_source_mapping" "dlq_trigger" {
  event_source_arn  = module.sqs.dlq_arn
  function_name     = module.dlq_lambda.lambda_function_name
  batch_size        = 1
  enabled           = true
}

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
