#-------- big-ip/main.tf --------
# Find F5 AMI
data "aws_ami" "f5_ami" {
  most_recent = true
  owners = ["679593333241"]
  
  filter {
    name   = "name"
    values = ["F5 Networks BIGIP-14.* PAYG - Good 25Mbps*"]
  }
}

resource "random_string" "password" {
  length = 16
  special = true
  override_special = "/@\""
}

# build out EC2 instances 
# add key pair
resource "aws_key_pair" "f5_auth" {
    key_name = "${var.key_name}"
    public_key = "${file(var.public_key_path)}"
}

# Deploy BIG-IP

data "template_file" "user_data" {
    template = "${file("${path.module}/user_data.tpl")}"

    vars {
        admin_username = "${var.f5_user}"
        admin_password = "${random_string.password.result}"
        do_rpm_url = "${var.do_rpm_url}"
        as3_rpm_url = "${var.as3_rpm_url}"
    }
}
resource "aws_instance" "f5_bigip" {
    count = "${var.f5_count}"
    instance_type = "${var.f5_instance_type}"
    ami = "${data.aws_ami.f5_ami.id}"

    tags {
        Name = "f5_demo_bigip-${count.index + 1}"
    }

    key_name = "${aws_key_pair.f5_auth.id}"
    vpc_security_group_ids = ["${var.security_group}"]
    subnet_id = "${element(var.subnets, count.index)}"
    iam_instance_profile = "${var.f5_profile}"
    root_block_device { 
        delete_on_termination = true 
    }

    user_data = "${data.template_file.user_data.rendered}"
}
