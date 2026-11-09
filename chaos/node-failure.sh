#!/usr/bin/env bash
# Test de panne : coupe brutalement une VM du cluster (equivalent d'une
# coupure de courant), la laisse eteinte, la rallume, et mesure l'impact.
#
# Usage : ./node-failure.sh <vmid> <nom-du-noeud> [secondes_eteinte]
#   ex. : ./node-failure.sh 103 k3s-agent-2 420
#
# Prerequis : source ~/.homelab/proxmox.env (le compte Terraform a le droit
# VM.PowerMgmt sur le pool homelab, rien de plus), kubectl et le kubeconfig.
set -euo pipefail

VMID="${1:?vmid manquant}"
NODE="${2:?nom du noeud manquant}"
DOWN="${3:-420}"
PVE_NODE="${PVE_NODE:-bekono}"
URL="${URL:-http://whoami.192.168.11.201.nip.io/}"

cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
export KUBECONFIG="${KUBECONFIG:-$PWD/../kubeconfig}"
: "${PROXMOX_VE_API_TOKEN:?source ~/.homelab/proxmox.env}"

OUT="results/$(date +%Y-%m-%d_%H%M)-${NODE}"
mkdir -p "$OUT"
log() { echo "$(date +%s) $*" | tee -a "$OUT/events.log"; }

pve_power() {
  curl -sk -o /dev/null -w "%{http_code}" -X POST \
    -H "Authorization: PVEAPIToken=${PROXMOX_VE_API_TOKEN}" \
    "${PROXMOX_VE_ENDPOINT}api2/json/nodes/${PVE_NODE}/qemu/${VMID}/status/$1"
}

# Sonde HTTP : une requete par seconde sur l'appli de demo
probe_http() {
  while true; do
    ts=$(date +%s)
    body=$(curl -s -m 2 -w "\n%{http_code}" "$URL" 2>/dev/null || printf "\n000")
    code=$(tail -1 <<<"$body")
    host=$(grep -m1 '^Hostname:' <<<"$body" | awk '{print $2}' || true)
    echo "$ts,$code,${host:--}" >>"$OUT/http.csv"
    sleep 1
  done
}

# Sonde Kubernetes : etat du noeud et des pods concernes toutes les 5 s
probe_k8s() {
  while true; do
    ts=$(date +%s)
    node=$(kubectl get node "$NODE" --no-headers 2>/dev/null | awk '{print $2}' || echo "?")
    pods=$(kubectl get pods -A -o wide --no-headers 2>/dev/null |
      awk '$2 ~ /^(whoami|prometheus-monitoring|monitoring-kube-state|monitoring-kube-prometheus-operator)/ {printf "%s=%s@%s ", $2, $4, $(NF-2)}' || true)
    # NODE est lu depuis la fin de ligne : la colonne RESTARTS peut contenir
    # des espaces ("1 (64s ago)") et decaler les colonnes suivantes
    echo "$ts node=$node $pods" >>"$OUT/k8s.log"
    sleep 5
  done
}

echo "ts,code,pod" >"$OUT/http.csv"
probe_http & P1=$!
probe_k8s & P2=$!
trap 'kill $P1 $P2 2>/dev/null || true' EXIT

log "BASELINE debut (60 s)"
sleep 60

log "PANNE arret brutal de la VM $VMID ($NODE) -> HTTP $(pve_power stop)"
sleep "$DOWN"

log "REPRISE demarrage de la VM $VMID -> HTTP $(pve_power start)"
until kubectl get node "$NODE" --no-headers 2>/dev/null | grep -q ' Ready'; do sleep 2; done
log "NODE_READY $NODE de nouveau Ready"

log "OBSERVATION apres reprise (120 s)"
sleep 120
log "FIN"

kill $P1 $P2 2>/dev/null || true
python3 summarize.py "$OUT" | tee "$OUT/summary.txt"
