resource "null_resource" "check_and_upload" {
  provisioner "local-exec" {
    command = <<EOT
      # Check if the file already exists in the storage pool
      existing_file=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/storage/${var.local_storage_pool}/content" \
        | jq -r '.data[] | select(.volid | endswith("jammy-server-cloudimg-amd64.img")) | .volid')

      if [ -z "$existing_file" ]; then
        # File does not exist, proceed with upload
        curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
             --header "Content-Type: multipart/form-data" \
             --form "content=iso" \
             --form "filename=@/home/sudo-amine/Downloads/jammy-server-cloudimg-amd64.img" \
             "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/storage/${var.local_storage_pool}/upload" \
             --silent --show-error
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
      "qm importdisk ${var.template_vm_id} /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ${var.local_storage_pool_lvm}"
    ]
  }
}

# Null resource to attach the disk to the VM
resource "null_resource" "attach_disk" {
  depends_on = [null_resource.import_disk, proxmox_vm_qemu.template_vm]

  provisioner "local-exec" {
    command = <<EOT
      # Attach the imported disk to the VM
      curl -X PUT --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
           --header "Content-Type: application/json" \
           --data '{"scsi0": "${var.local_storage_pool_lvm}:vm-${var.template_vm_id}-disk-0"}' \
           "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/config"
    EOT
  }
}

# Null resource to resize the attached disk
resource "null_resource" "resize_disk" {
  depends_on = [null_resource.attach_disk]

  provisioner "local-exec" {
    command = <<EOT
      # Resize the attached disk
      curl -X PUT --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
           --header "Content-Type: application/json" \
           --data '{"disk": "scsi0", "size": "+${var.template_vm_disk_size}"}' \
           "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/resize"
    EOT
  }
}

resource "null_resource" "start_vm" {
  depends_on = [null_resource.resize_disk]

  provisioner "local-exec" {
    command = <<EOT
        # Check if the VM is running using Proxmox API
        vm_status=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=c48784ac-fdb1-40d5-a86e-281c32bc0eb6" \
          "https://proxmox.local:8006/api2/json/nodes/proxmox/qemu/9002/status/current" \
          | jq -r '.data.status')

        if [ "$vm_status" != "running" ]; then
          echo "VM is not running. Waiting for VM to start..."
          exit 1
        fi

        # Check SSH connectivity with extended retries
        for i in $(seq 1 20); do
          echo "Attempt $i: Checking SSH connectivity..."
          nc -z -w 5 192.168.1.101 22 && echo "VM is SSH-ready" && exit 0
          sleep 10
        done

        echo "VM is not SSH-ready after 20 attempts. Exiting with error."
        exit 1
  EOT
  }
}


resource "null_resource" "check_ssh_ready" {
  depends_on = [null_resource.start_vm]
  provisioner "local-exec" {
    command = <<EOT
      # Check if the VM is running using Proxmox API
      vm_status=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
        "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/status/current" \
        | jq -r '.data.status')

      if [ "$vm_status" != "running" ]; then
        echo "VM is not running. Waiting for VM to start..."
        exit 1
      fi

      # Check SSH connectivity
      for i in {1..10}; do
        nc -z -w 2 ${var.template_vm_ip} 22 && echo "VM is SSH-ready" && exit 0
        echo "Waiting for SSH to be ready... Attempt $i"
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
      "if command -v apt-get &> /dev/null; then apt-get update -y; fi",
      "if command -v yum &> /dev/null; then yum makecache -y; fi",

      # Install qemu-guest-agent based on the package manager
      "if command -v apt-get &> /dev/null; then apt-get install -y qemu-guest-agent; fi",
      "if command -v yum &> /dev/null; then yum install -y qemu-guest-agent; fi",

      # Start the service
      "systemctl start qemu-guest-agent || echo 'Service already started'",

      # Enable the service to autostart
      "systemctl enable qemu-guest-agent || echo 'Service already enabled'"
    ]
  }
}

resource "null_resource" "stop_vm" {
  depends_on = [null_resource.install_qemu_guest_agent]

  provisioner "local-exec" {
    command = <<EOT
      # Stop the VM using Proxmox API
      curl -X POST --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
           "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/status/stop"

      # Wait until the VM is completely stopped
      for i in {1..20}; do
        vm_status=$(curl -s --header "Authorization: PVEAPIToken=terraform-prov@pve!tid=${data.vault_kv_secret_v2.proxmox_token.data.token}" \
          "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.template_vm_id}/status/current" \
          | jq -r '.data.status')

        if [ "$vm_status" == "stopped" ]; then
          echo "VM is stopped."
          exit 0
        fi

        echo "Waiting for VM to stop... Attempt $i"
        sleep 5
      done

      echo "VM did not stop after 20 attempts. Exiting with error."
      exit 1
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



