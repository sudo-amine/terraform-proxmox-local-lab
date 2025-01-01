locals {
  proxmox     = yamldecode(file("${path.root}/../config/proxmox.yml"))["proxmox"]
  template_vm = yamldecode(file("${path.root}/../config/template_vm.yml"))["template_vm"]
  nodes       = yamldecode(file("${path.root}/../config/k8s_nodes.yml"))["nodes"]
  network     = yamldecode(file("${path.root}/../config/network.yml"))["network"]
  ssh         = yamldecode(file("${path.root}/../config/ssh.yml"))["ssh"]
  vault       = yamldecode(file("${path.root}/../config/vault.yml"))["vault"]
}

variable "proxmox" {
  description = "Proxmox configuration"
  type = object({
    host              = string
    node              = string
    api_user          = string
    token_id          = string
    storage_local     = string
    storage_main      = string
  })
  default = local.proxmox
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
  default = local.template_vm
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
  default = local.nodes
}

variable "network" {
  description = "Network configuration"
  type = object({
    bridge         = string
    gateway        = string
    subnet         = string
    gateway_subnet = string
  })
  default = local.network
}

variable "ssh" {
  type = object({
    public_key_path  = string
    private_key_path = string
  })
  default = local.ssh
}

variable "vault" {
  type = object({
    secret_path = string
  })
  default = local.vault
}
