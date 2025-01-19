locals {


  # Proxmox Configuration
  proxmox = {
    api_user     = var.proxmox_api_user
    api_token_id = var.proxmox_api_token_id
    host         = var.proxmox_host
    node         = var.proxmox_node
    api_url      = "https://${var.proxmox_host}:${var.proxmox_api_url_port}/${var.proxmox_api_url_path}"
    ssh_key_path = var.proxmox_node_ssh_public_key_path
    user         = var.proxmox_node_user
  }

  # Vault Configuration
  vault = {
    address   = var.vault_address
    role_id   = var.vault_role_id
    secret_id = var.vault_secret_id
  }

  # SSH Configuration
  vm_ssh = {
    private_key_path = var.vm_ssh_private_key_path
    public_key_path  = var.vm_ssh_public_key_path
  }

  vm_user = var.vm_user

  control_plane = var.control_plane
  workers       = var.workers

  pod_network_cidr       = var.pod_network_cidr
  control_plane_endpoint = var.control_plane_endpoint

}
