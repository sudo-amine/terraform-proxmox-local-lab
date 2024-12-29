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


variable "ssh_public_key_file" {
  type = string
}

variable "ssh_private_key_file" {
  type = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub" # Provide a sensible default
}

locals {
  ssh_public_key = file(var.ssh_public_key_path)
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa" # Provide a sensible default
}

locals {
  ssh_private_key = file(var.ssh_private_key_path)
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
