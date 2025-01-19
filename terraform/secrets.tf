data "vault_kv_secret_v2" "proxmox_token" {
  mount = "secret"
  name = "proxmox"
}
