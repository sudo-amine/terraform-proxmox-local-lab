data "vault_kv_secret_v2" "proxmox_token" {
  mount = "secret"
  name  = "proxmox"
}

locals {
  secret_proxmox_api_token = data.vault_kv_secret_v2.proxmox_token.data.token
}
