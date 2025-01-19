terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }

    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
  }
}


