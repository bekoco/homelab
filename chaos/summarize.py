"""Resume un test de panne a partir des journaux produits par node-failure.sh."""
import csv
import re
import sys
from pathlib import Path

out = Path(sys.argv[1])

events = {}
for line in (out / "events.log").read_text().splitlines():
    ts, label = line.split(" ", 2)[:2]
    events.setdefault(label, int(ts))
t0 = events["PANNE"]

def rel(ts):
    return f"T{'+' if ts >= t0 else '-'}{abs(ts - t0)}s"

# --- HTTP
rows = list(csv.DictReader((out / "http.csv").open()))
total = len(rows)
fails = [r for r in rows if r["code"] != "200"]
windows, start, prev = [], None, None
for r in rows:
    ts, ok = int(r["ts"]), r["code"] == "200"
    if not ok and start is None:
        start = ts
    if ok and start is not None:
        windows.append((start, prev))
        start = None
    prev = ts
if start is not None:
    windows.append((start, prev))

print(f"=== Test de panne : {out.name}")
print(f"Requetes HTTP : {total}, en echec : {len(fails)} "
      f"({100 * len(fails) / max(total, 1):.2f} % de disponibilite perdue)")
for a, b in windows:
    print(f"  coupure HTTP de {rel(a)} a {rel(b)} ({b - a + 1} s)")

# --- Kubernetes
first = {}
for line in (out / "k8s.log").read_text().splitlines():
    ts = int(line.split()[0])
    m = re.search(r"node=(\S+)", line)
    state = m.group(1) if m else "?"
    if ts > t0:
        if state == "NotReady":
            first.setdefault("node_notready", ts)
        if "node_notready" in first and state == "Ready":
            first.setdefault("node_ready", ts)
    for pod, status, node in re.findall(r"(\S+?)=(\S+?)@(\S+)", line):
        if ts > t0 and status in ("Terminating", "Unknown"):
            first.setdefault(f"evict:{pod}", ts)

print("Chronologie :")
for label in ("BASELINE", "PANNE", "REPRISE", "NODE_READY", "FIN"):
    if label in events:
        print(f"  {rel(events[label]):>8}  {label}")
for key, ts in sorted(first.items(), key=lambda kv: kv[1]):
    print(f"  {rel(ts):>8}  {key}")

print("Etat final des pods :")
last = (out / "k8s.log").read_text().splitlines()[-1]
for pod, status, node in re.findall(r"(\S+?)=(\S+?)@(\S+)", last):
    print(f"  {pod:<60} {status:<10} {node}")
