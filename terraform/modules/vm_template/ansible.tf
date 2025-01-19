resource "ansible_playbook" "start_vm" {
  playbook = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/ansible/playbooks/start_template_vm.yml"
  name     = "localhost"
  extra_vars = {
    proxmox_host         = var.proxmox.host
    proxmox_node         = var.proxmox.node
    proxmox_api_user     = var.proxmox.api_user
    proxmox_api_token_id = var.proxmox.api_token_id
    api_token            = var.secret_proxmox_api_token
    ssh_private_key_path = var.vm_ssh.private_key_path
    vault_address        = var.vault.address
    vault_role_id        = var.vault.role_id
    vault_secret_id      = var.vault.secret_id
    status_retries       = 10
    status_delay         = 10
    ssh_wait_timeout     = 300
    ansible_connection   = "local"
    vm_id                = proxmox_vm_qemu.vm_template.vmid
    vm_ip                = regex("[0-9.]+", proxmox_vm_qemu.vm_template.ipconfig0)
  }
  replayable = true
}

resource "ansible_playbook" "install_vm_template" {
  depends_on = [ansible_playbook.start_vm, ansible_host.vm_template]
  playbook   = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/ansible/playbooks/install_vm_template.yml"
  name       = regex("[0-9.]+", proxmox_vm_qemu.vm_template.ipconfig0)
  extra_vars = local.extra_vars
  replayable = true
}


output "temp_inventory_file" {
  value = ansible_playbook.install_vm_template.temp_inventory_file
}

output "test" {
  value = "test"
}
# resource "ansible_playbook" "stop_vm" {
#   depends_on = [ansible_playbook.start_vm]
#   playbook   = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/ansible/playbooks/stop_template_vm.yml"
#   name       = ansible_group.all.name

#   # Pass the necessary variables to the playbook
#   extra_vars = {
#     vm_id              = proxmox_vm_qemu.vm_template.vmid
#     vm_ip              = regex("[0-9.]+", proxmox_vm_qemu.vm_template.ipconfig0)
#     ansible_connection = "local"
#   }
# }


# resource "ansible_playbook" "start_vms" {
#   for_each = tomap({
#     for i, vm in proxmox_vm_qemu.control_plane : vm.name => {
#       name = vm.name
#       ip   = cidrhost(var.network.gateway_subnet, var.nodes.control_plane.ip_range_start + i)
#     }
#   } ++ {
#     for i, vm in proxmox_vm_qemu.worker_nodes : vm.name => {
#       name = vm.name
#       ip   = cidrhost(var.network.gateway_subnet, var.nodes.workers.ip_range_start + i)
#     }
#   })

#   playbook = "/home/sudo-amine/ansible/playbooks/start_template_vm.yml"
#   name     = "localhost"

#   extra_vars = {
#     vm_name = each.value.name
#     vm_ip   = each.value.ip
#   }
# }
