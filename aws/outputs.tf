#--------root/outputs.tf--------
output "BIG-IP IPs" {
  value = "${module.big-ip.public_ip}"
}

output "BIG-IP Password" {
    value = "${module.big-ip.password}"
}