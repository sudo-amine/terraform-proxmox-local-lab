resource "proxmox_vm_qemu" "control_plane" {
  vm_state    = "stopped"
  count       = var.nodes.control_plane.count
  vmid        = var.nodes.control_plane.first_id + count.index + 1
  name        = "${var.nodes.control_plane.names_prefix}${count.index + 1}"
  target_node = var.proxmox.node
  clone       = var.template_vm.name
  cores       = var.nodes.control_plane.cores
  memory      = var.nodes.control_plane.memory
  agent       = 1
  scsihw      = "virtio-scsi-pci"
  full_clone  = true

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.proxmox.local_storage_lvm
  }

  disk {
    size    = var.nodes.control_plane.disk_size
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

  ipconfig0 = "ip=${cidrhost(var.network.gateway_subnet, var.nodes.control_plane.ip_range_start + count.index)}/${var.network.subnet},gw=${var.network.gateway}"
  sshkeys   = local.ssh_public_key
  ciuser    = var.nodes.control_plane.user


}

resource "local_file" "k8s_control_plane_nodes_ansible_inventory" {
  content = <<EOT
  [vm]
  %{ for index, vm in proxmox_vm_qemu.control_plane }
  ${cidrhost(var.network.gateway_subnet, var.nodes.control_plane.ip_range_start + index)} ansible_user=${var.nodes.control_plane.user} ansible_ssh_private_key_file=${var.ssh_private_key_path} ansible_become=true
  %{ endfor }

  [all:vars]
  proxmox_node=${var.proxmox.node}
  proxmox_host=${var.proxmox.host}
  proxmox_api_user=${var.proxmox.api_user}
  proxmox_api_token_id=${var.proxmox.token_id}
  EOT

  filename = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/k8s_nodes/ansible/inventory/control_plane_inventory.ini"
}
