terraform {
  backend "s3" {
    bucket = "cody-terraform"
    key    = "f5_demo/terraform.tfstate"
    region = "us-east-2"
  }
}

provider "aws" {
  region = "${var.aws_region}"
}

# Deploy Network Module
module "networking" {
  source       = "./networking"
  vpc_cidr     = "${var.vpc_cidr}"
  f5_count     = "${var.f5_count}"
  public_cidrs = "${var.public_cidrs}"
}

# Deploy IAM Module
# IAM is not needed at this time, commenting out so I can proceed with UDF lab
# module "iam" {
#   source = "./iam"
# }

# Deploy Compute Module
module "compute" {
  source              = "./compute"
  security_group      = "${module.networking.security_group}"
  subnet              = "${module.networking.public_subnets}"
  vpc                 = "${module.networking.vpc}"
  dns_domain_internal = "${var.dns_domain_internal}"
  app_name            = "${var.app_name}"
}

# Deploy BIG-IP Module
module "big-ip" {
  source           = "./big-ip"
  as3_rpm_url      = "${var.as3_rpm_url}"
  do_rpm_url       = "${var.do_rpm_url}"
  f5_count         = "${var.f5_count}"
  f5_user          = "${var.f5_user}"
  f5_instance_type = "${var.f5_instance_type}"
  key_name         = "${var.key_name}"
  public_key_path  = "${var.public_key_path}"
  subnets          = "${module.networking.public_subnets}"

  # f5_profile          = "${module.iam.f5_profile}"
  security_group      = "${module.networking.security_group}"
  app_name            = "${var.app_name}"
  dns_domain_external = "${var.dns_domain_external}"
  dns_domain_internal = "${var.dns_domain_internal}"
  app_type_https      = "${var.app_type_https}"
  email_address       = "${var.email_address}"
}
