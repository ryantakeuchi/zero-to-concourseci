## Configure the AWS Provider
#
provider "aws" {
  region      = "ap-southeast-2"
}

## IAM User for bbl
#
resource "aws_iam_user" "bbl" {
  name = "bosh-bootloader"
}

resource "aws_iam_access_key" "bbl" {
  user = "${aws_iam_user.bbl.name}"
}

resource "aws_iam_user_policy" "bbl-policy" {
  name = "bosh-bootloader"
  user = "${aws_iam_user.bbl.name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:*",
                "rds:*",
                "s3:*",
                "kms:*",
                "logs:*",
                "route53:*",
                "ec2:*",
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

output "aws user" {
  value = "${aws_iam_user.bbl.name}"
}

output "aws_access_key_id" {
  value = "${aws_iam_access_key.bbl.id}"
}

output "aws_secret_access_key" {
  value = "${aws_iam_access_key.bbl.secret}"
}
