output "url" {
  value = "https://${var.tfe_subdomain}.${var.tfe_domain}"
}

output "ssh_bastion" {
  value = "ssh -i ${var.key_pair}.pem ubuntu@${aws_eip.eip.public_ip}"
}