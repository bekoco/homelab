# Tests de panne

`node-failure.sh` coupe brutalement une VM du cluster via l'API Proxmox (equivalent d'une coupure de courant), la laisse eteinte, la rallume, et mesure en continu :
- la disponibilite de l'application de demo (1 requete HTTP par seconde) ;
- l'etat du noeud et le placement des pods (toutes les 5 s).

```bash
source ~/.homelab/proxmox.env
./chaos/node-failure.sh 103 k3s-agent-2 420
```

Les journaux bruts et le resume sont enregistres dans `chaos/results/`.

## Test du 2026-11-09 : perte de k3s-agent-2

### Hypotheses (ecrites avant le test)
| # | Hypothese |
|---|---|
| H1 | `whoami` reste disponible (2 replicas sur 2 noeuds), avec au pire quelques erreurs le temps que Kubernetes retire le pod mort du Service |
| H2 | Le noeud passe `NotReady` en moins d'une minute |
| H3 | Les pods du noeud mort sont recrees ailleurs apres environ 5 min (tolerance `unreachable` par defaut de 300 s) |
| H4 | **Prometheus ne peut pas etre recree ailleurs** : son volume `local-path` est attache a k3s-agent-2. La supervision est donc aveugle pendant la panne, et aucune alerte ne signale la panne elle-meme |
| H5 | Au redemarrage, le noeud rejoint le cluster et tout revient a la normale sans intervention |

Resultats et analyse : voir le [post-mortem](../docs/postmortem-2026-11-09-perte-k3s-agent-2.md).

## Test du 2026-11-09 (13:56) : meme scenario apres corrections
Verification des actions du post-mortem (Traefik en 2 replicas, reessai rapide, tolerance de 30 s, alerte homme mort) : 6 echecs au lieu de 12, pod recree a T+81 s au lieu de T+351 s. Details dans le post-mortem.

```bash
python3 chaos/plot.py docs/images/chaos-availability.svg \
  "Test 1 (avant)" chaos/results/2026-11-09_1234-k3s-agent-2 \
  "Test 2 (apres)" chaos/results/2026-11-09_1355-k3s-agent-2
```
