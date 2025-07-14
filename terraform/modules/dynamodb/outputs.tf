output "orders_table_name" {
  value = aws_dynamodb_table.orders.name
}

output "failed_orders_table_name" {
  value = aws_dynamodb_table.failed_orders.name
}
