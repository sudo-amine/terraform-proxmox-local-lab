# Resource to import the disk remotely using qm importdisk
resource "proxmox_storage_iso" "upload_image" {
  url      = var.vm_template.image_url
  filename = basename(var.vm_template.image_url)
  storage  = var.storage.local
  pve_node = var.proxmox_node
}

# TODO replace with custom provider, as the current provider does not support importing disks
resource "null_resource" "import_disk" {

  triggers = {
    instance_id = proxmox_vm_qemu.vm_template.id
  }

  connection {
    type  = "ssh"
    host  = var.proxmox_host
    user  = "root"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "disk_exists=$(pvesm list ${var.storage.main} | grep '${var.vm_template.id}-disk-0')",
      "if [ -z \"$disk_exists\" ]; then",
      "  echo 'Disk does not exist. Importing...';",
      "  qm importdisk ${var.vm_template.id} /var/lib/vz/template/iso/${proxmox_storage_iso.upload_image.filename} ${var.storage.main} --format qcow2;",
      "else",
      "  echo 'Disk already imported. Skipping.';",
      "fi"
    ]
  }
}

# Null resource to attach the disk to the VM
resource "null_resource" "attach_disk" {
  depends_on = [null_resource.import_disk]

  provisioner "local-exec" {
    command = <<EOT
      attached_disk=$(curl -s --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${local.secret_proxmox_api_token}" \
        "https://${var.proxmox_host}:${var.proxmox_api_url_port}/${var.proxmox_api_url_path}/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/config" \
        | jq -r '.data.scsi0')

      # Extract the disk path (remove the ',size=...' part)
      disk_path=$(echo "$attached_disk" | cut -d',' -f1)

      if [ "$disk_path" != "${var.storage.main}:vm-${var.vm_template.id}-disk-0" ]; then
        echo "Attaching disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${local.secret_proxmox_api_token}" \
            --header "Content-Type: application/json" \
            --data '{"scsi0": "${var.storage.main}:vm-${var.vm_template.id}-disk-0"}' \
            "https://${var.proxmox_host}:${var.proxmox_api_url_port}/${var.proxmox_api_url_path}/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/config"
      else
        echo "Disk already attached. Skipping."
      fi
    EOT
  }

}

resource "null_resource" "resize_disk" {
  depends_on = [null_resource.attach_disk]

  triggers = {
    instance_id = proxmox_vm_qemu.vm_template.id
  }

  provisioner "local-exec" {
    command = <<EOT
      current_size=$(curl -s --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${local.secret_proxmox_api_token}" \
        "https://${var.proxmox_host}:${var.proxmox_api_url_port}/${var.proxmox_api_url_path}/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/config" \
        | jq -r '.data.scsi0 | split(",")[-1]')

      desired_size="${var.vm_template.disk_size}"

      if [ "$current_size" != "$desired_size" ]; then
        echo "Resizing disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${local.secret_proxmox_api_token}" \
             --header "Content-Type: application/json" \
             --data '{"disk": "scsi0", "size": "+${var.vm_template.disk_size}"}' \
             "https://${var.proxmox_host}:${var.proxmox_api_url_port}/${var.proxmox_api_url_path}/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/resize"
      else
        echo "Disk already at desired size. Skipping resize."
      fi
    EOT
  }
}
