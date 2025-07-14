resource "aws_sqs_queue" "dlq" {
  name = "order_dlq"
}

resource "aws_sqs_queue" "queue" {
  name = "order_queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}
