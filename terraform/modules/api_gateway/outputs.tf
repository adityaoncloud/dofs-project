output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "api_arn" {
  value = aws_apigatewayv2_api.api.arn
}

output "api_id" {
  value = aws_apigatewayv2_api.api.id
}

output "api_execution_arn" {
  value = aws_apigatewayv2_api.api.execution_arn
}