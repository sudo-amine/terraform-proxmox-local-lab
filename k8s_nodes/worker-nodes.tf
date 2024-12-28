resource "proxmox_vm_qemu" "worker_nodes" {
  count       = var.nodes.workers.count
  vmid        = "${var.nodes.workers.first_id + count.index + 1}"
  name        = "${var.nodes.workers.names_prefix}${count.index + 1}"
  target_node = var.proxmox.node
  clone       = var.template_vm.name
  cores       = var.nodes.workers.cores
  memory      = var.nodes.workers.memory
  agent       = 1
  scsihw      = "virtio-scsi-pci"
  full_clone  = true
  vm_state    = "stopped"

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.proxmox.local_storage_lvm
  }

  disk {
    size    = var.nodes.workers.disk_size
    storage = var.proxmox.local_storage_lvm
    type    = "disk"
    slot    = "scsi0"
    format  = "raw"
  }

  network {
    model  = "virtio"
    bridge = var.network.bridge
    id     = 0
  }

  ipconfig0 = "ip=${cidrhost(var.network.gateway_subnet, count.index + var.nodes.workers.ip_range_start)}/${var.network.subnet},gw=${var.network.gateway}"
  sshkeys   = local.ssh_public_key
  ciuser    = var.nodes.workers.user
}
