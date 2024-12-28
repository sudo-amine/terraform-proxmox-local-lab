resource "null_resource" "check_and_upload" {
  provisioner "local-exec" {
    command = <<EOT
      # Check if the image already exists in Proxmox storage
      existing_file=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/storage/${var.storage.local}/content" \
        | jq -r '.data[] | select(.volid | endswith("${var.image_name}")) | .volid')

      if [ -z "$existing_file" ]; then
        echo "File not found in Proxmox storage. Checking local image..."

        # Check if the image exists locally
        if [ ! -f "/tmp/${var.image_name}" ]; then
          wget -O "/tmp/${var.image_name}" "${var.image_url}"
          if [ $? -ne 0 ]; then
            echo "Error: Failed to download the image from ${var.image_url}"
            exit 1
          fi
        else
          echo "Local image found at tmp/${var.image_name}. Skipping download."
        fi

        # Upload the image to Proxmox storage
        echo "Uploading image to Proxmox storage..."
        curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             --header "Content-Type: multipart/form-data" \
             --form "content=iso" \
             --form "filename=@/tmp/${var.image_name}" \
             "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/storage/${var.storage.local}/upload" \
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


resource "proxmox_vm_qemu" "template_vm" {
  depends_on = [null_resource.check_and_upload]

  name        = var.template_vm.name
  vmid        = var.template_vm.id
  cores       = 2
  memory      = 2048
  scsihw      = "virtio-scsi-pci"
  target_node = var.proxmox.node
  boot        = "order=scsi0;net0"
  vm_state    = "stopped"
  ciuser      = var.template_vm.user
  ipconfig0   = "ip=${var.template_vm.ip}/${var.network.subnet},gw=${var.network.gateway}"
  sshkeys     = local.ssh_public_key
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

# Resource to import the disk remotely using qm importdisk
resource "null_resource" "import_disk" {
  depends_on = [null_resource.check_and_upload, proxmox_vm_qemu.template_vm]

  triggers = {
    instance_id = proxmox_vm_qemu.template_vm.id
  }

  connection {
    type = "ssh"
    host = var.proxmox.host
    user = "root"
  }

  provisioner "remote-exec" {
    inline = [
      "disk_exists=$(pvesm list ${var.storage.main} | grep '${var.template_vm.id}-disk-0')",
      "if [ -z \"$disk_exists\" ]; then",
      "  echo 'Disk does not exist. Importing...';",
      "  qm importdisk ${var.template_vm.id} /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ${var.storage.main} --format qcow2;",
      "else",
      "  echo 'Disk already imported. Skipping.';",
      "fi"
    ]
  }
}

# Null resource to attach the disk to the VM
resource "null_resource" "attach_disk" {
  depends_on = [null_resource.import_disk, proxmox_vm_qemu.template_vm]

  triggers = {
    instance_id = proxmox_vm_qemu.template_vm.id
  }

  provisioner "local-exec" {
    command = <<EOT
      attached_disk=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/config" \
        | jq -r '.data.scsi0')

      if [ "$attached_disk" != *"${var.storage.main}:vm-${var.template_vm.id}-disk-0"* ]; then
        echo "Attaching disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             --header "Content-Type: application/json" \
             --data '{"scsi0": "${var.storage.main}:vm-${var.template_vm.id}-disk-0"}' \
             "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/config"
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
    instance_id = proxmox_vm_qemu.template_vm.id
  }

  provisioner "local-exec" {
    command = <<EOT
      current_size=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/config" \
        | jq -r '.data.scsi0 | split(",")[-1]')

      desired_size="${var.template_vm.disk_size}"

      if [ "$current_size" != "$desired_size" ]; then
        echo "Resizing disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             --header "Content-Type: application/json" \
             --data '{"disk": "scsi0", "size": "+${var.template_vm.disk_size}"}' \
             "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/resize"
      else
        echo "Disk already at desired size. Skipping resize."
      fi
    EOT
  }
}

resource "null_resource" "start_vm" {
  depends_on = [null_resource.resize_disk]

  triggers = {
    instance_id = proxmox_vm_qemu.template_vm.id
  }

  provisioner "local-exec" {
    command = <<EOT
      vm_status=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/status/current" \
        | jq -r '.data.status')

      if [ "$vm_status" != "running" ]; then
        echo "Starting VM..."
        curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/status/start"
      else
        echo "VM is already running. Skipping start."
      fi
    EOT
  }
}

resource "null_resource" "check_ssh_ready" {
  depends_on = [null_resource.start_vm]

  triggers = {
    instance_id = proxmox_vm_qemu.template_vm.id
  }

  provisioner "local-exec" {
    command = <<EOT
      # Function to check the VM status
      check_vm_status() {
        curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
          "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/status/current" \
          | jq -r '.data.status'
      }

      # Wait for the VM to reach the "running" state
      attempt=1
      while [ $attempt -le 20 ]; do
        vm_status=$(check_vm_status)
        if [ "$vm_status" = "running" ]; then
          echo "VM is running."
          break
        fi

        if [ $attempt -eq 20 ]; then
          echo "VM did not start after 20 attempts. Exiting."
          exit 1
        fi

        echo "VM is not running yet. Attempt $attempt. Retrying in 10 seconds..."
        attempt=$((attempt + 1))
        sleep 10
      done

      # Check SSH connectivity
      attempt=1
      while [ $attempt -le 10 ]; do
        nc -z -w 2 ${var.template_vm.ip} 22 && echo "VM is SSH-ready" && exit 0
        echo "Waiting for SSH to be ready... Attempt $attempt"
        attempt=$((attempt + 1))
        sleep 5
      done

      echo "VM is not SSH-ready after 10 attempts."
      exit 1
    EOT
  }
}

resource "null_resource" "install_qemu_guest_agent" {
  depends_on = [null_resource.check_ssh_ready]

  triggers = {
    instance_id = proxmox_vm_qemu.template_vm.id
  }

  connection {
    type = "ssh"
    host = var.template_vm.ip
    user = var.template_vm.user
  }

  provisioner "remote-exec" {
    inline = [
      # Update the package lists
      "if command -v sudo apt-get &> /dev/null; then sudo apt-get update -y; fi",
      "if command -v sudo yum &> /dev/null; then sudo yum makecache -y; fi",

      # Install qemu-guest-agent based on the package manager
      "if command -v sudo apt-get &> /dev/null; then sudo apt-get install -y qemu-guest-agent; fi",
      "if command -v sudo yum &> /dev/null; then sudo yum install -y qemu-guest-agent; fi",

      # Start the service
      "sudo systemctl start qemu-guest-agent || echo 'Service already started'",

      # Enable the service to autostart
      "sudo systemctl enable qemu-guest-agent || echo 'Service already enabled'"
    ]
  }
}

resource "null_resource" "stop_vm" {
  depends_on = [null_resource.install_qemu_guest_agent]

  triggers = {
    instance_id = proxmox_vm_qemu.template_vm.id
  }

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
            "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/status/stop"

      # Function to check the VM status
      check_vm_status() {
        curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
          "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/status/current" \
          | jq -r '.data.status'
      }

      # Wait for the VM to reach the "stopped" state
      attempt=1
      while [ $attempt -le 20 ]; do
        vm_status=$(check_vm_status)
        if [ "$vm_status" = "stopped" ]; then
          echo "VM is stopped."
          break
        fi

        if [ $attempt -eq 20 ]; then
          echo "VM have not stopped yet after 20 attempts. Exiting."
          exit 1
        fi

        echo "VM is still running. Attempt $attempt. Retrying in 10 seconds..."
        attempt=$((attempt + 1))
        sleep 10
      done
    EOT
  }
}

# Null resource to convert the VM into a template using the API
resource "null_resource" "convert_to_template" {
  depends_on = [null_resource.stop_vm]

  triggers = {
    instance_id = proxmox_vm_qemu.template_vm.id
  }

  provisioner "local-exec" {
    command = <<EOT
      # Convert the VM into a template using Proxmox API
      curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
           "https://${var.proxmox.host}:8006/api2/json/nodes/${var.proxmox.node}/qemu/${var.template_vm.id}/template" \
           --silent --show-error --write-out "%%{http_code}"
    EOT
  }
}
