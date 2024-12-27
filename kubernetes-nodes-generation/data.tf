data "vault_kv_secret_v2" "proxmox_token" {
  name  = var.vault_secret_path
  mount = "secret"
}