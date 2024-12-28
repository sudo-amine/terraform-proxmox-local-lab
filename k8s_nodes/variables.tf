variable "proxmox" {
  description = "Proxmox configuration"
  type = object({
    host              = string
    node              = string
    local_storage     = string
    local_storage_lvm = string
    vault_secret_path = string
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

variable "nodes" {
  description = "Configuration for control plane and worker nodes"
  type = object({
    control_plane = object({
      count          = number
      first_id       = string
      names_prefix   = string
      ip_range_start = number
      disk_size      = string
      cores          = number # Added to configure cores
      memory         = number # Added to configure memory
      user           = string # Matches template_vm.user for consistency
    })
    workers = object({
      count          = number
      first_id       = string
      names_prefix   = string
      ip_range_start = number
      disk_size      = string
      cores          = number # Added to configure cores
      memory         = number # Added to configure memory
      user           = string # Matches template_vm.user for consistency
    })
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

variable "vault_secret_path" {
  description = "Path to the Vault secret containing Proxmox API token"
  type        = string
}

variable "image_name" {
  type        = string
}

variable "image_url" {
  type        = string
}