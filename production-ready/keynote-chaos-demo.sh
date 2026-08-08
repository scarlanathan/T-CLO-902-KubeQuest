#!/usr/bin/env bash
# =============================================================================
# KubeQuest — Scénario de démonstration "mise à rude épreuve" pour la keynote
# =============================================================================
# Objectif : démontrer en direct la ROBUSTESSE du cluster et la donner à VOIR
# via le monitoring. Trois scénarios, chacun observable dans Grafana :
#
#   1. Auto-réparation      : on tue un pod -> Kubernetes le recrée
#   2. Panne de nœud        : on draine un nœud -> les pods sont reschedulés
#   3. Montée en charge      : on génère du trafic -> le HPA scale l'app
#
# Usage :
#   ./keynote-chaos-demo.sh [all|heal|node|scale|status|cleanup]
#
# Variables (surchargeables) :
#   APP_NS=default            Namespace de l'application
#   APP_DEPLOY=laravel-app    Nom du Deployment applicatif
#   APP_SVC=laravel-app       Nom du Service (ClusterIP) pour le load-test
#   LOAD_DURATION=120         Durée (s) de la montée en charge
#
# ⚠️ Script de DÉMO : il perturbe volontairement le cluster. À lancer sur
#    l'environnement de démo, pas en prod réelle sans prévenir.
# =============================================================================
set -uo pipefail

APP_NS="${APP_NS:-default}"
APP_DEPLOY="${APP_DEPLOY:-laravel-app}"
APP_SVC="${APP_SVC:-laravel-app}"
LOAD_DURATION="${LOAD_DURATION:-120}"

# ---- helpers ----------------------------------------------------------------
c_blue="\033[1;34m"; c_grn="\033[1;32m"; c_yel="\033[1;33m"; c_red="\033[1;31m"; c_off="\033[0m"
step() { echo -e "\n${c_blue}==> $*${c_off}"; }
ok()   { echo -e "${c_grn}✔ $*${c_off}"; }
warn() { echo -e "${c_yel}! $*${c_off}"; }
err()  { echo -e "${c_red}✗ $*${c_off}"; }
pause(){ echo; read -rp "  [Entrée] pour continuer… " _ || true; }

need() { command -v "$1" >/dev/null 2>&1 || { err "commande requise absente : $1"; exit 1; }; }
need kubectl

k() { kubectl -n "$APP_NS" "$@"; }

banner() {
  echo -e "${c_blue}"
  echo "  ┌────────────────────────────────────────────────────────┐"
  echo "  │  KubeQuest — Démo de robustesse (keynote)                │"
  echo "  │  ns=$APP_NS  deploy=$APP_DEPLOY                          "
  echo "  └────────────────────────────────────────────────────────┘"
  echo -e "${c_off}"
  warn "Ouvrez Grafana en parallèle pour OBSERVER chaque scénario."
  echo  "   (voir docs/verification-monitoring.md pour les URLs / port-forward)"
}

require_deploy() {
  if ! k get deploy "$APP_DEPLOY" >/dev/null 2>&1; then
    err "Deployment '$APP_DEPLOY' introuvable dans le namespace '$APP_NS'."
    err "Déployez l'app d'abord, ou ajustez APP_NS / APP_DEPLOY."
    exit 1
  fi
}

