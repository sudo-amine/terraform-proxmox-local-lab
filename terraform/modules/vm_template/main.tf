resource "null_resource" "check_and_upload" {
  provisioner "local-exec" {
    command = <<EOT
      # Check if the image already exists in Proxmox storage
      existing_file=$(curl -s --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${var.proxmox_api_token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/storage/${var.storage.local}/content" \
        | jq -r '.data[] | select(.volid | endswith("${var.vm_template.image_name}")) | .volid')

      if [ -z "$existing_file" ]; then
        echo "File not found in Proxmox storage. Checking local image..."

        # Check if the image exists locally
        if [ ! -f "/tmp/${var.vm_template.image_name}" ]; then
          wget -O "/tmp/${var.vm_template.image_name}" "${var.vm_template.image_url}"
          if [ $? -ne 0 ]; then
            echo "Error: Failed to download the image from ${var.vm_template.image_url}"
            exit 1
          fi
        else
          echo "Local image found at tmp/${var.vm_template.image_name}. Skipping download."
        fi

        # Upload the image to Proxmox storage
        echo "Uploading image to Proxmox storage..."
        curl -X POST --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${var.proxmox_api_token}" \
             --header "Content-Type: multipart/form-data" \
             --form "content=iso" \
             --form "filename=@/tmp/${var.vm_template.image_name}" \
             "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/storage/${var.storage.local}/upload" \
             --silent --show-error

        if [ $? -ne 0 ]; then
          echo "Error: Failed to upload the image to Proxmox storage."
          exit 1
        fi

        echo "Image upload completed successfully."
      else
        echo "File already exists in Proxmox storage. Skipping upload."
      fi
    EOT
  }
}

resource "proxmox_vm_qemu" "vm_template" {
  depends_on = [null_resource.check_and_upload]

  name        = var.vm_template.name
  vmid        = var.vm_template.id
  cores       = 2
  memory      = 2048
  scsihw      = "virtio-scsi-pci"
  target_node = var.proxmox_node
  boot        = "order=scsi0;net0"
  vm_state    = "stopped"
  ciuser      = var.vm_template.user
  ipconfig0   = "ip=${var.vm_template.ip}/${var.network.subnet},gw=${var.network.gateway}"
  sshkeys     = var.ssh.public_key_path
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

# Generate the Dynamic Ansible Inventory File
resource "local_file" "ansible_inventory" {
  content = <<EOT
  [vm]
  ${var.vm_template.ip} ansible_user=${var.vm_template.user} ansible_ssh_private_key_file=${var.ssh.private_key_path} ansible_become=true

  [all:vars]
  proxmox_node=${var.proxmox_node}
  proxmox_host=${var.proxmox_host}
  proxmox_api_user=${var.proxmox_api_user}
  proxmox_api_token_id=${var.proxmox_api_token_id}
  vm_id=${var.vm_template.id}
  EOT

  filename = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/vm_template/ansible/inventory/inventory.ini"
}

# Resource to import the disk remotely using qm importdisk
resource "null_resource" "import_disk" {
  depends_on = [null_resource.check_and_upload, proxmox_vm_qemu.vm_template]

  triggers = {
    instance_id = proxmox_vm_qemu.vm_template.id
  }

  connection {
    type = "ssh"
    host = var.proxmox_host
    user = "root"
  }

  provisioner "remote-exec" {
    inline = [
      "disk_exists=$(pvesm list ${var.storage.main} | grep '${var.vm_template.id}-disk-0')",
      "if [ -z \"$disk_exists\" ]; then",
      "  echo 'Disk does not exist. Importing...';",
      "  qm importdisk ${var.vm_template.id} /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ${var.storage.main} --format qcow2;",
      "else",
      "  echo 'Disk already imported. Skipping.';",
      "fi"
    ]
  }
}

# Null resource to attach the disk to the VM
resource "null_resource" "attach_disk" {
  depends_on = [null_resource.import_disk, proxmox_vm_qemu.vm_template]

  triggers = {
    instance_id = proxmox_vm_qemu.vm_template.id
  }

  provisioner "local-exec" {
    command = <<EOT
      attached_disk=$(curl -s --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${var.proxmox_api_token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/config" \
        | jq -r '.data.scsi0')

      if [ "$attached_disk" != *"${var.storage.main}:vm-${var.vm_template.id}-disk-0"* ]; then
        echo "Attaching disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${var.proxmox_api_token}" \
             --header "Content-Type: application/json" \
             --data '{"scsi0": "${var.storage.main}:vm-${var.vm_template.id}-disk-0"}' \
             "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/config"
      else
        echo "Disk already attached. Skipping."
      fi
    EOT
  }
}

# Null resource to resize the attached disk
resource "null_resource" "resize_disk" {
  depends_on = [null_resource.attach_disk]

  triggers = {
    instance_id = proxmox_vm_qemu.vm_template.id
  }

  provisioner "local-exec" {
    command = <<EOT
      current_size=$(curl -s --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${var.proxmox_api_token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/config" \
        | jq -r '.data.scsi0 | split(",")[-1]')

      desired_size="${var.vm_template.disk_size}"

      if [ "$current_size" != "$desired_size" ]; then
        echo "Resizing disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${var.proxmox_api_token}" \
             --header "Content-Type: application/json" \
             --data '{"disk": "scsi0", "size": "+${var.vm_template.disk_size}"}' \
             "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/resize"
      else
        echo "Disk already at desired size. Skipping resize."
      fi
    EOT
  }
}

data "http" "vm_template_status" {
  depends_on = [null_resource.resize_disk]
  url        = "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/status/current"
  request_headers = {
    Authorization = "PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${var.proxmox_api_token}"
  }
}

# Null Resource to Run Ansible
resource "null_resource" "run_ansible" {
  depends_on = [null_resource.resize_disk]
  triggers = {
    always_run  = timestamp() # Forces recreation on every apply
    is_template = try(jsondecode(data.http.vm_template_status.response_body).data.template, 0) == 1 ? "true" : "false"
  }

  provisioner "local-exec" {
    command = <<EOT
      if [ "${self.triggers.is_template}" = "true" ]; then
        echo "VM is a template. Skipping Ansible execution."
        exit 0
      fi

      echo "Changing directory to the Ansible project directory..."
      cd /home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/vm_template/ansible || exit 1

      echo "Running Ansible playbook to configure the VM using the virtual environment..."
      ~/venv/bin/ansible-playbook -i inventory/inventory.ini main.yml

      if [ $? -eq 0 ]; then
        echo "Ansible playbook executed successfully."
      else
        echo "Ansible playbook failed. Check logs for details." >&2
        exit 1
      fi
    EOT
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
      curl -X POST --header "Authorization: PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${var.proxmox_api_token}" \
           "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/template" \
           --silent --show-error --write-out "%%{http_code}"
    EOT
  }
}
