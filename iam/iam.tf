terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.25.0"
    }
  }
}

provider "aws" {
  profile = "devops-rnd"
  region  = "eu-west-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_user" "iot-user" {
  name = "iot-user"
}

resource "aws_iam_policy" "pass-role-policy" {
  name = "pass-role-policy"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
        "Action": [
            "iam:GetRole",
            "iam:PassRole"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.iot-device-authorization-role-for-blog.name}"
    }
}
EOF
}

resource "aws_iam_user_policy_attachment" "attach-pass-role-policy-to-user" {
  user       = aws_iam_user.iot-user.name
  policy_arn = aws_iam_policy.pass-role-policy.arn
}

resource "aws_iam_role" "iot-device-authorization-role" {
  name = "iot-device-authorization-role-for-blog"

  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "credentials.iot.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
EOF
}

resource "aws_iam_policy" "iot-device-authorization-policy" {
  name        = "iot-device-authorization-policy"
  description = "Allows connecting, subscribing and sending messages to specific topic patterns"
  policy      = <<EOF
{
    "Statement": [
        {
            "Action": [
                "iot:Receive",
                "iot:Subscribe",
                "iot:Connect",
                "iot:Publish"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/$${credentials-iot:ThingName}",
                "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topicfilter/*/$${credentials-iot:ThingName}*",
                "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/*/$${credentials-iot:ThingName}*"
            ]
        }
    ],
    "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach-required-policies-to-iot-role" {
  role       = aws_iam_role.iot-device-authorization-role.name
  policy_arn = aws_iam_policy.iot-device-authorization-policy.arn
}

output "iot_device_authorization_role_arn" {
  value = aws_iam_role.iot-device-authorization-role.arn
}

output "aws_region" {
  value = data.aws_region.current.name
}