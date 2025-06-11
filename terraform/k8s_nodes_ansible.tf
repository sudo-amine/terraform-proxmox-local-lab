# Define the dynamic inventory generation as a local file
resource "local_file" "ansible_inventory" {
  content = <<EOT
[local]
localhost ansible_connection=local

[control_plane_single]
${keys(local.control_plane_nodes)[0]} ansible_user=${var.vm_user} ansible_ssh_private_key_file=${var.vm_ssh_private_key_path} ansible_become=true vm_id=${local.control_plane_nodes[keys(local.control_plane_nodes)[0]]} vm_ip=${keys(local.control_plane_nodes)[0]}

[control_plane]
%{ for ip, id in local.control_plane_nodes ~}
${ip} ansible_user=${var.vm_user} ansible_ssh_private_key_file=${var.vm_ssh_private_key_path} ansible_become=true vm_id=${id} vm_ip=${ip}
%{ endfor }

[worker_nodes]
%{ for ip, id in local.worker_nodes ~}
${ip} ansible_user=${var.vm_user} ansible_ssh_private_key_file=${var.vm_ssh_private_key_path} ansible_become=true vm_id=${id} vm_ip=${ip}
%{ endfor }
EOT
  filename = "${path.module}/inventory.ini"
}


# Define a null_resource to trigger Ansible playbook execution
resource "null_resource" "run_ansible_playbook" {
  triggers = {
    always_run = timestamp()
    inventory  = sha1(local_file.ansible_inventory.content)
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Running Ansible playbook to initialize the cluster..."
      ~/venv/bin/ansible-playbook \
        -i "${local_file.ansible_inventory.filename}" \
        --extra-vars '{
          "proxmox_host": "${var.proxmox_host}",
          "proxmox_node": "${var.proxmox_node}",
          "proxmox_api_user": "${var.proxmox_api_user}",
          "proxmox_api_token_id": "${var.proxmox_api_token_id}",
          "status_retries": 10,
          "status_delay": 10,
          "ssh_wait_timeout": 300
        }' \
        /home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/ansible/playbooks/start_all_vms.yml
    EOT
  }
}

# Local variables for clean logic and reusability
locals {
  # Calculate control plane and worker node IPs and IDs
  control_plane_nodes = { for i in range(length(proxmox_vm_qemu.control_plane)) :
    cidrhost(var.network.gateway_subnet, var.control_plane.ip_range_start + i) =>
    var.control_plane.first_id + i
  }

  worker_nodes = { for i in range(length(proxmox_vm_qemu.worker_nodes)) :
    cidrhost(var.network.gateway_subnet, var.worker_nodes.ip_range_start + i) =>
    var.worker_nodes.first_id + i
  }
}
