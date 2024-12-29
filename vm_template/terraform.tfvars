proxmox = {
  host              = "proxmox.local"
  node              = "proxmox"
  local_storage     = "local"
  local_storage_lvm = "local-lvm-2"
  vault_secret_path = "proxmox"
  api_user          = "terraform-prov@pve"
  token_id          = "tid"
}

template_vm = {
  id        = "9001"
  name      = "vm-template"
  disk_size = "8G"
  ip        = "192.168.1.101"
  user      = "sudo-amine"
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

image_name = "jammy-server-cloudimg-amd64.img"
image_url  = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
