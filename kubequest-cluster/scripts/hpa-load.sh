#!/usr/bin/env bash
#
# hpa-load.sh — Génère de la charge sur l'application Laravel pour déclencher
#               l'autoscaling (HPA), puis l'arrête pour observer le scale-down.
#
# La charge est produite DANS le cluster (Deployment busybox qui martèle le
# Service en boucle) : aucune dépendance à un DNS/ingress externe, et le
# générateur est conforme à la policy OPA/Gatekeeper (label + resources + non-root).
#
# Usage :
#   ./hpa-load.sh start [replicas] [workers]   # démarre la charge (défaut 3 / 12)
#   ./hpa-load.sh stop                         # arrête la charge (scale-down)
#   ./hpa-load.sh status                       # état HPA + pods
#
# À lancer sur node-1 (là où kubectl est disponible).
# Astuce : ouvrir « ./hpa-watch.sh » dans un 2e terminal pour voir le scaling en direct.

set -euo pipefail

NS="laravel-app-prod"
APP_DEPLOY="laravel-app"
HPA="laravel-app"
LOADGEN="hpa-loadgen"
TARGET="http://laravel-app.laravel-app-prod.svc.cluster.local/"

ACTION="${1:-start}"
REPLICAS="${2:-3}"     # nb de pods générateurs
WORKERS="${3:-12}"     # nb de boucles de requêtes parallèles PAR pod

# OPA/Gatekeeper impose >= 2 replicas sur les Deployments
if [ "$REPLICAS" -lt 2 ]; then REPLICAS=2; fi

status() {
  echo "── HPA ────────────────────────────────────────────"
  kubectl -n "$NS" get hpa "$HPA" 2>/dev/null || true
  echo "── Deployment application ─────────────────────────"
  kubectl -n "$NS" get deploy "$APP_DEPLOY" 2>/dev/null || true
  echo "── Générateur de charge ───────────────────────────"
  kubectl -n "$NS" get deploy "$LOADGEN" 2>/dev/null || echo "  (aucun — charge à l'arrêt)"
}

case "$ACTION" in
  stop|down|clean|arret)
    kubectl -n "$NS" delete deployment "$LOADGEN" --ignore-not-found
    MIN=$(kubectl -n "$NS" get hpa "$HPA" -o jsonpath='{.spec.minReplicas}' 2>/dev/null || echo 2)
    echo ""
    echo "✅ Charge arrêtée. Le HPA va redescendre vers $MIN pods."
    echo "   (Le scale-down est volontairement lent : ~3-5 min, fenêtre de stabilisation K8s.)"
    exit 0
    ;;
  status|etat)
    status; exit 0
    ;;
esac

# ── start ────────────────────────────────────────────────
echo "==================================================="
echo " Test d'autoscaling — KubeQuest"
echo "==================================================="
echo " Cible      : $APP_DEPLOY (ns $NS)"
echo " HPA        : CPU 70% · min/max = $(kubectl -n "$NS" get hpa "$HPA" -o jsonpath='{.spec.minReplicas}/{.spec.maxReplicas}')"
echo " Charge     : $REPLICAS pods × $WORKERS boucles = $((REPLICAS * WORKERS)) requêtes en parallèle"
echo "==================================================="
echo ""
echo "État AVANT charge :"
status
echo ""
echo "🚀 Démarrage du générateur de charge..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $LOADGEN
  namespace: $NS
  labels:
    app.kubernetes.io/name: $LOADGEN
spec:
  replicas: $REPLICAS
  selector:
    matchLabels:
      app.kubernetes.io/name: $LOADGEN
  template:
    metadata:
      labels:
        app.kubernetes.io/name: $LOADGEN
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: loadgen
        image: busybox:1.36
        env:
        - name: WORKERS
          value: "$WORKERS"
        - name: TARGET
          value: "$TARGET"
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "loadgen: \$WORKERS boucles vers \$TARGET"
          i=0
          while [ "\$i" -lt "\$WORKERS" ]; do
            ( while true; do wget -q -O /dev/null "\$TARGET" 2>/dev/null; done ) &
            i=\$((i + 1))
          done
          wait
        resources:
          requests:
            cpu: 50m
            memory: 16Mi
          limits:
            cpu: 500m
            memory: 64Mi
EOF

echo ""
echo "✅ Charge lancée."
echo ""
echo "👀 Observer le scaling :"
echo "   • Terminal      : ./hpa-watch.sh"
echo "   • Grafana       : voir GRAFANA-AUTOSCALING.md"
echo "   • Arrêter       : ./hpa-load.sh stop"
echo ""
echo "⏱️  Le HPA réévalue toutes les ~15 s. Les pods montent en général vers"
echo "    la limite (10) en 1 à 2 minutes. Laisse tourner puis fais 'stop'."
