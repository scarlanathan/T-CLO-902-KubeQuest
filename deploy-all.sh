#!/bin/bash

###############################################################################
# KubeQuest Groupe 50 - Script de Déploiement Complet
# Ce script déploie TOUTE l'infrastructure et les applications
# Utilisation : ./deploy-all.sh
###############################################################################

set -e  # Arrêter si une commande échoue

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonctions de log
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Vérifications
check_prereqs() {
    log_info "Vérification des prérequis..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé"
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        log_error "helm n'est pas installé"
        exit 1
    fi

    # Vérifier la connexion au cluster
    if ! kubectl get nodes &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        log_error "Assurez-vous d'être connecté au control plane (node-1)"
        exit 1
    fi

    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
    log_success "Connecté au cluster avec $NODE_COUNT nœud(s)"

    # Afficher les nœuds
    kubectl get nodes
}

# Déployer l'infrastructure de base
deploy_infrastructure() {
    log_info "Déploiement de l'infrastructure de base..."

    # nginx-ingress controller
    log_info "Installation de nginx-ingress controller..."
    if helm list -n ingress-nginx | grep -q ingress-nginx; then
        log_warning "nginx-ingress déjà installé, upgrade..."
        helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --set controller.nodeSelector."node-role\.kubernetes\.io/ingress"=ingress
    else
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update
        helm install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx --create-namespace \
            --set controller.nodeSelector."node-role\.kubernetes\.io/ingress"=ingress
    fi

    # Attendre que ingress-nginx soit prêt
    log_info "Attente de nginx-ingress controller (max 5min)..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=ingress-nginx \
        -n ingress-nginx --timeout=300s

    log_success "nginx-ingress controller est prêt"
}

# Déployer le monitoring
deploy_monitoring() {
    log_info "Déploiement de la stack monitoring..."

    if helm list -n monitoring | grep -q kube-prometheus; then
        log_warning "kube-prometheus déjà installé, upgrade..."
        helm upgrade kube-prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --set prometheus.prometheusSpec.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
            --set grafana.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
            --set alertmanager.alertmanagerSpec.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring
    else
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm install kube-prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring --create-namespace \
            --set prometheus.prometheusSpec.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
            --set grafana.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
            --set alertmanager.alertmanagerSpec.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring
    fi

    log_success "Monitoring déployé"
}

# Déployer Loki (logging)
deploy_logging() {
    log_info "Déploiement de Loki pour la centralisation des logs..."

    if helm list -n monitoring | grep -q loki; then
        log_warning "Loki déjà installé, upgrade..."
        helm upgrade loki grafana/loki-stack \
            --namespace monitoring \
            --set loki.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
            --set promtail.enabled=true
    else
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo update
        helm install loki grafana/loki-stack \
            --namespace monitoring \
            --set loki.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
            --set promtail.enabled=true
    fi

    log_success "Loki déployé"
}

# Déployer l'application Laravel
deploy_laravel_app() {
    log_info "Déploiement de l'application Laravel..."

    # Créer le namespace si besoin
    kubectl create namespace laravel --dry-run=client -o yaml | kubectl apply -f -

    # Installer le Helm chart Laravel
    if helm list -n laravel | grep -q laravel-app; then
        log_warning "laravel-app déjà installé, upgrade..."
        helm upgrade laravel-app ./kubequest-cluster/laravel-app \
            --namespace laravel \
            --values kubequest-cluster/laravel-app/values.yaml
    else
        helm install laravel-app ./kubequest-cluster/laravel-app \
            --namespace laravel \
            --values kubequest-cluster/laravel-app/values.yaml
    fi

    log_success "Application Laravel déployée"
}

# Déployer Kubernetes Dashboard
deploy_dashboard() {
    log_info "Déploiement de Kubernetes Dashboard..."

    # Appliquer le manifest
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

    # Créer l'admin user
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF

    log_success "Kubernetes Dashboard déployé"
}

# Vérifier le déploiement
verify_deployment() {
    log_info "Vérification du déploiement..."

    echo ""
    log_info "=== État des nœuds ==="
    kubectl get nodes -L node-role.kubernetes.io/ingress,node-role.kubernetes.io/monitoring,node-role.kubernetes.io/worker

    echo ""
    log_info "=== Pods ingress-nginx ==="
    kubectl get pods -n ingress-nginx -o wide

    echo ""
    log_info "=== Pods Laravel ==="
    kubectl get pods -n laravel -o wide

    echo ""
    log_info "=== Pods Monitoring ==="
    kubectl get pods -n monitoring -l 'app in (prometheus,grafana,loki)' -o wide

    echo ""
    log_info "=== Ingress ==="
    kubectl get ingress -A

    echo ""
    log_info "=== Services LoadBalancer/NodePort ==="
    kubectl get svc -n ingress-nginx ingress-nginx-controller

    echo ""
    log_info "=== HPA (Horizontal Pod Autoscaler) ==="
    kubectl get hpa -n laravel || echo "Pas encore d'HPA (les replicas gérés par Helm)"

    echo ""
    log_success "=== DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ==="
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
    echo "🚀 KUBEQUEST - DÉPLOIEMENT COMPLET"
    echo "=========================================="
    echo ""

    check_prereqs
    deploy_infrastructure
    deploy_monitoring
    deploy_logging
    deploy_laravel_app
    deploy_dashboard
    verify_deployment
    show_access_info

    log_success "Tout est déployé ! Pour tester, lancez : ./load-test.sh"
}

# Exécuter
main "$@"
