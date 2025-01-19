# resource "ansible_host" "control_plane_nodes" {
#   for_each = { for index, vm in proxmox_vm_qemu.control_plane_nodes : index => vm }

#   name = each.value.name

#   variables = {
#     host            = each.value.network[0].ip # Dynamically get the VM's IP
#     user            = var.user
#     ssh_private_key = file(var.ssh.private_key_path)
#     vmid            = each.value.vmid # Get the VM ID dynamically
#   }
# }


# resource "ansible_host" "worker_nodes" {
#   for_each = { for index, vm in proxmox_vm_qemu.worker_nodes : index => vm }

#   name = each.value.name

#   variables = {
#     host            = each.value.network[0].ip # Dynamically get the VM's IP
#     user            = var.user
#     ssh_private_key = file(var.ssh.private_key_path)
#     vmid            = each.value.vmid # Get the VM ID dynamically
#   }
# }

# resource "ansible_host" "vm_template" {
#   name = proxmox_vm_qemu.vm_template.name

#   variables = {
#     host                 = regex("[0-9.]+", proxmox_vm_qemu.vm_template.ipconfig0)
#     user                 = var.vm_user
#     ssh_private_key_file = var.ssh.private_key_path
#     vmid                 = proxmox_vm_qemu.vm_template.vmid
#   }
# }

# # Define control plane group
# resource "ansible_group" "control_plane" {
#   name = "control_plane"

#   children = [for h in ansible_host.control_plane_nodes : h.name]
# }

# # Define worker nodes group
# resource "ansible_group" "workers" {
#   name = "workers"

#   children = [for h in ansible_host.worker_nodes : h.name]
# }

# # Define first control plane node group
# resource "ansible_group" "first_cp_node" {
#   name = "first_cp_node"

#   children = [
#     ansible_host.control_plane_nodes[0].name
#   ]
# }

# # Define other control plane nodes group
# resource "ansible_group" "other_cp_nodes" {
#   name = "other_cp_nodes"

#   children = [for h in ansible_host.control_plane_nodes : h.name if h.index > 0]
# }

# Set global variables for all hosts
resource "ansible_group" "all" {
  name = "all"

  variables = {
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
  }
}

resource "ansible_host" "vm_template" {
  name   = proxmox_vm_qemu.vm_template.name
  groups = ["all"]

  variables = {
    host                 = regex("[0-9.]+", proxmox_vm_qemu.vm_template.ipconfig0)
    user                 = var.vm_user
    ssh_private_key_file = var.vm_ssh.private_key_path
    vmid                 = proxmox_vm_qemu.vm_template.vmid
  }
}


