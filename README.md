# Homelab : infrastructure d'entreprise as code

Infrastructure complète d'une entreprise fictive, construite sur un serveur **Proxmox VE** et entièrement décrite en code : on peut tout recréer de zéro avec quelques commandes.

| Projet | Contenu | État |
|---|---|---|
| 0. Socle Proxmox | Sauvegardes planifiées, template Debian 12 cloud-init, compte Terraform à privilèges minimaux, bridge VLAN-aware | ✅ |
| **1. Plateforme Kubernetes** | **Terraform crée les VMs, Ansible installe k3s, ArgoCD déploie en GitOps** (supervision à venir) | 🚧 |
| 2. Réseau automatisé | Fabric spine-leaf BGP/EVPN (containerlab), NetBox, Ansible, tests en CI | ⏳ |
| 3. Sécurité hybride | OPNsense, VLANs, WireGuard, Suricata, Wazuh | ⏳ |

## Projet 1 : cluster k3s

```
 PC (WSL2)                        Proxmox VE "bekono" (pool homelab)
┌────────────┐  API (token)     ┌──────────────────────────────────────┐
│ Terraform  │ ───────────────▶ │ template 9000 (Debian 12 cloud-init) │
│            │                  │      │ clone                         │
│ Ansible    │ ── SSH ────────▶ │  k3s-server   192.168.11.201         │
│            │                  │  k3s-agent-1  192.168.11.202         │
│ kubectl    │ ── :6443 ──────▶ │  k3s-agent-2  192.168.11.203         │
└────────────┘                  └──────────────────────────────────────┘
```

### Choix techniques
- **Compte de service dédié** : Terraform utilise `terraform@pve`, qui n'a de droits d'écriture que sur le pool `homelab`. Une erreur ne peut pas toucher aux autres VMs du serveur.
- **Aucun secret dans le dépôt** : le token API est chargé depuis une variable d'environnement, et le kubeconfig, l'état Terraform et l'inventaire sont ignorés par Git.
- **Inventaire Ansible généré par Terraform** : une seule source de vérité pour les IPs.
- **CPU `x86-64-v2-AES`** : le serveur (i7-2600, 2011) ne gère pas AVX2/x86-64-v3.
- **Clé SSH dédiée au lab**, distincte de la clé d'administration.

### Déployer
Depuis WSL :
```bash
source ~/.homelab/proxmox.env          # voir terraform/proxmox.env.example
cd terraform && terraform init && terraform apply
cd ../ansible && ./run.sh
export KUBECONFIG=$PWD/../kubeconfig && kubectl get nodes
```

### GitOps avec ArgoCD
ArgoCD surveille ce dépôt : **Git est la seule source de vérité**. Un `git push` suffit pour déployer, et une modification manuelle sur le cluster est automatiquement annulée (*self-heal*).

```
k8s/bootstrap/root-app.yaml   appliqué une fois : « app of apps » qui surveille k8s/apps
k8s/apps/                      une Application ArgoCD par service
k8s/argocd/                    configuration d'ArgoCD (gérée par ArgoCD lui-même)
k8s/workloads/whoami/          application de démonstration
```

```bash
cd ansible && ./run.sh argocd.yml      # installe ArgoCD et l'application racine
```
- Interface ArgoCD : http://argocd.192.168.11.201.nip.io
- Application de démo : http://whoami.192.168.11.201.nip.io

### Tout détruire
```bash
cd terraform && terraform destroy
```
