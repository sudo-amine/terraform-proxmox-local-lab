resource "proxmox_vm_qemu" "control_plane" {
  depends_on  = [null_resource.convert_to_template]
  count       = var.control_plane.count
  vmid        = var.control_plane.first_id + count.index + 1
  name        = "${var.control_plane.names_prefix}${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.vm_template.name
  cores       = var.control_plane.cores
  memory      = var.control_plane.memory
  agent       = 1
  scsihw      = "virtio-scsi-pci"
  full_clone  = true

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.storage.main
  }

  disk {
    size    = var.control_plane.disk_size
    storage = var.storage.main
    type    = "disk"
    slot    = "scsi0"
    format  = "raw"
  }

  network {
    model  = "virtio"
    bridge = var.network.bridge
    id     = 0
  }

  ipconfig0 = "ip=${cidrhost(var.network.gateway_subnet, var.control_plane.ip_range_start + count.index)}/${var.network.subnet},gw=${var.network.gateway}"
  sshkeys   = file(var.vm_ssh_public_key_path)
  ciuser    = var.vm_user
}

resource "proxmox_vm_qemu" "worker_nodes" {
  depends_on  = [null_resource.convert_to_template]
  count       = var.worker_nodes.count
  vmid        = var.worker_nodes.first_id + count.index + 1
  name        = "${var.worker_nodes.names_prefix}${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.vm_template.name
  cores       = var.worker_nodes.cores
  memory      = var.worker_nodes.memory
  agent       = 1
  scsihw      = "virtio-scsi-pci"
  full_clone  = true

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.storage.main
  }

  disk {
    size    = var.worker_nodes.disk_size
    storage = var.storage.main
    type    = "disk"
    slot    = "scsi0"
    format  = "raw"
  }

  network {
    model  = "virtio"
    bridge = var.network.bridge
    id     = 0
  }

  ipconfig0 = "ip=${cidrhost(var.network.gateway_subnet, var.worker_nodes.ip_range_start + count.index)}/${var.network.subnet},gw=${var.network.gateway}"
  sshkeys   = file(var.vm_ssh_public_key_path)
  ciuser    = var.vm_user
}
