proxmox = {
  host              = "proxmox.local"
  node              = "proxmox"
  local_storage     = "local"
  local_storage_lvm = "local-lvm-2"
  vault_secret_path = "proxmox"
  api_user          = "terraform-prov@pve"
  token_id          = "tid"
}
nodes = {
  control_plane = {
    count          = 2
    first_id       = "100"
    names_prefix   = "control-plane-"
    ip_range_start = "130"
    disk_size      = "20G" # Matches the disk size in the resource
    cores          = 1
    memory         = 2048
    user           = "sudo-amine"
  }
  workers = {
    count          = 2
    first_id       = "120"
    names_prefix   = "worker-"
    ip_range_start = "150" # Starts with this IP
    disk_size      = "50G" # Matches the disk size in the resource
    cores          = 4
    memory         = 3072
    user           = "sudo-amine"
  }
}

template_vm = {
  id        = "9001"
  name      = "vm-template"
  disk_size = "8G"
  ip        = "192.168.1.101"
  user      = "sudo-amine"
}

vault_secret_path = "proxmox"

