nodes = {
  "k3s-server"  = { role = "server", ip = "192.168.11.201", cores = 2, memory = 6144, disk = 20 }
  "k3s-agent-1" = { role = "agent", ip = "192.168.11.202", cores = 2, memory = 3072, disk = 20 }
  "k3s-agent-2" = { role = "agent", ip = "192.168.11.203", cores = 2, memory = 3072, disk = 20 }
}
