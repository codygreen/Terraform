#-------- compute-ec2/output.tf --------
output "public_ip" {
  value = "${join(", ", aws_instance.nginx.*.public_ip)}"
}

output "private_ip" {
  value = "${join(", ", aws_instance.nginx.*.private_ip)}"
}
