terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "vault" {
  address = var.vault_config.address
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_config.role_id
      secret_id = var.vault_config.secret_id
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = "${var.proxmox_api_user}!${var.proxmox_api_token_id}"
  pm_api_token_secret = data.vault_generic_secret.proxmox_token.data.token
  pm_tls_insecure     = false
}