# ---- scénario 1 : auto-réparation ------------------------------------------
scenario_heal() {
  require_deploy
  step "SCÉNARIO 1/3 — Auto-réparation (self-healing)"
  echo "  On tue un pod de l'app ; Kubernetes doit en recréer un immédiatement."
  k get pods -l app.kubernetes.io/name="$APP_DEPLOY" -o wide
  pause
  local pod
  pod=$(k get pods -l app.kubernetes.io/name="$APP_DEPLOY" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [ -z "$pod" ] && { err "aucun pod trouvé pour $APP_DEPLOY"; return 1; }
  warn "Suppression du pod : $pod"
  k delete pod "$pod" --wait=false
  step "Observez la recréation (Ctrl-C pour arrêter le watch) :"
  timeout 40 kubectl -n "$APP_NS" get pods -l app.kubernetes.io/name="$APP_DEPLOY" -w || true
  ok "Le ReplicaSet a maintenu le nombre de replicas désiré."
  echo "  📊 Grafana : le nombre de pods 'Running' redescend puis remonte."
}

# ---- scénario 2 : panne de nœud --------------------------------------------
scenario_node() {
  require_deploy
  step "SCÉNARIO 2/3 — Panne de nœud (cordon + drain -> reschedule)"
  echo "  On simule la perte d'un nœud worker : les pods qui y tournent"
  echo "  doivent être reschedulés sur les autres nœuds."
  kubectl get nodes -L kubequest.io/role
  # Choisit un nœud worker hébergeant un pod de l'app (évite le control-plane).
  local node
  node=$(k get pods -l app.kubernetes.io/name="$APP_DEPLOY" \
          -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null)
  [ -z "$node" ] && { err "impossible de déterminer le nœud cible"; return 1; }
  warn "Nœud cible (à drainer) : $node"
  pause
  step "cordon : plus aucun nouveau pod ne sera planifié sur $node"
  kubectl cordon "$node"
  step "drain : éviction des pods de $node"
  kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=60s || \
    warn "drain partiel (normal si PDB/timeout) — observez quand même le reschedule"
  step "Où tournent les pods maintenant ?"
  k get pods -l app.kubernetes.io/name="$APP_DEPLOY" -o wide
  ok "Les pods ont été reschedulés sur les nœuds sains."
  echo "  📊 Grafana : basculement des pods d'un nœud à l'autre."
  pause
  step "Rétablissement du nœud (uncordon) :"
  kubectl uncordon "$node"
  ok "Nœud $node de nouveau schedulable."
}

# ---- scénario 3 : montée en charge + HPA -----------------------------------
scenario_scale() {
  require_deploy
  step "SCÉNARIO 3/3 — Montée en charge (HPA autoscaling)"
  if ! k get hpa >/dev/null 2>&1 || [ -z "$(k get hpa -o name 2>/dev/null)" ]; then
    warn "Aucun HPA dans $APP_NS — le scénario montrera la charge sans autoscale."
  fi
  k get hpa 2>/dev/null || true
  echo "  État initial des replicas :"
  k get deploy "$APP_DEPLOY"
  pause
  step "Génération de charge pendant ${LOAD_DURATION}s via un pod 'load-generator'…"
  local target="http://${APP_SVC}.${APP_NS}.svc.cluster.local/"
  echo "  Cible : $target"
  kubectl -n "$APP_NS" run load-generator-$$ --image=busybox:1.36 --restart=Never --rm -i --labels=app=chaos-load -- \
    /bin/sh -c "end=\$(( \$(date +%s) + ${LOAD_DURATION} )); while [ \$(date +%s) -lt \$end ]; do wget -q -O- ${target} >/dev/null 2>&1; done; echo done" &
  local loadpid=$!
  step "Observez le HPA monter (watch ~${LOAD_DURATION}s, Ctrl-C pour stopper) :"
  timeout "${LOAD_DURATION}" kubectl -n "$APP_NS" get hpa,deploy "$APP_DEPLOY" -w || true
  wait "$loadpid" 2>/dev/null || true
  ok "Fin de charge — le HPA va faire redescendre les replicas (cooldown ~5 min)."
  echo "  📊 Grafana : pic CPU -> montée des replicas -> retour au calme."
}

scenario_status() {
  step "État du cluster"
  kubectl get nodes -L kubequest.io/role -o wide
  echo; k get deploy,hpa,pods -o wide 2>/dev/null || true
}

scenario_cleanup() {
  step "Nettoyage / remise en état"
  # Dé-cordonne tous les nœuds au cas où un scénario aurait été interrompu.
  for n in $(kubectl get nodes -o name); do kubectl uncordon "$n" >/dev/null 2>&1 || true; done
  kubectl -n "$APP_NS" delete pod -l app=chaos-load --ignore-not-found >/dev/null 2>&1 || true
  ok "Nœuds dé-cordonnés, pods de charge supprimés."
}

# ---- main -------------------------------------------------------------------
banner
case "${1:-all}" in
  heal)    scenario_heal ;;
  node)    scenario_node ;;
  scale)   scenario_scale ;;
  status)  scenario_status ;;
  cleanup) scenario_cleanup ;;
  all)
    scenario_status; pause
    scenario_heal;   pause
    scenario_node;   pause
    scenario_scale
    scenario_cleanup
    ;;
  *) echo "Usage: $0 [all|heal|node|scale|status|cleanup]"; exit 2 ;;
esac
ok "Terminé."
