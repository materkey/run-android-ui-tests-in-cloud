#!/bin/bash

set -xe

# TODO use secure way to store keys
export AWS_ACCESS_KEY_ID=XXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXX
export AWS_DEFAULT_REGION=us-east-1

timestamp=$(date +%d-%m-%Y_%H-%M-%S)
random_string=`uuidgen`
task_name="$timestamp-$random_string"
mkdir $task_name
cp app.apk $task_name/
cp test.apk $task_name/
cp Marathonfile $task_name/

aws s3 sync ./$task_name s3://my-tf-test-bucket-dc/$task_name

terraform init
terraform taint -allow-missing aws_instance.ui_tests_instance[0]
terraform apply -auto-approve -var="task_name=$task_name"

## sqs url example https://sqs.us-east-1.amazonaws.com/953451983374/terraform-example-queue1
queue_url=`sed -e 's/^"//' -e 's/"$//' <<<"$(terraform output data_aws_sqs_queue_url)"`
result="None"
while [ "$result" != "$task_name" ]; do
  echo "still no msg..."
  msg=$(aws sqs receive-message --queue-url $queue_url --max-number-of-messages 1 --wait-time-seconds 20)
	[ ! -z "$msg"  ] && receipt_handle=`echo "$msg" | jq -r '.Messages[] | .ReceiptHandle'`

  body=`echo "$msg" | jq -r '.Messages[] | .Body'`
	[ ! -z "$body" ] && result="$body"
  unset msg
  unset body
done

[ ! -z "$receipt_handle"  ] &&	aws sqs delete-message --queue-url $queue_url --receipt-handle $receipt_handle
unset receipt_handle

aws s3 sync s3://my-tf-test-bucket-dc/$task_name ./$task_name
aws s3 rm s3://my-tf-test-bucket-dc/$task_name --recursive
terraform destroy -auto-approve -var="task_name=$task_name"
