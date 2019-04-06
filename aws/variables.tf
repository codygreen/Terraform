variable "f5_count" {}
variable "aws_region" {}
variable "vpc_cidr" {}

variable "public_cidrs" {
  type = "list"
}

variable "key_name" {}
variable "public_key_path" {}
variable "private_key_path" {}
variable "f5_instance_type" {}
variable "f5_user" {}
variable "do_rpm_url" {}
variable "as3_rpm_url" {}
variable "dns_domain_external" {}
variable "dns_domain_internal" {}

variable "app_name" {}

variable "app_type_https" {
  description = "determine if we are deploying an http or https application"
}

variable "email_address" {}
