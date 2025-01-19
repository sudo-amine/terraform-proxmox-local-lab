

# # Generate the Dynamic Ansible Inventory File
# resource "local_file" "ansible_inventory" {
#   content = <<EOT
#   [vm]
#   ${var.vm_template.ip} ansible_user=${var.user} ansible_ssh_private_key_file=${var.ssh_config.private_key_path} ansible_become=true

#   [all:vars]
#   proxmox.node=${var.proxmox.node}
#   proxmox.host=${var.proxmox.host}
#   proxmox_api_user=${var.proxmox.api_user}
#   proxmox.api_token_id=${var.proxmox.api_token_id}
#   vm_id=${var.vm_template.id}
#   EOT

#   filename = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/vm_template/ansible/inventory/inventory.ini"
# }

# # Resource to import the disk remotely using qm importdisk
# resource "null_resource" "import_disk" {
#   depends_on = [null_resource.check_and_upload]

#   triggers = {
#     instance_id = proxmox_vm_qemu.vm_template.id
#   }

#   connection {
#     type = "ssh"
#     host = var.proxmox.host
#     user = "root"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "disk_exists=$(pvesm list ${var.storage.main} | grep '${var.vm_template.id}-disk-0')",
#       "if [ -z \"$disk_exists\" ]; then",
#       "  echo 'Disk does not exist. Importing...';",
#       "  qm importdisk ${var.vm_template.id} /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ${var.storage.main} --format qcow2;",
#       "else",
#       "  echo 'Disk already imported. Skipping.';",
#       "fi"
#     ]
#   }
# }

# # Null resource to attach the disk to the VM
# resource "null_resource" "attach_disk" {
#   depends_on = [null_resource.import_disk]

#   triggers = {
#     instance_id = proxmox_vm_qemu.vm_template.id
#   }

#   provisioner "local-exec" {
#     command = <<EOT
#       attached_disk=$(curl -s --header "Authorization: PVEAPIToken=${var.proxmox.api_user}!${var.proxmox.api_token_id}=${var.secret_proxmox_api_token}" \
#         "${var.proxmox.api_url}/nodes/${var.proxmox.node}/qemu/${var.vm_template.id}/config" \
#         | jq -r '.data.scsi0')

#       if [ "$attached_disk" != *"${var.storage.main}:vm-${var.vm_template.id}-disk-0"* ]; then
#         echo "Attaching disk..."
#         curl -X PUT --header "Authorization: PVEAPIToken=${var.proxmox.api_user}!${var.proxmox.api_token_id}=${var.secret_proxmox_api_token}" \
#              --header "Content-Type: application/json" \
#              --data '{"scsi0": "${var.storage.main}:vm-${var.vm_template.id}-disk-0"}' \
#              "${var.proxmox.api_url}/nodes/${var.proxmox.node}/qemu/${var.vm_template.id}/config"
#       else
#         echo "Disk already attached. Skipping."
#       fi
#     EOT
#   }
# }

# # Null resource to resize the attached disk
# resource "null_resource" "resize_disk" {
#   depends_on = [null_resource.attach_disk]

#   triggers = {
#     instance_id = proxmox_vm_qemu.vm_template.id
#   }

#   provisioner "local-exec" {
#     command = <<EOT
#       current_size=$(curl -s --header "Authorization: PVEAPIToken=${var.proxmox.api_user}!${var.proxmox.api_token_id}=${var.secret_proxmox_api_token}" \
#         "${var.proxmox.api_url}/nodes/${var.proxmox.node}/qemu/${var.vm_template.id}/config" \
#         | jq -r '.data.scsi0 | split(",")[-1]')

#       desired_size="${var.vm_template.disk_size}"

#       if [ "$current_size" != "$desired_size" ]; then
#         echo "Resizing disk..."
#         curl -X PUT --header "Authorization: PVEAPIToken=${var.proxmox.api_user}!${var.proxmox.api_token_id}=${var.secret_proxmox_api_token}" \
#              --header "Content-Type: application/json" \
#              --data '{"disk": "scsi0", "size": "+${var.vm_template.disk_size}"}' \
#              "${var.proxmox.api_url}/nodes/${var.proxmox.node}/qemu/${var.vm_template.id}/resize"
#       else
#         echo "Disk already at desired size. Skipping resize."
#       fi
#     EOT
#   }
# }


# # Null Resource to Run Ansible



# resource "null_resource" "convert_to_template" {
#   depends_on = [null_resource.run_ansible]

#   triggers = {
#     instance_id = proxmox_vm_qemu.vm_template.id
#   }

#   provisioner "local-exec" {
#     command = <<EOT
#       # Convert the VM into a template using Proxmox API
#       curl -X POST --header "Authorization: PVEAPIToken=${var.proxmox.api_user}!${var.proxmox.api_token_id}=${var.secret_proxmox_api_token}" \
#            "${var.proxmox.api_url}/nodes/${var.proxmox.node}/qemu/${var.vm_template.id}/template" \
#            --silent --show-error --write-out "%%{http_code}"
#     EOT
#   }
# }



# Null resource to attach the disk to the VM
# resource "null_resource" "attach_disk" {
#   depends_on = [null_resource.import_disk]

#   triggers = {
#     instance_id = proxmox_vm_qemu.vm_template.id
#   }

#   provisioner "local-exec" {
#     command = <<EOT
#       attached_disk=$(curl -s --header "Authorization: PVEAPIToken=${local.user}!${local.token_id}=${local.secret}" \
#         "${local.api_url}/nodes/${local.node}/qemu/${local.vmid}/config" \
#         | jq -r '.data.scsi0')

#       if [ "$attached_disk" != *"${local.main_storage}:vm-${local.vmid}-disk-0"* ]; then
#         echo "Attaching disk..."
#         curl -X PUT --header "Authorization: PVEAPIToken=${local.user}!${local.token_id}=${local.secret}" \
#              --header "Content-Type: application/json" \
#              --data '{"scsi0": "${local.main_storage}:vm-${local.vmid}-disk-0"}' \
#              "${local.api_url}/nodes/${local.node}/qemu/${local.vmid}/config"
#       else
#         echo "Disk already attached. Skipping."
#       fi
#     EOT
#   }
# }

# resource "null_resource" "resize_disk" {
#   depends_on = [null_resource.attach_disk]

#   triggers = {
#     instance_id = proxmox_vm_qemu.vm_template.id
#   }

#   provisioner "local-exec" {
#     command = <<EOT
#       current_size=$(curl -s --header "Authorization: PVEAPIToken=${local.user}!${local.token_id}=${local.secret}" \
#         "${var.proxmox.api_url}/nodes/${var.proxmox.node}/qemu/${var.vm_template.id}/config" \
#         | jq -r '.data.scsi0 | split(",")[-1]')

#       desired_size="${var.vm_template.disk_size}"

#       if [ "$current_size" != "$desired_size" ]; then
#         echo "Resizing disk..."
#         curl -X PUT --header "Authorization: PVEAPIToken=${local.user}!${local.token_id}=${local.secret}" \
#              --header "Content-Type: application/json" \
#              --data '{"disk": "scsi0", "size": "+${local.disk_size}"}' \
#              "${local.api_url}/nodes/${local.node}/qemu/${local.vmid}/resize"
#       else
#         echo "Disk already at desired size. Skipping resize."
#       fi
#     EOT
#   }
# }