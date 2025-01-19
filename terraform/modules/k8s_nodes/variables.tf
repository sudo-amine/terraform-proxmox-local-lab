variable "network" {
  type = object({
    bridge         = string
    gateway        = string
    subnet         = string
    gateway_subnet = string
  })
}

variable "storage" {
  type = object({
    local = string
    main  = string
  })
}

variable "vm_template" {
  type = object({
    id        = string
    name      = string
    ip        = string
    image_url = string
    disk_size = string
  })
}

variable "proxmox" {
  description = "Configuration for the Proxmox API and node"
  type = object({
    api_user     = string
    api_token_id = string
    host         = string
    node         = string
    api_url      = string
    user         = string
    ssh_key_path = string
  })
}


variable "secret_proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
}

variable "vault" {
  description = "Configuration for the Vault API"
  type = object({
    address = string
    role_id = string
    secret_id = string
  })
}


variable "vm_ssh" {
  description = "Configuration for SSH key paths"
  type = object({
    private_key_path = string
    public_key_path  = string
  })
}

variable "vm_user" {
  description = "The username for the VM"
  type        = string
}
