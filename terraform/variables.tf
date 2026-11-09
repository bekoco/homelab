variable "proxmox_node" {
  description = "Nom du noeud Proxmox"
  type        = string
  default     = "bekono"
}

variable "pool" {
  description = "Pool Proxmox du lab (le compte Terraform n'a des droits que sur ce pool)"
  type        = string
  default     = "homelab"
}

variable "template_id" {
  description = "ID du template Debian 12 cloud-init"
  type        = number
  default     = 9000
}

variable "datastore" {
  description = "Stockage des disques des VMs"
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Bridge reseau Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN du lab (null = reseau local actuel ; a renseigner au projet 3 avec OPNsense)"
  type        = number
  default     = null
}

variable "gateway" {
  description = "Passerelle du reseau"
  type        = string
  default     = "192.168.11.1"
}

variable "dns_servers" {
  description = "Serveurs DNS des VMs"
  type        = list(string)
  default     = ["192.168.11.1", "1.1.1.1"]
}

variable "vm_user" {
  description = "Utilisateur cree par cloud-init"
  type        = string
  default     = "debian"
}

variable "ssh_public_key_path" {
  description = "Cle publique SSH dediee au lab"
  type        = string
  default     = "~/.ssh/homelab_ed25519.pub"
}

variable "nodes" {
  description = "Noeuds du cluster k3s"
  type = map(object({
    role   = string # server ou agent
    ip     = string
    cores  = number
    memory = number # Mo
    disk   = number # Go
  }))
}
