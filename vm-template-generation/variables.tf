variable "proxmox_host" {
  description = "Proxmox server IP or hostname"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "local_storage_pool" {
  type = string
}

variable "local_storage_pool_lvm" {
  type = string
}

variable "template_vm_id" {
  type = string
}

variable "template_vm_name" {
  type = string
}

variable "template_vm_disk_size" {
  type = string
}

variable "template_vm_ip" {
  type = string
}

variable "template_user" {
  type = string
}

variable "cloned_vm_id" {
  type = string
}

variable "cloned_vm_name" {
  type = string
}

variable "cloned_vm_disk_size" {
  type = string
}

variable "cloned_vm_ip" {
  type = string
}

variable "cloned_user" {
  type = string
}

variable "vault_secret_path" {
  description = "Path to the Vault secret containing Proxmox API token"
  type        = string
}

variable "network_bridge" {
  description = "The network bridge to use"
  type        = string
}

variable "network_gateway" {
  description = "The network gateway"
  type        = string
  default     = "192.168.1.1"
}

variable "network_subnet" {
  description = "The network gateway"
  type        = string
  default     = "24"
}

locals {
  ssh_public_key = file("~/.ssh/id_rsa.pub") # Read the SSH public key from the file
}
