locals {
  user                 = var.vm_user
  token_id             = var.proxmox.api_token_id
  local_storage        = var.storage.local
  main_storage         = var.storage.main
  node                 = var.proxmox.node
  host                 = var.proxmox.host
  api_user             = var.proxmox.api_user
  api_url              = var.proxmox.api_url
  image_url            = var.vm_template.image_url
  secret               = var.secret_proxmox_api_token
  image_name           = basename(var.vm_template.image_url)
  ssh_private_key_path = var.vm_ssh.private_key_path
  vmid                 = var.vm_template.id
  name                 = var.vm_template.name
  ip                   = var.vm_template.ip
  disk_size            = var.vm_template.disk_size

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
  }
}
