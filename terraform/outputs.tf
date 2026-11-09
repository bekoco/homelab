output "nodes" {
  description = "VMs du cluster : ID Proxmox et IP"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k3s :
    name => { vm_id = vm.vm_id, ip = var.nodes[name].ip }
  }
}
