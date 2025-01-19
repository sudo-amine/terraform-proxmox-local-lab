# Proxmox Variables
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

variable "proxmox_node_user" {
  description = "The Proxmox user"
  type        = string
}

variable "proxmox_node_ssh_public_key_path" {
  description = "The file path to the public SSH key for the Proxmox node"
  type        = string
}

variable "proxmox_api_url_port" {
  description = "The full API URL for Proxmox"
  type        = string
}

variable "proxmox_api_url_path" {
  description = "The full API URL for Proxmox"
  type        = string
}

# Vault Variables
variable "vault_address" {
  description = "The Vault server address"
  type        = string
}

variable "vault_role_id" {
  description = "The role ID for Vault AppRole authentication"
  type        = string
}

variable "vault_secret_id" {
  description = "The secret ID for Vault AppRole authentication"
  type        = string
}

# SSH Variables
variable "vm_ssh_private_key_path" {
  description = "The file path to the private SSH key for the vms"
  type        = string
}

variable "vm_ssh_public_key_path" {
  description = "The file path to the public SSH key for the vms"
  type        = string
}

variable "vm_user" {
  description = "The user for the k8s nodes"
  type        = string
}


variable "pod_network_cidr" {
  description = "The CIDR block for the pod network"
  type        = string
}

variable "control_plane_endpoint" {
  description = "The endpoint for the control plane"
  type        = string
}
