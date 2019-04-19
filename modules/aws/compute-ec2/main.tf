#-------- compute/main.tf --------

# Get My Public IP
data "http" "myIP" {
  url = "http://api.ipify.org/"
}

# Find Ubuntu AMI
data "aws_ami" "compute" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name = "name"

    # Ubuntu Bionic 
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_instance_profile" "compute" {
  name = "${var.name}_profile"
  role = "${aws_iam_role.role.name}"
}

resource "aws_iam_role" "role" {
  name = "${var.name}_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_security_group" "compute" {
  name        = "${var.name}_sg"
  vpc_id      = "${var.vpc_id}"
  description = "demo app"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}", "${chomp(data.http.myIP.body)}/32"]
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

resource "aws_instance" "udf" {
  ami   = "${data.aws_ami.compute.id}"
  count = "${var.instance_count}"

  #   associate_public_ip_address = true

  iam_instance_profile   = "${aws_iam_instance_profile.compute.id}"
  instance_type          = "t2.micro"
  key_name               = "${var.ssh_key}"
  vpc_security_group_ids = ["${aws_security_group.compute.id}"]
  subnet_id              = "${var.subnet_id}"
  tags = {
    Terraform  = true
    Name       = "${var.name}_workload-${count.index}"
    ScaleGroup = "lab"
  }
}

# write out host file
data "template_file" "inventory" {
  template = <<EOF
[http]
$${workload_ips}

[http:vars]
ansible_ssh_private_key_file=~/.ssh/$${ssh_key}
host_key_checking=false
ansible_user=ubuntu
EOF

  vars {
    workload_ips = "${join("\n", aws_instance.udf.*.public_ip)}"
    ssh_key      = "${var.ssh_key}"
  }
}

resource "local_file" "save_inventory" {
  depends_on = ["data.template_file.inventory"]
  content    = "${data.template_file.inventory.rendered}"
  filename   = "./inventory"
}

# run ansible playbook
resource "null_resource" "ansible" {
  provisioner "local-exec" {
    command = <<-EOF
    aws ec2 wait instance-status-ok --instance-ids ${element(aws_instance.udf.*.id, 0)}
    ansible-playbook -i ./inventory ./demo_app.yaml
    EOF
  }
}
