resource "proxmox_vm_qemu" "vm_template" {
  depends_on = [proxmox_storage_iso.upload_image]

  name        = var.vm_template.name
  vmid        = var.vm_template.id
  cores       = 2
  memory      = 2048
  scsihw      = "virtio-scsi-pci"
  target_node = var.proxmox.node
  boot        = "order=scsi0;net0"
  vm_state    = "stopped"
  ciuser      = var.vm_user
  ipconfig0   = "ip=${var.vm_template.ip}/${var.network.subnet},gw=${var.network.gateway}"
  sshkeys     = file(var.vm_ssh.public_key_path)
  agent       = 1

  # Add a Cloud-Init Disk
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.storage.main
  }

  # Network Configuration
  network {
    model  = "virtio"
    bridge = var.network.bridge
    id     = 0
  }

  serial {
    id   = 0
    type = "socket"
  }

  lifecycle {
    # ignore_changes = [
    #   disk
    # ]
    ignore_changes = all
  }
}
