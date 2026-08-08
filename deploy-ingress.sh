#!/bin/bash

###############################################################################
# Script de déploiement Ingress pour Kubernetes AWS
# Projet : T-CLO-902-PAR_5
# Groupe : student-frankfurt-group-50
###############################################################################

set -e  # Arrêter le script si une commande échoue

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier si kubectl est installé
check_kubectl() {
    log_info "Vérification de kubectl..."
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé. Installation..."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install kubectl
        else
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        fi
    fi
    log_success "kubectl est installé : $(kubectl version --client --short 2>&1 | head -1)"
}

# Vérifier si helm est installé
check_helm() {
    log_info "Vérification de Helm..."
    if ! command -v helm &> /dev/null; then
        log_error "Helm n'est pas installé. Installation..."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install helm
        else
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        fi
    fi
    log_success "Helm est installé : $(helm version --short 2>&1 | head -1)"
}

# Vérifier si kustomize est installé
check_kustomize() {
    log_info "Vérification de Kustomize..."
    if ! command -v kustomize &> /dev/null; then
        log_error "Kustomize n'est pas installé. Installation..."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install kustomize
        else
            curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
            sudo mv kustomize /usr/local/bin/
        fi
    fi
    log_success "Kustomize est installé"
}

# Vérifier la connexion au cluster
check_cluster_connection() {
    log_info "Vérification de la connexion au cluster..."

    if ! kubectl get nodes &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes!"
        log_warning "Assurez-vous d'avoir configuré vos credentials AWS et exécuté :"
        log_warning "  aws eks update-kubeconfig --name <nom-du-cluster> --region eu-central-1"
        exit 1
    fi

    local NODE_COUNT=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
    log_success "Connecté au cluster avec $NODE_COUNT nœud(s)"
    kubectl get nodes
}

# Déployer nginx-ingress
deploy_nginx_ingress() {
    log_info "Déploiement de nginx-ingress controller..."

    # Créer le namespace
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

    # Aller dans le répertoire de configuration nginx-ingress
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local NGINX_DIR="$SCRIPT_DIR/kubequest-cluster/gitops/infrastructure/base/nginx-ingress"

    if [ ! -d "$NGINX_DIR" ]; then
        log_error "Répertoire nginx-ingress non trouvé : $NGINX_DIR"
        exit 1
    fi

    cd "$NGINX_DIR"

    # Appliquer la configuration
    kubectl apply -k .

    # Attendre que le déploiement soit prêt
    log_info "Attente du déploiement nginx-ingress (cela peut prendre quelques minutes)..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s

    # Récupérer l'information du LoadBalancer
    log_info "Récupération de l'adresse du LoadBalancer..."
    local LB_HOST=""
    local LB_IP=""

    # Attendre que le LoadBalancer soit prêt
    for i in {1..30}; do
        local SVC_OUTPUT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o json)
        LB_HOST=$(echo "$SVC_OUTPUT" | jq -r '.status.loadBalancer.ingress[0].hostname // empty')
        LB_IP=$(echo "$SVC_OUTPUT" | jq -r '.status.loadBalancer.ingress[0].ip // empty')

        if [ -n "$LB_HOST" ] || [ -n "$LB_IP" ]; then
            break
        fi

        log_warning "En attente du LoadBalancer... ($i/30)"
        sleep 10
    done

    if [ -n "$LB_HOST" ]; then
        log_success "LoadBalancer créé : $LB_HOST"
        export LB_ADDRESS="$LB_HOST"
    elif [ -n "$LB_IP" ]; then
        log_success "LoadBalancer créé : $LB_IP"
        export LB_ADDRESS="$LB_IP"
    else
        log_error "Le LoadBalancer n'a pas d'adresse externe"
        kubectl get svc ingress-nginx-controller -n ingress-nginx
        return 1
    fi

    cd "$SCRIPT_DIR"
}

# Déployer cert-manager
deploy_cert_manager() {
    log_info "Déploiement de cert-manager..."

    # Vérifier si cert-manager est déjà installé
    if kubectl get namespace cert-manager &> /dev/null; then
        log_warning "cert-manager est déjà installé"
        return
    fi

    # Installer cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

    # Attendre que cert-manager soit prêt
    log_info "Attente de cert-manager..."
    sleep 10
    kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s || true

    log_success "cert-manager déployé"
}

