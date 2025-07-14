resource "aws_sfn_state_machine" "orchestrator" {
  name     = "order-orchestrator"
  role_arn = var.sfn_role_arn
  definition = templatefile("${path.module}/definition.asl.json", {
    validator_arn     = var.validator_arn
    storage_arn       = var.storage_arn
    order_queue_url   = var.order_queue_url
  })
}
