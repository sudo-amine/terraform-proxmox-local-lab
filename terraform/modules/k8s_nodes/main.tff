resource "proxmox_vm_qemu" "control_plane" {
  # vm_state    = "stopped"
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
  # vm_state    = "stopped"

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

# resource "local_file" "k8s_inventory" {
#   content = <<EOT
#   # Kubernetes Cluster Inventory
#   [control_plane]

#   %{for index, vm in proxmox_vm_qemu.control_plane}${var.nodes.control_plane.names_prefix}${index + 1} ansible_host=${cidrhost(var.network.gateway_subnet, var.nodes.control_plane.ip_range_start + index)} ansible_user=${var.nodes.control_plane.user} ansible_ssh_private_key_file=${var.ssh_private_key_path} ansible_become=true  vm_id=${vm.vmid}
#   %{endfor}
#   [workers]

#   %{for index, vm in proxmox_vm_qemu.worker_nodes}${var.nodes.workers.names_prefix}${index + 1} ansible_host=${cidrhost(var.network.gateway_subnet, var.nodes.workers.ip_range_start + index)} ansible_user=${var.nodes.workers.user} ansible_ssh_private_key_file=${var.ssh_private_key_path} ansible_become=true  vm_id=${vm.vmid}
#   %{endfor}

#   [control_plane_1]

#   control-plane-1 ansible_host=192.168.1.130 ansible_user=sudo-amine ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_become=true  vm_id=101
#   [all:vars]
#   proxmox_node=${var.proxmox.node}
#   proxmox_host=${var.proxmox.host}
#   proxmox_api_user=${var.proxmox.api_user}
#   proxmox_api_token_id=${var.proxmox.token_id}
#   pod_network_cidr="10.244.0.0/16"
#   control_plane_endpoint="control-plane.local"  
#   EOT

#   filename = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/k8s_nodes/ansible/inventory/k8s_inventory.ini"
# }

resource "local_file" "k8s_inventory" {
  content = <<EOT
  # Kubernetes Cluster Inventory
  [other_cp_nodes]

  %{for index, vm in proxmox_vm_qemu.control_plane}${var.nodes.control_plane.names_prefix}${index + 1} ansible_host=${cidrhost(var.network.gateway_subnet, var.nodes.control_plane.ip_range_start + index)} ansible_user=${var.nodes.control_plane.user} ansible_ssh_private_key_file=${var.ssh_private_key_path} ansible_become=true  vm_id=${vm.vmid}
  %{endfor}
  
  [worker_nodes]
  
  %{for index, vm in proxmox_vm_qemu.worker_nodes}${var.nodes.workers.names_prefix}${index + 1} ansible_host=${cidrhost(var.network.gateway_subnet, var.nodes.workers.ip_range_start + index)} ansible_user=${var.nodes.workers.user} ansible_ssh_private_key_file=${var.ssh_private_key_path} ansible_become=true  vm_id=${vm.vmid}
  %{endfor}
  
  [first_cp_node]
  
  
  [all:vars]
  proxmox_node=${var.proxmox.node}
  proxmox_host=${var.proxmox.host}
  proxmox_api_user=${var.proxmox.api_user}
  proxmox_api_token_id=${var.proxmox.token_id}
  pod_network_cidr="10.244.0.0/16"
  control_plane_endpoint="control-plane.local"  
  EOT

  filename = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/k8s_nodes/ansible/inventory/k8s_inventory.ini"
}

resource "null_resource" "run_ansible" {
  depends_on = [proxmox_vm_qemu.control_plane, proxmox_vm_qemu.worker_nodes]

  triggers = {
    always_run = timestamp() # Forces recreation on every apply    
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Changing directory to the Ansible project directory..."
      cd /home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/k8s_nodes/ansible || exit 1

      echo "Running Ansible playbook to configure the VM using the virtual environment..."
      ~/venv/bin/ansible-playbook -i inventory/k8s_inventory.ini main.yml

      if [ $? -eq 0 ]; then
        echo "Ansible playbook executed successfully."
      else
        echo "Ansible playbook failed. Check logs for details." >&2
        exit 1
      fi
    EOT
  }
}
