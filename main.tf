provider "aws" {
  region = "us-east-2"
}

resource "aws_spot_instance_request" "ui_tests_instance" {
  count = 1
  spot_price = "1.00" // https://aws.amazon.com/ec2/spot/pricing/
  ami = "ami-002068ed284fb165b" // replace with ami based on "ami-002068ed284fb165b" Amazon Linux 2 from AMI Catalog with docker and android sdk
  wait_for_fulfillment = false
  availability_zone = "us-east-2b"
  instance_type = "c5.metal"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  user_data = templatefile("bootstrap_instance.sh.tpl", {
    queue_url = data.aws_sqs_queue.terraform_queue.url
    region = data.aws_region.current.name
    task_name = var.task_name
  })
  key_name = aws_key_pair.ssh_key_for_instance.key_name
  iam_instance_profile = aws_iam_instance_profile.ui_tests_profile.id

  root_block_device {
    volume_size = "40"
    volume_type = "standard"
  }

  tags = {
    Name = "Android UI tests runner - ${var.task_name}"
    Owner = "Vyacheslav Kovalev"
    Project = "Terraform Android UI tests Infra"
  }

  volume_tags = {
    Name = "${var.task_name}-disk"
  }
}

resource "aws_sqs_queue" "terraform_queue" {
  name = "sqs-${var.task_name}"
  fifo_queue = false
}

resource "aws_iam_instance_profile" "ui_tests_profile" {
  name = "profile_${var.task_name}"
  role = aws_iam_role.ec2_iam_role.name
}

resource "aws_iam_role" "ec2_iam_role" {
  name = "ec2_role${var.task_name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2-read-only-policy-attachment" {
  role = aws_iam_role.ec2_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sqs-read-only-policy-attachment" {
  role = aws_iam_role.ec2_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key_for_instance" {
  key_name = "keyName${var.task_name}"
  public_key = tls_private_key.pk.public_key_openssh
  provisioner "local-exec" {
    command = <<-EOT
      rm -f terraform_ec2_key.pem
      echo '${tls_private_key.pk.private_key_pem}' > ./terraform_ec2_key.pem
      chmod 400 ./terraform_ec2_key.pem
    EOT
  }
}

//resource "aws_s3_bucket" "b" {
//  bucket = "my-tf-test-bucket-dc"
//  acl = "private"
//
//  tags = {
//    Name = "My bucket"
//    Environment = "Dev"
//  }
//}

resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh_${var.task_name}"
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
    Owner = "Vyacheslav Kovalev"
  }
}