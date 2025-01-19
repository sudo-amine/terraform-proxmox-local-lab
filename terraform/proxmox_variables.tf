variable "control_plane" {
  type = object({
    count          = number
    first_id       = string
    names_prefix   = string
    ip_range_start = number
    disk_size      = string
    cores          = number
    memory         = number
  })
}

variable "workers" {
  type = object({
    count          = number
    first_id       = string
    names_prefix   = string
    ip_range_start = number
    disk_size      = string
    cores          = number
    memory         = number
  })
}

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

variable "proxmox_api_user" {
  description = "The user for the Proxmox API"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "The token ID for Proxmox API authentication"
  type        = string
}

variable "proxmox_host" {
  description = "The Proxmox host name or IP address"
  type        = string
}

variable "proxmox_node" {
  description = "The Proxmox node where resources will be deployed"
  type        = string
}

variable "proxmox_api_url" {
  description = "The full API URL for Proxmox"
  type        = string
}