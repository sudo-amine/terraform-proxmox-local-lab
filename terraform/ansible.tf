# Null Resource to Run Ansible
resource "null_resource" "run_ansible" {
  triggers = {
    # Always trigger on each apply
    always_run  = timestamp()
    # Trigger conditionally based on VM template status
    is_template = try(jsondecode(data.http.vm_template_status.response_body).data.template, 0) == 1 ? "true" : "false"
  }

  provisioner "local-exec" {
    command = <<EOT
      # Exit if VM is a template
      if [ "${self.triggers.is_template}" = "true" ]; then
        echo "VM is a template. Skipping Ansible execution."
        exit 0
      fi

      # Log playbook execution start
      echo "Running Ansible playbook on the VM..."

      # Create a dynamic inventory string
      inventory_file=$(mktemp)
      echo "[all]" > $inventory_file
      echo "localhost ansible_connection=local" >> $inventory_file
      echo "${var.vm_template.name} ansible_host=${var.vm_template.ip} ansible_user=${var.vm_user} ansible_ssh_private_key_file=${var.vm_ssh_private_key_path} ansible_become=true" >> $inventory_file

      # Run the Ansible playbook
      ~/venv/bin/ansible-playbook \
        -i "$inventory_file" \
        --extra-vars '{
          "proxmox_host": "${var.proxmox_host}",
          "proxmox_node": "${var.proxmox_node}",
          "proxmox_api_user": "${var.proxmox_api_user}",
          "proxmox_api_token_id": "${var.proxmox_api_token_id}",
          "vm_id": "${var.vm_template.id}",
          "vm_ip": "${var.vm_template.ip}",
          "status_retries": 10,
          "status_delay": 10,
          "ssh_wait_timeout": 300
        }' \
        /home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/ansible/playbooks/vm_template.yml

      # Capture the playbook's exit status
      ansible_exit_code=$?

      # Clean up the temporary inventory file
      rm -f $inventory_file

      # Handle playbook execution result
      if [ $ansible_exit_code -eq 0 ]; then
        echo "Ansible playbook executed successfully."
      else
        echo "Ansible playbook failed. Check logs for details." >&2
        exit $ansible_exit_code
      fi
    EOT
  }
}




data "http" "vm_template_status" {
  depends_on = [null_resource.attach_disk]
  url        = "https://${var.proxmox_host}:8006/api2/json/nodes/${var.proxmox_node}/qemu/${var.vm_template.id}/status/current"
  request_headers = {
    Authorization = "PVEAPIToken=${var.proxmox_api_user}!${var.proxmox_api_token_id}=${local.secret_proxmox_api_token}"
  }
}