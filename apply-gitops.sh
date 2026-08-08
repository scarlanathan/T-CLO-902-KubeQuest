#!/bin/bash

###############################################################################
# KubeQuest Groupe 50 - Script GitOps (Kustomize)
# Ce script déploie TOUT en utilisant Kustomize (GitOps)
# Utilisation : ./apply-gitops.sh
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Vérifier que kustomize est installé
check_prereqs() {
    log_info "Vérification des prérequis..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé"
        exit 1
    fi

    # Vérifier si kustomize est installé, sinon essayer kubectl apply -k
    if command -v kustomize &> /dev/null; then
        KUSTOMIZE_CMD="kustomize"
        log_success "kustomize trouvé"
    elif kubectl apply --help | grep -q "kustomize"; then
        KUSTOMIZE_CMD="kubectl apply -k"
        log_success "kubectl avec support kustomize trouvé"
    else
        log_error "Ni kustomize ni kubectl avec kustomize n'est installé"
        log_error "Installez kustomize : brew install kustomize"
        exit 1
    fi

    # Vérifier la connexion au cluster
    if ! kubectl get nodes &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi

    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
    log_success "Connecté au cluster avec $NODE_COUNT nœud(s)"
}

# Déployer l'infrastructure
deploy_infrastructure() {
    echo ""
    log_info "=========================================="
    log_info "DÉPLOIEMENT INFRASTRUCTURE (GitOps)"
    log_info "=========================================="
    echo ""

    local infra_dir="./kubequest-cluster/gitops/infrastructure/base"

    if [ ! -d "$infra_dir" ]; then
        log_error "Répertoire GitOps infrastructure non trouvé : $infra_dir"
        exit 1
    fi

    log_info "Application des manifests Kubernetes depuis :"
    log_info "  $infra_dir"
    echo ""

    if [ "$KUSTOMIZE_CMD" = "kustomize" ]; then
        kustomize build "$infra_dir" | kubectl apply -f -
    else
        kubectl apply -k "$infra_dir"
    fi

    log_success "Infrastructure déployée"

    # Attendre que nginx-ingress soit prêt
    log_info "Attente de nginx-ingress controller..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=ingress-nginx \
        -n ingress-nginx --timeout=300s

    log_success "Infrastructure prête"
}

# Déployer les applications
deploy_apps() {
    echo ""
    log_info "=========================================="
    log_info "DÉPLOIEMENT APPLICATIONS (GitOps)"
    log_info "=========================================="
    echo ""

    local apps_dir="./kubequest-cluster/gitops/apps"

    if [ ! -d "$apps_dir" ]; then
        log_error "Répertoire GitOps apps non trouvé : $apps_dir"
        exit 1
    fi

    # Déployer toutes les applications dans le dossier apps
    for app_path in "$apps_dir"/*/base; do
        if [ -d "$app_path" ]; then
            app_name=$(basename $(dirname "$app_path"))
            log_info "Déploiement de $app_name depuis :"
            log_info "  $app_path"

            if [ "$KUSTOMIZE_CMD" = "kustomize" ]; then
                kustomize build "$app_path" | kubectl apply -f -
            else
                kubectl apply -k "$app_path"
            fi

            log_success "$app_name déployé"
        fi
    done

    log_success "Toutes les applications déployées"
}

# Vérifier le déploiement
verify_deployment() {
    echo ""
    log_info "=========================================="
    log_info "VÉRIFICATION DU DÉPLOIEMENT"
    log_info "=========================================="
    echo ""

    log_info "=== Nœuds ==="
    kubectl get nodes
    echo ""

    log_info "=== Pods Ingress ==="
    kubectl get pods -n ingress-nginx
    echo ""

    log_info "=== Pods Monitoring ==="
    kubectl get pods -n monitoring -l 'app in (prometheus,grafana,loki)'
    echo ""

    log_info "=== Pods Laravel ==="
    kubectl get pods -n laravel-app
    echo ""

    log_info "=== Ingress ==="
    kubectl get ingress -A
    echo ""

    log_success "=== DÉPLOIEMENT GITOPS TERMINÉ ==="
}

# Afficher les informations d'accès
show_access_info() {
    echo ""
    echo "=========================================="
    echo "🌐 ACCÈS AUX APPLICATIONS"
    echo "=========================================="
    echo ""
    echo "📱 Laravel Application :"
    echo "   URL : http://app.kubequest.local:32222"
    echo "   (Ajoutez '3.77.235.74  app.kubequest.local' à votre /etc/hosts)"
    echo ""
    echo "📊 Kubernetes Dashboard :"
    echo "   URL : http://dashboard.kubequest.local:32222"
    echo "   Token : kubectl -n kubernetes-dashboard get secret admin-user-token -o jsonpath='{.data.token}' | base64 -d"
    echo ""
    echo "📈 Grafana :"
    echo "   URL : http://3.120.183.206:3000"
    echo "   Password : kubectl -n monitoring get secret kube-prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
    echo ""
    echo "=========================================="
    echo ""
}

# Main
main() {
    echo "=========================================="
    echo "🚀 KUBEQUEST - DÉPLOIEMENT GITOPS"
    echo "=========================================="
    echo ""
    log_info "Ce script déploie TOUT l'infrastructure et les applications"
    log_info "en utilisant les manifests Kustomize (GitOps)"
    echo ""

    check_prereqs
    deploy_infrastructure
    deploy_apps
    verify_deployment
    show_access_info

    log_success "GitOps deployment completed!"
    echo ""
    log_info "Prochaine étape :"
    log_info "  1. Tester l'application : curl http://app.kubequest.local:32222"
    log_info "  2. Lancer le test de charge : ./load-test.sh"
    log_info "  3. Voir les logs : kubectl logs -n laravel-app -l app.kubernetes.io/name=laravel-app -f"
}

# Exécuter
main "$@"
