module "vm_template" {
  source      = "./modules/vm_template"

  vm_template = var.vm_template
  storage     = var.storage
  network     = var.network
  
  proxmox_api_user = var.proxmox_api_user
  proxmox_api_token_id = var.proxmox_api_token_id
  proxmox_api_url = var.proxmox_api_url
  proxmox_node = var.proxmox_node
  proxmox_host = var.proxmox_host

  proxmox_api_token = data.vault_generic_secret.proxmox_token.data.token

}
