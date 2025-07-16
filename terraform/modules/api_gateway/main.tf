# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/order-api"
  retention_in_days = 14
}

# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "order-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type", "x-amz-date", "authorization", "x-api-key"]
    allow_methods     = ["*"]
    allow_origins     = ["*"]
    expose_headers    = ["date", "keep-alive"]
    max_age           = 86400
  }
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.lambda_uri
  integration_method = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds = 30000
}

# Route
resource "aws_apigatewayv2_route" "order_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /order"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage with logging enabled
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      error_message  = "$context.error.message"
      error_type     = "$context.error.messageString"
      integration_error = "$context.integration.error"
      integration_status = "$context.integration.status"
      integration_latency = "$context.integration.latency"
      response_latency = "$context.responseLatency"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = true
    logging_level            = "INFO"
    data_trace_enabled       = true
    throttling_burst_limit   = 5000
    throttling_rate_limit    = 10000
  }
}