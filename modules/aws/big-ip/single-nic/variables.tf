#-------- big-ip/variables.tf --------
variable "name" {}

variable "vpc_id" {}

variable "vpc_cidr" {}
variable "subnet_id" {}
variable "key_name" {}
variable "instance_count" {}

variable "allowed_mgmt_cidrs" {
  type = "list"
}

variable "as3_rpm_url" {
  default = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.10.0/f5-appsvcs-3.10.0-5.noarch.rpm"
}

variable "do_rpm_url" {
  default = "https://github.com/F5Networks/f5-declarative-onboarding/raw/master/dist/f5-declarative-onboarding-1.3.0-4.noarch.rpm"
}

variable "f5_user" {
  default = "admin"
}

variable "f5_instance_type" {
  default = "t2.medium"
}
