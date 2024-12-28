proxmox = {
  host              = "proxmox.local"
  node              = "proxmox"
  local_storage     = "local"
  local_storage_lvm = "local-lvm-2"
  vault_secret_path = "proxmox"
}

nodes = {
  control_plane = {
    count          = 3
    first_id       = "100"
    names_prefix   = "control-plane-"
    ip_range_start = "130"
    disk_size      = "20G" # Matches the disk size in the resource
    cores          = 1
    memory         = 2048
    user           = "sudo-amine"
  }
  workers = {
    count          = 3
    first_id       = "120"
    names_prefix   = "worker-"
    ip_range_start = "150" # Starts with this IP
    disk_size      = "50G" # Matches the disk size in the resource
    cores          = 4
    memory         = 3072
    user           = "sudo-amine"
  }
}

network = {
  bridge         = "vmbr0"
  gateway        = "192.168.1.1"
  subnet         = "24"
  gateway_subnet = "192.168.1.0/24"
}

storage = {
  local = "local"
  main  = "local-lvm-2"
}

vault_secret_path = "proxmox"

