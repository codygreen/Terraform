provider "aws" {
    region  = "${var.aws_region}"
}

# create required IAM policy and role
data "aws_iam_policy_document" "assume_role_doc" {
    statement {
        actions = [
            "sts:AssumeRole"
        ]

        principals = {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }

        effect = "Allow"

        sid = ""
    }
}

data "aws_iam_policy_document" "f5_ha_policy_doc" {
    statement {
        effect = "Allow"

        actions = [
            "ec2:describeinstancestatus",
            "ec2:describenetworkinterfaces",
            "ec2:assignprivateipaddresses"
        ]

        resources =  [
            "*"
        ]
    }
}

resource "aws_iam_policy" "f5_ha_policy" {
    name = "f5_ha_policy"
    path = "/"
    policy = "${data.aws_iam_policy_document.f5_ha_policy_doc.json}"
}

resource "aws_iam_role" "f5_ha" {
    name = "f5_ha"
    assume_role_policy = "${data.aws_iam_policy_document.assume_role_doc.json}"
}

resource "aws_iam_role_policy_attachment" "f5_ha_attach" {
    role = "${aws_iam_role.f5_ha.name}"
    policy_arn = "${aws_iam_policy.f5_ha_policy.arn}"
}

resource "aws_iam_instance_profile" "f5_profile" {
    name = "f5_profile"
    role = "${aws_iam_role.f5_ha.name}"
}

# Create an AWS VPC
resource "aws_vpc" "f5_demo_vpc" {
    cidr_block              = "${var.vpc_cidr}"
    enable_dns_hostnames    = true
    enable_dns_support      = true


    tags {
        Name = "f5_demo_vpc"
    }
}

# Create subnets
data "aws_availability_zones" "available" {}

resource "aws_subnet" "f5_mgmt1_subnet" {
    vpc_id = "${aws_vpc.f5_demo_vpc.id}"
    cidr_block = "${var.cidrs["mgmt1"]}"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[0]}"

    tags {
        Name = "f5_mgmt1"
    }
}
resource "aws_subnet" "f5_mgmt2_subnet" {
    vpc_id = "${aws_vpc.f5_demo_vpc.id}"
    cidr_block = "${var.cidrs["mgmt2"]}"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[1]}"

    tags {
        Name = "f5_mgmt2"
    }
}
resource "aws_subnet" "f5_public1_subnet" {
    vpc_id = "${aws_vpc.f5_demo_vpc.id}"
    cidr_block = "${var.cidrs["public1"]}"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[0]}"

    tags {
        Name = "f5_public1"
    }
}
resource "aws_subnet" "f5_public2_subnet" {
    vpc_id = "${aws_vpc.f5_demo_vpc.id}"
    cidr_block = "${var.cidrs["public2"]}"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[1]}"

    tags {
        Name = "f5_public2"
    }
}

# Create Internet Gateway
resource "aws_internet_gateway" "f5_internet_gateway" {
    vpc_id = "${aws_vpc.f5_demo_vpc.id}"
    tags {
        Name = "f5_igw"
    }
}

# Create Routes
resource "aws_route_table" "f5_public_rt" {
    vpc_id = "${aws_vpc.f5_demo_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.f5_internet_gateway.id}"
    }

    tags {
        Name = "f5_public"
    }
}

resource "aws_default_route_table" "f5_private_rt" {
    default_route_table_id = "${aws_vpc.f5_demo_vpc.default_route_table_id}"

    tags {
        Name = "f5_private"
    }
}

resource "aws_route_table_association" "f5_mgmt1_assoc" {
    subnet_id = "${aws_subnet.f5_mgmt1_subnet.id}"
    route_table_id = "${aws_route_table.f5_public_rt.id}"
}

resource "aws_route_table_association" "f5_mgmt2_assoc" {
    subnet_id = "${aws_subnet.f5_mgmt2_subnet.id}"
    route_table_id = "${aws_route_table.f5_public_rt.id}"
}

resource "aws_route_table_association" "f5_public1_assoc" {
    subnet_id = "${aws_subnet.f5_public1_subnet.id}"
    route_table_id = "${aws_route_table.f5_public_rt.id}"
}

resource "aws_route_table_association" "f5_public2_assoc" {
    subnet_id = "${aws_subnet.f5_public2_subnet.id}"
    route_table_id = "${aws_route_table.f5_public_rt.id}"
}

# Get public IP address
data "http" "myIP" {
    url = "http://ipv4.icanhazip.com"
}

# Create Security Groups
resource "aws_security_group" "f5_mgmt_sg" {
    name = "f5_mgmt_sg"
    description = "F5 BIG-IP Management Security Group"
    vpc_id = "${aws_vpc.f5_demo_vpc.id}"

    # MGMT UI
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.myIP.body)}/32"]
    }

    # SSH
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.myIP.body)}/32"]
    }

    # iQuery
    ingress {
        from_port = 4353
        to_port = 4353
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }

    # mcpd
    ingress {
        from_port = 6699
        to_port = 6699
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }

    # failover
    ingress {
        from_port = 1026
        to_port = 1026
        protocol = "udp"
        cidr_blocks = ["10.0.0.0/16"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "f5_public_sg" {
    name = "f5_public_sg"
    description = "F5 BIG-IP Public Security Group"
    vpc_id = "${aws_vpc.f5_demo_vpc.id}"

    # HTTP
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTPS
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# build out EC2 instances 
# add key pair
resource "aws_key_pair" "f5_auth" {
    key_name = "${var.key_name}"
    public_key = "${file(var.public_key_path)}"
}

# create network interface for public subnet
resource "aws_network_interface" "mgmt1" {
    subnet_id = "${aws_subnet.f5_mgmt1_subnet.id}"
    security_groups = ["${aws_security_group.f5_mgmt_sg.id}"]
}
resource "aws_network_interface" "public1" {
    subnet_id = "${aws_subnet.f5_public1_subnet.id}"
    security_groups = ["${aws_security_group.f5_public_sg.id}"]
}

# Deploy BIG-IP
resource "aws_instance" "f5_bigip_01" {
    instance_type = "${var.f5_instance_type}"
    ami = "${var.f5_ami}"

    tags {
        Name = "F5_BIGIP_01"
    }

    key_name = "${aws_key_pair.f5_auth.id}"
    iam_instance_profile = "${aws_iam_instance_profile.f5_profile.id}"
    network_interface = {
        device_index = 0
        network_interface_id = "${aws_network_interface.mgmt1.id}"
    }
    network_interface = {
        device_index = 1
        network_interface_id = "${aws_network_interface.public1.id}"
    }

    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = "admin"
            private_key = "${file(var.private_key_path)}"
        }
        inline = [
            "modify auth user ${var.f5_user} password ${var.f5_password}"
        ]
    }
}

# Assign Elastic IPs
resource "aws_eip" "mgmt1" {
    vpc = true
    network_interface = "${aws_network_interface.mgmt1.id}"
}

resource "aws_eip" "public1" {
    vpc = true
    network_interface = "${aws_network_interface.public1.id}"
}

