# Resource to import the disk remotely using qm importdisk
resource "proxmox_storage_iso" "upload_image" {
  url      = local.image_url
  filename = local.image_name
  storage  = local.local_storage
  pve_node = local.node
}

# TODO replace with custom provider, as the current provider does not support importing disks
resource "null_resource" "import_disk" {

  triggers = {
    instance_id = proxmox_vm_qemu.vm_template.id
  }

  connection {
    type  = "ssh"
    host  = local.host
    user  = "root"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "disk_exists=$(pvesm list ${local.main_storage} | grep '${local.vmid}-disk-0')",
      "if [ -z \"$disk_exists\" ]; then",
      "  echo 'Disk does not exist. Importing...';",
      "  qm importdisk ${local.vmid} /var/lib/vz/template/iso/${proxmox_storage_iso.upload_image.filename} ${local.main_storage} --format qcow2;",
      "else",
      "  echo 'Disk already imported. Skipping.';",
      "fi"
    ]
  }
}

# Null resource to attach the disk to the VM
resource "null_resource" "attach_disk" {
  depends_on = [null_resource.import_disk]

  triggers = {
    instance_id = proxmox_vm_qemu.vm_template.id
  }

  provisioner "local-exec" {
    command = <<EOT
      attached_disk=$(curl -s --header "Authorization: PVEAPIToken=${local.user}!${local.token_id}=${local.secret}" \
        "${local.api_url}/nodes/${local.node}/qemu/${local.vmid}/config" \
        | jq -r '.data.scsi0')

      if [ "$attached_disk" != *"${local.main_storage}:vm-${local.vmid}-disk-0"* ]; then
        echo "Attaching disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=${local.user}!${local.token_id}=${local.secret}" \
             --header "Content-Type: application/json" \
             --data '{"scsi0": "${local.main_storage}:vm-${local.vmid}-disk-0"}' \
             "${local.api_url}/nodes/${local.node}/qemu/${local.vmid}/config"
      else
        echo "Disk already attached. Skipping."
      fi
    EOT
  }
}
