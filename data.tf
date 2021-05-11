data "aws_availability_zones" "working" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_sqs_queue" "terraform_queue" {
  name = aws_sqs_queue.terraform_queue.name
}