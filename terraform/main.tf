locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "proxmox_virtual_environment_vm" "k3s" {
  for_each = var.nodes

  name        = each.key
  description = "Noeud k3s (${each.value.role}) - gere par Terraform, ne pas modifier a la main"
  node_name   = var.proxmox_node
  pool_id     = var.pool
  tags        = ["homelab", "k3s", each.value.role]
  on_boot     = true

  # Pas encore d'agent QEMU dans l'image cloud : on force l'arret au destroy
  stop_on_destroy = true

  clone {
    vm_id = var.template_id
    full  = true
  }

  # L'agent QEMU est installe ensuite par Ansible ; Terraform n'en depend pas
  agent {
    enabled = false
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES" # le CPU du serveur (i7-2600) ne gere pas x86-64-v3
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = each.value.disk
    discard      = "on"
    ssd          = true
    iothread     = true
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.datastore

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = [local.ssh_public_key]
    }
  }
}

# Inventaire Ansible genere automatiquement a partir des VMs creees
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tftpl", {
    servers = { for k, v in var.nodes : k => v.ip if v.role == "server" }
    agents  = { for k, v in var.nodes : k => v.ip if v.role == "agent" }
    user    = var.vm_user
    ssh_key = trimsuffix(var.ssh_public_key_path, ".pub")
  })
}
