#-------- big-ip/main.tf --------
# Find F5 AMI
data "aws_ami" "f5_ami" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["F5 Networks BIGIP-14.* PAYG - Good 25Mbps*"]
  }
}

resource "random_string" "password" {
  length           = 16
  special          = true
  override_special = "@"
}

# build out EC2 instances 
# add key pair
resource "aws_key_pair" "f5_auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Deploy BIG-IP

data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.tpl")}"

  vars {
    admin_username = "${var.f5_user}"
    admin_password = "${random_string.password.result}"
    do_rpm_url     = "${var.do_rpm_url}"
    as3_rpm_url    = "${var.as3_rpm_url}"
  }
}

resource "aws_instance" "f5_bigip" {
  count         = "${var.f5_count}"
  instance_type = "${var.f5_instance_type}"
  ami           = "${data.aws_ami.f5_ami.id}"

  tags {
    Name = "f5_demo_bigip-${count.index + 1}"
  }

  key_name               = "${aws_key_pair.f5_auth.id}"
  vpc_security_group_ids = ["${var.security_group}"]
  subnet_id              = "${element(var.subnets, count.index)}"
  iam_instance_profile   = "${var.f5_profile}"

  root_block_device {
    delete_on_termination = true
  }

  user_data = "${data.template_file.user_data.rendered}"
}

# Onboard BIG-IP
data "template_file" "do_data" {
  template = "${file("${path.module}/single_nic_onboard.tpl")}"

  vars {}
}

resource "null_resource" "onboard" {
  provisioner "local-exec" {
    command = <<-EOF
    aws ec2 wait instance-status-ok --instance-ids ${aws_instance.f5_bigip.id}
    until $(curl -k -u ${var.f5_user}:${random_string.password.result} -o /dev/null --silent --fail https://${aws_instance.f5_bigip.public_ip}:8443/mgmt/shared/declarative-onboarding/example);do sleep 10;done
    curl -k -X POST https://${aws_instance.f5_bigip.public_ip}:8443/mgmt/shared/declarative-onboarding \
            --retry 60 \
            --retry-connrefused \
            --retry-delay 120 \
            -H "Content-Type: application/json" \
            -u ${var.f5_user}:${random_string.password.result} \
            -d '${data.template_file.do_data.rendered} '
    EOF
  }
}

# Define HTTP application
data "template_file" "http_app" {
  count    = "${1 - var.app_type_https}"
  template = "${file("${path.module}/http_app.tpl")}"

  vars {
    public_ip = "${aws_instance.f5_bigip.private_ip}"
  }
}

# Deploy HTTP Application
resource "null_resource" "as3" {
  count = "${1 - var.app_type_https}"

  provisioner "local-exec" {
    command = <<-EOF
    aws ec2 wait instance-status-ok --instance-ids ${aws_instance.f5_bigip.id}
    until $(curl -k -u ${var.f5_user}:${random_string.password.result} -o /dev/null --silent --fail https://${aws_instance.f5_bigip.public_ip}:8443/mgmt/shared/appsvcs/info);do sleep 10;done
    curl -k -X POST https://${aws_instance.f5_bigip.public_ip}:8443/mgmt/shared/appsvcs/declare \
            --retry 60 \
            --retry-connrefused \
            --retry-delay 120 \
            -H "Content-Type: application/json" \
            -u ${var.f5_user}:${random_string.password.result} \
            -d '${data.template_file.http_app.rendered} '
    EOF
  }
}

# Get SSL Cert for HTTPS application
provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  email_address   = "${var.email_address}"
}

resource "acme_certificate" "certificate" {
  account_key_pem = "${acme_registration.reg.account_key_pem}"
  common_name     = "${var.app_name}.${var.dns_domain_external}"

  dns_challenge {
    provider = "route53"
  }
}

# Define HTTPS application
data "template_file" "https_app" {
  count    = "${var.app_type_https}"
  template = "${file("${path.module}/https_app.tpl")}"

  vars {
    public_ip = "${aws_instance.f5_bigip.private_ip}"

    cert = "${jsonencode(acme_certificate.certificate.certificate_pem)}"
    key  = "${jsonencode(acme_certificate.certificate.private_key_pem)}"
    ca   = "${jsonencode(acme_certificate.certificate.issuer_pem)}"
  }
}

# Deploy HTTPS Application
resource "null_resource" "as3_https" {
  count = "${var.app_type_https}"

  provisioner "local-exec" {
    command = <<-EOF
    aws ec2 wait instance-status-ok --instance-ids ${aws_instance.f5_bigip.id}
    until $(curl -k -u ${var.f5_user}:${random_string.password.result} -o /dev/null --silent --fail https://${aws_instance.f5_bigip.public_ip}:8443/mgmt/shared/appsvcs/info);do sleep 10;done
    curl -k -X POST https://${aws_instance.f5_bigip.public_ip}:8443/mgmt/shared/appsvcs/declare \
            --retry 60 \
            --retry-connrefused \
            --retry-delay 120 \
            -H "Content-Type: application/json" \
            -u ${var.f5_user}:${random_string.password.result} \
            -d '${data.template_file.https_app.rendered} '
    EOF
  }
}

# Configure DNS
data "aws_route53_zone" "f5demos-external" {
  name = "${var.dns_domain_external}"
}

resource "aws_route53_record" "f5demos-external-app" {
  zone_id = "${data.aws_route53_zone.f5demos-external.zone_id}"
  name    = "${var.app_name}.${var.dns_domain_external}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_instance.f5_bigip.public_ip}"]
}
