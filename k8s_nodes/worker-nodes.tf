resource "proxmox_vm_qemu" "worker_nodes" {
  count       = var.nodes.workers.count
  vmid        = var.nodes.workers.first_id + count.index + 1
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

resource "local_file" "workers_inventory" {
  content = <<EOT
  [workers]
  %{for index, vm in proxmox_vm_qemu.worker_nodes}
  ${cidrhost(var.network.gateway_subnet, var.nodes.workers.ip_range_start + index)} ansible_user=${var.nodes.workers.user} ansible_ssh_private_key_file=${var.ssh_private_key_path} ansible_become=true
  %{endfor}

  [all:vars]
  proxmox_node=${var.proxmox.node}
  proxmox_host=${var.proxmox.host}
  proxmox_api_user=${var.proxmox.api_user}
  proxmox_api_token_id=${var.proxmox.token_id}
  EOT

  filename = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/ansible/inventory/workers_inventory.ini"
}
