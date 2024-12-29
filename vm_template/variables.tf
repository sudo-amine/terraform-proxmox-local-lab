variable "proxmox" {
  description = "Proxmox configuration"
  type = object({
    host              = string
    node              = string
    local_storage     = string
    local_storage_lvm = string
    vault_secret_path = string
    api_user          = string
    token_id          = string
  })
}

variable "template_vm" {
  description = "Template VM configuration"
  type = object({
    id        = string
    name      = string
    disk_size = string
    ip        = string
    user      = string
  })
}

variable "storage" {
  description = "Storage configuration"
  type = object({
    local = string
    main  = string
  })
}

variable "network" {
  description = "Network configuration"
  type = object({
    bridge         = string
    gateway        = string
    subnet         = string
    gateway_subnet = string
  })
}

locals {
  ssh_public_key = file("~/.ssh/id_rsa.pub") # Read the SSH public key from the file
}

locals {
  ssh_private_key = file("~/.ssh/id_rsa") # Read the SSH public key from the file
}

variable "ssh_public_key_file" {
  type = string
}

variable "ssh_private_key_file" {
  type = string
}

variable "vault_secret_path" {
  description = "Path to the Vault secret containing Proxmox API token"
  type        = string
}

variable "image_name" {
  type = string
}

variable "image_url" {
  type = string
}
