output "api_url" {
  value = module.api_gateway.api_url
}

output "orders_table" {
  value = module.dynamodb.orders_table_name
}

output "step_function_arn" {
  value = module.stepfunctions.state_machine_arn
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}
