# module "vm_template" {
#   source = "./modules/vm_template"

#   vm_template              = var.vm_template
#   storage                  = var.storage
#   network                  = var.network
#   proxmox                  = local.proxmox
#   vm_ssh                   = local.vm_ssh
#   secret_proxmox_api_token = nonsensitive(data.vault_kv_secret_v2.proxmox_token.data.token)
#   vm_user                  = var.vm_user
#   vault                    = local.vault
# }
