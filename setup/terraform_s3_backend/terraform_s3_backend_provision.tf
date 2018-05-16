## Configure the AWS Provider
#
provider "aws" {
  region      = "ap-southeast-2"
}

## Versioned S3 bucket for Terraform state
#
resource "aws_s3_bucket" "bbl-ops" {
  bucket  = "bbl-ops"
  acl     = "private"
  force_destroy = "true"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
  tags {
    Name    = "bbl-ops"
  }
}

resource "aws_dynamodb_table" "bbl-ops-terraform-state-lock" {
  name           = "bbl-ops-terraform-state-lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "bucketname" {
  value = "${aws_s3_bucket.bbl-ops.bucket}"
}

output "dynamodb-name" {
  value = "${aws_dynamodb_table.bbl-ops-terraform-state-lock.name}"
}

output "dynamodb-arn" {
  value = "${aws_dynamodb_table.bbl-ops-terraform-state-lock.arn}"
}
