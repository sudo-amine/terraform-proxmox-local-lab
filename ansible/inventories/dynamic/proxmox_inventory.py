#!/usr/bin/env python3

import os
from proxmoxer import ProxmoxAPI

# Proxmox API credentials
PROXMOX_HOST = os.getenv('PROXMOX_HOST', '192.168.1.100')  # Replace with your Proxmox host
PROXMOX_USER = os.getenv('PROXMOX_USER', 'root@pam')       # Replace with your Proxmox user
PROXMOX_PASS = os.getenv('PROXMOX_PASS', 'your-password')  # Replace with your Proxmox password
PROXMOX_VERIFY_SSL = os.getenv('PROXMOX_VERIFY_SSL', False)

# Static variables to replace with your Terraform variables
NETWORK_GATEWAY_SUBNET = "192.168.1.0/24"
CONTROL_PLANE_PREFIX = "cp-node"
WORKER_PREFIX = "worker-node"
CONTROL_PLANE_USER = "root"
WORKER_USER = "root"
SSH_PRIVATE_KEY_PATH = "~/.ssh/id_rsa"
PROXMOX_NODE = "proxmox-node1"
PROXMOX_API_USER = "root@pam"
PROXMOX_API_TOKEN_ID = "terraform-token"

# Control plane and worker IP ranges
CONTROL_PLANE_IP_START = 100
WORKER_IP_START = 200

def generate_inventory():
    proxmox = ProxmoxAPI(PROXMOX_HOST, user=PROXMOX_USER, password=PROXMOX_PASS, verify_ssl=PROXMOX_VERIFY_SSL)

    control_plane_nodes = []
    worker_nodes = []
    control_plane_index = 0
    worker_index = 0

    for node in proxmox.nodes.get():
        for vm in proxmox.nodes(node['node']).qemu.get():
            if vm.get("status") == "running":
                vm_id = vm['vmid']
                vm_name = vm['name']
                vm_config = proxmox.nodes(node['node']).qemu(vm_id).config.get()
                vm_ip = vm_config.get('net0', '').split('=')[1].split(',')[0]  # Extract IP from net0

                if "control_plane" in vm_name.lower():
                    control_plane_nodes.append({
                        "index": control_plane_index,
                        "name": vm_name,
                        "ip": f"{NETWORK_GATEWAY_SUBNET.split('/')[0].rsplit('.', 1)[0]}.{CONTROL_PLANE_IP_START + control_plane_index}",
                        "vm_id": vm_id
                    })
                    control_plane_index += 1
                elif "worker" in vm_name.lower():
                    worker_nodes.append({
                        "index": worker_index,
                        "name": vm_name,
                        "ip": f"{NETWORK_GATEWAY_SUBNET.split('/')[0].rsplit('.', 1)[0]}.{WORKER_IP_START + worker_index}",
                        "vm_id": vm_id
                    })
                    worker_index += 1

    # Generate the Terraform-compatible inventory
    inventory_content = "# Kubernetes Cluster Inventory\n\n"
    inventory_content += "[other_cp_nodes]\n\n"
    for node in control_plane_nodes[1:]:
        inventory_content += f"{CONTROL_PLANE_PREFIX}{node['index'] + 1} ansible_host={node['ip']} ansible_user={CONTROL_PLANE_USER} ansible_ssh_private_key_file={SSH_PRIVATE_KEY_PATH} ansible_become=true vm_id={node['vm_id']}\n"

    inventory_content += "\n[worker_nodes]\n\n"
    for node in worker_nodes:
        inventory_content += f"{WORKER_PREFIX}{node['index'] + 1} ansible_host={node['ip']} ansible_user={WORKER_USER} ansible_ssh_private_key_file={SSH_PRIVATE_KEY_PATH} ansible_become=true vm_id={node['vm_id']}\n"

    inventory_content += "\n[first_cp_node]\n\n"
    if control_plane_nodes:
        first_node = control_plane_nodes[0]
        inventory_content += f"{CONTROL_PLANE_PREFIX}{first_node['index'] + 1} ansible_host={first_node['ip']} ansible_user={CONTROL_PLANE_USER} ansible_ssh_private_key_file={SSH_PRIVATE_KEY_PATH} ansible_become=true vm_id={first_node['vm_id']}\n"

    inventory_content += "\n[all:vars]\n"
    inventory_content += f"proxmox_node={PROXMOX_NODE}\n"
    inventory_content += f"proxmox_host={PROXMOX_HOST}\n"
    inventory_content += f"proxmox_api_user={PROXMOX_API_USER}\n"
    inventory_content += f"proxmox_api_token_id={PROXMOX_API_TOKEN_ID}\n"
    inventory_content += 'pod_network_cidr="10.244.0.0/16"\n'
    inventory_content += 'control_plane_endpoint="control-plane.local"\n'

    return inventory_content

def main():
    inventory = generate_inventory()
    output_path = "/home/sudo-amine/terraform-k8s-cluster/terraform-proxmox-local-lab/k8s_nodes/ansible/inventory/k8s_inventory.ini"

    # Write the inventory to the file
    with open(output_path, "w") as f:
        f.write(inventory)

    print(f"Inventory written to {output_path}")

if __name__ == "__main__":
    main()
