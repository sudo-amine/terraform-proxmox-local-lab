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