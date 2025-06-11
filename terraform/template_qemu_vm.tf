resource "proxmox_vm_qemu" "vm_template" {
  depends_on = [proxmox_storage_iso.upload_image]

  name        = var.vm_template.name
  vmid        = var.vm_template.id
  cores       = 2
  memory      = 2048
  scsihw      = "virtio-scsi-pci"
  target_node = var.proxmox_node
  boot        = "order=scsi0;net0"
  vm_state    = "stopped"
  ciuser      = var.vm_user
  ipconfig0   = "ip=${var.vm_template.ip}/${var.network.subnet},gw=${var.network.gateway}"
  sshkeys     = file(var.vm_ssh_public_key_path)
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
    ignore_changes = all
  }
}

resource "null_resource" "convert_to_template" {
  depends_on = [null_resource.run_ansible]

  triggers = {
    instance_id = proxmox_vm_qemu.vm_template.id
  }

  provisioner "local-exec" {
    command = <<EOT
      # Convert the VM into a template using Proxmox API
      curl -X POST --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${local.secret_proxmox_api_token}" \
           "https://${var.proxmox_host}:${var.proxmox_api_url_port}/${var.proxmox_api_url_path}/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/template" \
           --silent --show-error --write-out "%%{http_code}"
    EOT
  }
}
