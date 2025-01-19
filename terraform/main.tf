module "vm_template" {
  source = "./modules/vm_template"

  vm_template              = var.vm_template
  storage                  = var.storage
  network                  = var.network
  proxmox                  = local.proxmox
  vm_ssh                   = local.vm_ssh
  secret_proxmox_api_token = nonsensitive(data.vault_kv_secret_v2.proxmox_token.data.token)
  vm_user                  = var.vm_user
  vault                    = local.vault
}


# module "ansible" {
#   source = "./modules/ansible"

#   vm_template            = module.vm_template.vm_outputs
#   control_plane          = var.control_plane
#   workers                = var.workers
#   network                = var.network
#   storage                = var.storage
#   user                   = var.user
#   proxmox                = local.proxmox
#   ssh_private_key_path   = local.ssh.private_key_path
#   control_plane_endpoint = local.control_plane_endpoint
#   pod_network_cidr       = local.pod_network_cidr
# }
