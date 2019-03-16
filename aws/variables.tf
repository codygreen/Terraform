variable "aws_region" {}
variable "vpc_cidr" {}
variable "cidrs" {
  type = "map"
}
variable "key_name" {}
variable "public_key_path" {}
variable "f5_instance_type" {}
variable "f5_ami" {}
variable "do_rpm_url" {}