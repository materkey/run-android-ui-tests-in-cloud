output "data_aws_availability_zones" {
  value = data.aws_availability_zones.working.names
}

output "data_aws_caller_identity" {
  value = data.aws_caller_identity.current.account_id
}

output "data_aws_region_name" {
  value = data.aws_region.current.name
}

output "data_aws_region_description" {
  value = data.aws_region.current.description
}

output "webserver_instance_id" {
  value = aws_spot_instance_request.ui_tests_instance[0].id
}

output "webserver_sg_id" {
  value = aws_security_group.allow_ssh.id
}

output "webserver_sg_arn" {
  value = aws_security_group.allow_ssh.arn
  description = "This id SecurityGroup ARN"
}

output "data_aws_sqs_queue_url" {
  value = data.aws_sqs_queue.terraform_queue.url
}
