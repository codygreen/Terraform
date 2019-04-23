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

data "aws_iam_policy_document" "assume_role_doc" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    # principals = {
    #   type        = "Service"
    #   identifiers = ["ec2.amazonaws.com"]
    # }

    effect = "Allow"
    sid = ""
  }
}

data "aws_iam_policy_document" "serviceDiscovery" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeAddresses",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeNetworkInterfaceAttribute",
      "ec2:DescribeRouteTables",
      "ec2:ReplaceRoute",
      "ec2:assignprivateipaddresses",
      "sts:AssumeRole",
    ]

    effect = "Allow"

    sid = ""
  }
}

resource "aws_iam_policy" "bigip" {
  name   = "${var.name}_bigip"
  path   = "/"
  policy = "${data.aws_iam_policy_document.assume_role_doc.json}"
}

resource "aws_iam_role" "bigip" {
  name               = "${var.name}_assume_role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_doc.json}"
}

resource "aws_iam_role_policy_attachment" "bigip" {
  role       = "${aws_iam_role.bigip.name}"
  policy_arn = "${aws_iam_policy.bigip.arn}"
}

resource "aws_iam_instance_profile" "f5_profile" {
  name = "${var.name}_f5_profile"
  role = "${aws_iam_role.bigip.name}"
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

resource "aws_security_group" "big-ip" {
  name        = "${var.name}_sg"
  vpc_id      = "${var.vpc_id}"
  description = "${var.name}_sg"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}", "${join(",", var.allowed_mgmt_cidrs)}"]
  }

  # MGMT
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}", "${join(",", var.allowed_mgmt_cidrs)}"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "compute"
  }
}

resource "aws_instance" "f5_bigip" {
  count         = "${var.instance_count}"
  instance_type = "${var.f5_instance_type}"
  ami           = "${data.aws_ami.f5_ami.id}"

  tags {
    Name = "f5_bigip-${var.name}-${count.index + 1}"
  }

  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.big-ip.id}"]
  subnet_id              = "${var.subnet_id}"

  root_block_device {
    delete_on_termination = true
  }

  iam_instance_profile = "${aws_iam_instance_profile.f5_profile.name}"
  user_data            = "${data.template_file.user_data.rendered}"
}
