#!/bin/bash

###############################################################################
# KubeQuest Groupe 50 - Démonstration Rollback
# Ce script montre un déploiement cassé et comment revenir en arrière
# Utilisation : ./rollback-demo.sh
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Attendre que les pods soient ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-120}

    log_info "Attente des pods dans namespace '$namespace' (timeout: ${timeout}s)..."

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local not_ready=$(kubectl get pods -n "$namespace" --no-headers | grep -v "1/1\|2/2\|3/3" | wc -l | tr -d ' ')

        if [ "$not_ready" -eq 0 ]; then
            log_success "Tous les pods sont ready"
            return 0
        fi

        echo -n "."
        sleep 2
        elapsed=$((elapsed + 2))
    done

    echo ""
    log_warning "Timeout atteint, certains pods ne sont toujours pas ready"
    return 1
}

# Tester l'application
test_app() {
    local expected_content=$1

    log_info "Test de l'application..."

    local response=$(curl -s -H "Host: app.kubequest.local" http://3.77.235.74:32222)

    if echo "$response" | grep -q "$expected_content"; then
        log_success "Application répond correctement"
        return 0
    else
        log_error "Application ne répond pas comme attendu"
        echo "Contenu reçu :"
        echo "$response" | head -20
        return 1
    fi
}

# État initial
show_initial_state() {
    echo ""
    log_info "=== ÉTAT INITIAL ==="
    echo ""
    log_info "Releases Helm :"
    helm list -n laravel
    echo ""
    log_info "Pods Laravel :"
    kubectl get pods -n laravel -L app.kubernetes.io/version
    echo ""
    log_info "Test de l'application :"
    test_app "Hello world sample app" || true
    echo ""
}

# Créer une version "broken"
create_broken_version() {
    log_info "Création d'une version 'broken' pour la démo..."

    # Créer un values file pour la version broken
    cat > /tmp/laravel-broken-values.yaml <<EOF
image:
  repository: nginx
  tag: "alpine"
  pullPolicy: IfNotPresent

replicaCount: 2

resources:
  limits:
    cpu: "100m"
    memory: "128Mi"
  requests:
    cpu: "50m"
    memory: "64Mi"

ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: "/"
  hosts:
    - host: app.kubequest.local
      paths:
        - path: /
          pathType: Prefix
EOF

    log_success "Values 'broken' créé"
}

# Déployer la version broken
deploy_broken_version() {
    echo ""
    log_warning "======================================================"
    log_warning "DÉPLOIEMENT D'UNE VERSION CASSÉE (BROKEN)"
    log_warning "======================================================"
    echo ""
    log_info "Upgrade Helm avec la version broken..."

    helm upgrade laravel-app ./kubequest-cluster/laravel-app \
        --namespace laravel \
        --values /tmp/laravel-broken-values.yaml \
        --wait --timeout 120s

    echo ""
    log_info "État après déploiement broken :"
    kubectl get pods -n laravel

    echo ""
    log_warning "Test de l'application (doit échouer)..."
    if test_app "Welcome to nginx"; then
        log_warning "La version broken répond (page nginx par défaut)"
    else
        log_error "L'application ne répond pas du tout"
    fi

    log_warning "Cette version n'est PAS l'application Laravel !"
}

# Rollback
do_rollback() {
    echo ""
    log_info "======================================================"
    log_info "ROLLBACK vers la version stable"
    log_info "======================================================"
    echo ""

    log_info "Helm rollback en cours..."
    helm rollback laravel-app -n laravel --wait --timeout 120s

    log_success "Rollback effectué"

    echo ""
    log_info "État après rollback :"
    kubectl get pods -n laravel

    wait_for_pods "laravel" 60

    echo ""
    log_info "Test de l'application après rollback :"
    test_app "Hello world sample app"

    log_success "Rollback réussi ! L'application fonctionne à nouveau"
}

# Afficher l'historique
show_history() {
    echo ""
    log_info "=== HISTORIQUE DES RELEASES ==="
    echo ""
    helm history laravel-app -n laravel
    echo ""
}

# Main
main() {
    echo "=========================================="
    echo "🎭 KUBEQUEST - DÉMO ROLLBACK"
    echo "=========================================="
    echo ""
    log_warning "Ce script va :"
    log_warning "  1. Vérifier l'état actuel (version stable)"
    log_warning "  2. Déployer une version 'broken' (nginx au lieu de Laravel)"
    log_warning "  3. Montrer que l'application est cassée"
    log_warning "  4. Faire un rollback vers la version stable"
    log_warning "  5. Vérifier que l'application fonctionne à nouveau"
    echo ""
    log_info "Appuyez sur Entrée pour continuer..."
    read

    show_initial_state
    create_broken_version

    echo ""
    log_info "Appuyez sur Entrée pour déployer la version broken..."
    read
    deploy_broken_version

    echo ""
    log_info "Appuyez sur Entrée pour faire le rollback..."
    read
    do_rollback

    show_history

    echo ""
    log_success "=== DÉMO TERMINÉE ==="
    echo ""
    log_info "Ce que vous avez vu :"
    log_info "  1. Helm permet de revenir instantanément à une version précédente"
    log_info "  2. Le rollback est automatique si le deployment échoue"
    log_info "  3. Zéro-downtime : pendant le rollback, l'application reste dispo"
    echo ""
}

# Nettoyer à la sortie
trap "rm -f /tmp/laravel-broken-values.yaml" EXIT

# Exécuter
main "$@"
