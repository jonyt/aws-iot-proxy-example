provider "aws" {
  profile = "devops-rnd"
  region  = data.terraform_remote_state.iam-state.outputs.aws_region
}

data "aws_iot_endpoint" "data" {
  endpoint_type = "iot:Data-ATS"
}

data "aws_iot_endpoint" "credentials" {
  endpoint_type = "iot:CredentialProvider"
}

data "terraform_remote_state" "iam-state" {
  backend = "local"

  config = {
    path = "./iam/terraform.tfstate"
  }
}

resource "aws_iot_thing" "the-thing" {
  name = "the-thing"
}

resource "aws_iot_certificate" "cert" {
  active = true
}

resource "aws_iot_thing_principal_attachment" "attach-thing-to-certificate" {
  principal = aws_iot_certificate.cert.arn
  thing     = aws_iot_thing.the-thing.name
}

resource "aws_iot_policy" "device-assume-role" {
  name = "device-assume-role"

  policy = jsonencode({
    "Statement": {
        "Action": "iot:AssumeRoleWithCertificate",
        "Effect": "Allow",
        "Resource": aws_iot_role_alias.role-alias.arn
    },
    "Version": "2012-10-17"
  })
}

resource "aws_iot_policy_attachment" "attach-policy-to-certificate" {
  policy = aws_iot_policy.device-assume-role.name
  target = aws_iot_certificate.cert.arn
}

variable "role_alias_name" {
  default = "iot-device-authorization-role-alias"
}

resource "aws_iot_role_alias" "role-alias" {
  alias    = var.role_alias_name
  role_arn = data.terraform_remote_state.iam-state.outputs.iot_device_authorization_role_arn
}

variable "pem_filename" {
  default = "cert.pem"
}

variable "private_key_filename" {
  default = "cert.private_key"
}

variable "public_key_filename" {
  default = "cert.public_key"
}

variable "root_ca_filename" {
  default = "root.ca"
}

resource "local_file" "pem" {
  filename = var.pem_filename
  sensitive_content = aws_iot_certificate.cert.certificate_pem
}

resource "local_file" "private_key" {
  filename = var.private_key_filename
  sensitive_content = aws_iot_certificate.cert.private_key
}

resource "local_file" "public_key" {
  filename = var.public_key_filename
  sensitive_content = aws_iot_certificate.cert.public_key
}

resource "null_resource" "download_root_ca" {
  provisioner "local-exec" {
    command = "curl -o ${var.root_ca_filename} https://www.amazontrust.com/repository/AmazonRootCA1.pem"
  }
}

output "run_command" {
  description = "Command to run the test application. You'll have to replace the path to the root.ca file."
  value = <<EOT
    java -jar BasicPubSub-1.0-SNAPSHOT-jar-with-dependencies.jar --clientId ${aws_iot_thing.the-thing.name}  --x509rootca ${var.root_ca_filename} \ 
      --x509cert ${var.pem_filename} --x509key ${var.private_key_filename} --endpoint ${data.aws_iot_endpoint.data.endpoint_address} --count 1 -w \ 
      --region ${data.terraform_remote_state.iam-state.outputs.aws_region} --x509 --x509rolealias ${var.role_alias_name} \ 
      --x509endpoint ${data.aws_iot_endpoint.credentials.endpoint_address} --x509thing ${aws_iot_thing.the-thing.name} -m yoyo -t aaa/${aws_iot_thing.the-thing.name}
  EOT
}