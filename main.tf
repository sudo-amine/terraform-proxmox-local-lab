resource "null_resource" "check_and_upload" {
  provisioner "local-exec" {
    command = <<EOT
      existing_file=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/storage/${var.local_storage_pool}/content" \
        | jq -r '.data[] | select(.volid | endswith("jammy-server-cloudimg-amd64.img")) | .volid')

      if [ -z "$existing_file" ]; then
        echo "File not found. Uploading..."
        curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             --header "Content-Type: multipart/form-data" \
             --form "content=iso" \
             --form "filename=@/home/sudo-amine/Downloads/jammy-server-cloudimg-amd64.img" \
             "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/storage/${var.local_storage_pool}/upload" \
             --silent --show-error
      else
        echo "File already exists. Skipping upload."
      fi
    EOT
  }
}

resource "proxmox_vm_qemu" "template_vm" {
  depends_on = [null_resource.check_and_upload]

  name        = var.template_vm_name
  vmid        = var.template_vm_id
  cores       = 2
  memory      = 2048
  scsihw      = "virtio-scsi-pci"
  target_node = var.proxmox_node
  boot        = "order=scsi0;net0"
  vm_state    = "stopped"
  ciuser      = var.cloned_user
  ipconfig0   = "ip=${var.template_vm_ip}/${var.network_subnet},gw=${var.network_gateway}"
  sshkeys     = local.ssh_public_key
  agent       = 1

  # Add a Cloud-Init Disk
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.local_storage_pool_lvm
  }

  # Network Configuration
  network {
    model  = "virtio"
    bridge = var.network_bridge
    id     = 0
  }

  serial {
    id   = 0
    type = "socket"
  }

}

# Resource to import the disk remotely using qm importdisk
resource "null_resource" "import_disk" {
  depends_on = [null_resource.check_and_upload, proxmox_vm_qemu.template_vm]

  connection {
    type = "ssh"
    host = var.proxmox_host
    user = "root"
  }

  provisioner "remote-exec" {
    inline = [
      "disk_exists=$(pvesm list ${var.local_storage_pool_lvm} | grep '${var.template_vm_id}-disk-0')",
      "if [ -z \"$disk_exists\" ]; then",
      "  echo 'Disk does not exist. Importing...';",
      "  qm importdisk ${var.template_vm_id} /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ${var.local_storage_pool_lvm};",
      "else",
      "  echo 'Disk already imported. Skipping.';",
      "fi"
    ]
  }
}

# Null resource to attach the disk to the VM
resource "null_resource" "attach_disk" {
  depends_on = [null_resource.import_disk, proxmox_vm_qemu.template_vm]

  provisioner "local-exec" {
    command = <<EOT
      attached_disk=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/config" \
        | jq -r '.data.scsi0')

      if [ "$attached_disk" != *"${var.local_storage_pool_lvm}:vm-${var.template_vm_id}-disk-0"* ]; then
        echo "Attaching disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             --header "Content-Type: application/json" \
             --data '{"scsi0": "${var.local_storage_pool_lvm}:vm-${var.template_vm_id}-disk-0"}' \
             "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/config"
      else
        echo "Disk already attached. Skipping."
      fi
    EOT
  }
}

# Null resource to resize the attached disk
resource "null_resource" "resize_disk" {
  depends_on = [null_resource.attach_disk]

  provisioner "local-exec" {
    command = <<EOT
      current_size=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/config" \
        | jq -r '.data.scsi0 | split(",")[-1]')

      desired_size="${var.template_vm_disk_size}"

      if [ "$current_size" != "$desired_size" ]; then
        echo "Resizing disk..."
        curl -X PUT --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             --header "Content-Type: application/json" \
             --data '{"disk": "scsi0", "size": "+${var.template_vm_disk_size}"}' \
             "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/resize"
      else
        echo "Disk already at desired size. Skipping resize."
      fi
    EOT
  }
}

resource "null_resource" "start_vm" {
  depends_on = [null_resource.resize_disk]

  provisioner "local-exec" {
    command = <<EOT
      vm_status=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/status/current" \
        | jq -r '.data.status')

      if [ "$vm_status" != "running" ]; then
        echo "Starting VM..."
        curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/status/start"
      else
        echo "VM is already running. Skipping start."
      fi
    EOT
  }
}

resource "null_resource" "check_ssh_ready" {
  depends_on = [null_resource.start_vm]

  provisioner "local-exec" {
    command = <<EOT
      # Function to check the VM status
      check_vm_status() {
        curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
          "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/status/current" \
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
        nc -z -w 2 ${var.template_vm_ip} 22 && echo "VM is SSH-ready" && exit 0
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

  connection {
    type = "ssh"
    host = var.template_vm_ip
    user = var.template_user
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

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
            "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/status/stop"

      # Function to check the VM status
      check_vm_status() {
        curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
          "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/status/current" \
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

  provisioner "local-exec" {
    command = <<EOT
      # Convert the VM into a template using Proxmox API
      curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
           "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/template" \
           --silent --show-error --write-out "%%{http_code}"
    EOT
  }
}


# # Create the VM with Cloud-Init
# resource "proxmox_vm_qemu" "cloned_vm" {
#   depends_on  = [null_resource.convert_to_template]
#   name        = var.cloned_vm_name
#   target_node = var.proxmox_node
#   desc        = "Ubuntu Cloud Template created with Terraform"
#   vmid        = var.cloned_vm_id
#   # Set boot order to prioritize the imported disk
#   boot     = "order=scsi0;net0"
#   bootdisk = "scsi0"
#   # Cloud-Init configuration
#   qemu_os = "l26" # Linux 2.6/3.x/4.x/5.x
#   sshkeys = local.ssh_public_key
#   ciuser  = "sudo-amine"
#   # Ensure the VM shuts down after provisioning for conversion to template
#   ipconfig0 = "ip=192.168.1.100/24,gw=192.168.1.1" # Replace with your network settings

#   vm_state = "stopped"

#   # Wait for Cloud-Init
#   ci_wait = 30


#   # VM hardware configuration
#   memory  = 2048
#   cores   = 4
#   sockets = 1
#   onboot  = false
#   agent   = 1
#   scsihw  = "virtio-scsi-pci"

#   # Attach the imported disk as SCSI
#   disk {
#     type    = "disk"
#     storage = var.local_storage_pool_lvm
#     size    = var.cloned_vm_disk_size # Adjust size as needed
#     slot    = "scsi0"
#   }

#   # Add the Cloud-Init disk
#   disk {
#     type    = "cloudinit"
#     storage = var.local_storage_pool_lvm
#     slot    = "ide2"
#   }



#   # Networking configuration
#   network {
#     model  = "virtio"
#     bridge = "vmbr0" # Replace with your network bridge
#     id     = 0
#   }

#   serial {
#     id   = 0
#     type = "socket"
#   }

# }