# Déployer l'application Laravel
deploy_laravel_app() {
    log_info "Déploiement de l'application Laravel..."

    # Créer le namespace
    kubectl create namespace laravel-app --dry-run=client -o yaml | kubectl apply -f -

    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local LARAVEL_DIR="$SCRIPT_DIR/kubequest-cluster/laravel-app"

    if [ ! -d "$LARAVEL_DIR" ]; then
        log_error "Répertoire Laravel non trouvé : $LARAVEL_DIR"
        exit 1
    fi

    cd "$LARAVEL_DIR"

    # Vérifier si le chart est déjà installé
    if helm list -n laravel-app | grep -q laravel-app; then
        log_warning "Le chart laravel-app est déjà installé. Upgrade..."
        helm upgrade laravel-app . -n laravel-app -f values.yaml
    else
        helm install laravel-app . -n laravel-app -f values.yaml
    fi

    # Attendre que les pods soient prêts
    log_info "Attente des pods Laravel..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=laravel-app -n laravel-app --timeout=300s || true

    log_success "Application Laravel déployée"
    cd "$SCRIPT_DIR"
}

# Configurer le hosts local
configure_local_hosts() {
    local LB_ADDRESS="$1"

    log_info "Configuration du fichier /etc/hosts..."

    log_warning "Vous devez configurer votre fichier /etc/hosts pour tester"
    log_warning "Ajoutez la ligne suivante à /etc/hosts :"
    echo ""
    echo -e "${GREEN}$LB_ADDRESS    larapp.kubequest.local${NC}"
    echo ""
    log_warning "Commande suggérée (macOS/Linux) :"
    echo -e "${YELLOW}sudo bash -c 'echo \"$LB_ADDRESS    larapp.kubequest.local\" >> /etc/hosts'${NC}"
    echo ""

    read -p "Voulez-vous que j'ajoute cette ligne automatiquement ? (o/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sudo bash -c "echo \"$LB_ADDRESS    larapp.kubequest.local\" >> /etc/hosts"
        else
            # Linux
            sudo bash -c "echo \"$LB_ADDRESS    larapp.kubequest.local\" >> /etc/hosts"
        fi
        log_success "Entrée ajoutée à /etc/hosts"
    fi
}

# Tester l'accès HTTP
test_http_access() {
    local LB_ADDRESS="$1"

    log_info "Test de l'accès HTTP..."

    if curl -s -o /dev/null -w "%{http_code}" http://larapp.kubequest.local --connect-timeout 5 | grep -q "200\|301\|302\|404"; then
        log_success "Test HTTP réussi !"
        echo "Essayez : curl http://larapp.kubequest.local"
    else
        log_warning "Test HTTP échoué ou application pas encore prête"
        log_warning "Essayez à nouveau dans quelques minutes"
    fi
}

# Tester l'accès HTTPS
test_https_access() {
    log_info "Test de l'accès HTTPS (avec vérification SSL désactivée)..."

    if curl -k -s -o /dev/null -w "%{http_code}" https://larapp.kubequest.local --connect-timeout 5 | grep -q "200\|301\|302\|404"; then
        log_success "Test HTTPS réussi !"
        echo "Essayez : curl -k https://larapp.kubequest.local"
    else
        log_warning "Test HTTPS échoué"
        log_warning "Le certificat SSL n'est peut-être pas encore prêt"
    fi
}

# Afficher les informations de déploiement
show_deployment_info() {
    local LB_ADDRESS="$1"

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  DÉPLOIEMENT INGRESS TERMINÉ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Informations du LoadBalancer :${NC}"
    echo "  Adresse : $LB_ADDRESS"
    echo ""
    echo -e "${BLUE}Tests à effectuer :${NC}"
    echo "  HTTP  : curl http://larapp.kubequest.local"
    echo "  HTTPS : curl -k https://larapp.kubequest.local"
    echo "  Web   : open http://larapp.kubequest.local"
    echo ""
    echo -e "${BLUE}Commandes utiles :${NC}"
    echo "  kubectl get pods -n ingress-nginx"
    echo "  kubectl get pods -n laravel-app"
    echo "  kubectl get ingress -n laravel-app"
    echo "  kubectl get svc -n ingress-nginx"
    echo ""
    echo -e "${BLUE}Logs :${NC}"
    echo "  kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 -f"
    echo "  kubectl logs -n laravel-app -l app.kubernetes.io/name=laravel-app --tail=50 -f"
    echo ""
}

# Fonction principale
main() {
    echo -e "${GREEN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║        Script de Déploiement Ingress Kubernetes           ║
║                  Projet T-CLO-902-PAR_5                    ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    log_info "Début du déploiement..."

    # Prérequis
    check_kubectl
    check_helm
    check_kustomize
    check_cluster_connection

    # Déploiements
    deploy_nginx_ingress
    LB_ADDRESS="${LB_ADDRESS}"
    deploy_cert_manager
    deploy_laravel_app

    # Configuration et tests
    configure_local_hosts "$LB_ADDRESS"
    test_http_access "$LB_ADDRESS"
    test_https_access "$LB_ADDRESS"

    # Afficher les informations finales
    show_deployment_info "$LB_ADDRESS"

    log_success "Script terminé avec succès !"
    log_info "Consultez le fichier GUIDE_INGRESS_DEPLOYMENT.md pour plus de détails"
}

# Exécuter le script
main "$@"
