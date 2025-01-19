terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "vault" {
  address = local.vault.address
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = local.vault.role_id
      secret_id = local.vault.secret_id
    }
  }
}

provider "proxmox" {
  pm_api_url          = local.proxmox.api_url
  pm_api_token_id     = "${local.proxmox.api_user}!${local.proxmox.api_token_id}"
  pm_api_token_secret = data.vault_kv_secret_v2.proxmox_token.data.token
  pm_tls_insecure     = false
}

