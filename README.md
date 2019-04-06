# Terraform
Terraform example to deploy a BIG-IP single NIC instance in AWS.

# Environment
This Terraform example will deploy a new VPC, subnet, route tables, associated security groups, a demo app running in ECS and a single NIC BIG-IP instance.  The framework is there to deploy multiple BIG-IPs but I have not finished building out a unique ECS instance in each AZ.

## HTTP ot HTTPS
You can deploy either an HTTP or HTTPS application.  To deploy an HTTP based application set the app_type_https variable to 0.  To deploy an HTTPS based application set the app_type_https variable to 1.

When app_type_https = 1 Terraform will register an SSL certificate with Let's Encrypt so all requests to provide a production like demo.

# Setup
This example uses the terraform.tfvars file to store common variables - this is a common format in Terraform when leveraging modules.  An example terraform.tfvars file has been included but it needs to be renamed (remove the .example from the end).  

This example also leverages the AWS CLI tool, so you'll need to ensure that the AWS CLI tool is setup and configured properly: [https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)

Next, you'll need to perform a terraform init, a terraform plan and finally a terraform apply.

# 
