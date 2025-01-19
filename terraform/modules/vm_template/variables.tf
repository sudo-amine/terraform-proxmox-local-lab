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
    id         = string
    name       = string
    disk_size  = string
    ip         = string
    image_name = string
    image_url  = string
  })
}


variable "proxmox_api_token" {
  description = "Proxmox API token"
  type = string
  sensitive = true
}


variable "proxmox_api_user" {
  description = "Proxmox API user"
  type = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type = string
}

variable "proxmox_host" {
  description = "Proxmox Host"
  type = string
}

variable "proxmox_node" {
  description = "Proxmox Node"
  type = string
}

variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type = string
}