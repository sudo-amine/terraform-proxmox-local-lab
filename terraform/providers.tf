terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "vault" {
  address = var.vault_address
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://${var.proxmox_host}:${var.proxmox_api_url_port}/${var.proxmox_api_url_path}"
  pm_api_token_id     = "${var.proxmox_api_user}!${var.proxmox_api_token_id}"
  pm_api_token_secret = local.secret_proxmox_api_token
  pm_tls_insecure     = false
}

