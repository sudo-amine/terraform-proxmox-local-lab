output "ansible_inventory" {
  value = <<EOT
[vm]
${var.template_vm.ip} ansible_ssh_user=${var.template_vm.user} ansible_ssh_private_key_file=${local.ssh_public_key}
EOT
}
