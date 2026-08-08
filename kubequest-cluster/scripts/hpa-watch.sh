#!/usr/bin/env bash
#
# hpa-watch.sh — Vue temps réel de l'autoscaling (à ouvrir dans un 2e terminal
#                pendant que hpa-load.sh génère la charge).
#
# Affiche, rafraîchi toutes les 2 s :
#   - le HPA (CPU courant / cible, replicas courant / souhaité)
#   - le Deployment de l'app (replicas prêtes)
#   - la conso CPU par pod applicatif (via metrics-server)
#   - la liste des pods de l'app (on voit les nouveaux apparaître)
#
# À lancer sur node-1.

NS="laravel-app-prod"
SEL="app.kubernetes.io/instance=laravel-app"   # ne montre que les pods de l'app

CMD='
echo "════════════════════ AUTOSCALING — KubeQuest ════════════════════"
echo "── HPA (CPU courant/cible · replicas courant→souhaité) ──"
kubectl -n '"$NS"' get hpa laravel-app
echo
echo "── Deployment (souhaitées / à jour / prêtes) ──"
kubectl -n '"$NS"' get deploy laravel-app
echo
echo "── CPU par pod applicatif ──"
kubectl -n '"$NS"' top pods -l '"$SEL"' 2>/dev/null || echo "  (metrics en cours de collecte...)"
echo
echo "── Pods de l'\''application ──"
kubectl -n '"$NS"' get pods -l '"$SEL"' -o wide
'

if command -v watch >/dev/null 2>&1; then
  exec watch -t -n 2 "$CMD"
else
  # fallback si 'watch' absent
  while true; do clear; date '+%H:%M:%S'; bash -c "$CMD"; sleep 2; done
fi
