output "queue_url" {
  value = aws_sqs_queue.queue.id
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.id
}

output "queue_arn" {
  value = aws_sqs_queue.queue.arn
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}


