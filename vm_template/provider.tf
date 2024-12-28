terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://${var.proxmox.host}:8006/api2/json"
  pm_api_token_id     = "terraform-prov@pve!tid"
  pm_api_token_secret = data.vault_kv_secret_v2.proxmox_token.data.token
  pm_tls_insecure     = false # Set to true only for testing in insecure environments
}

provider "vault" {}
