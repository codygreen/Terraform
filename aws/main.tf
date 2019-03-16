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
        cidr_block = "0.0.0/0"
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

# Create Security Groups

