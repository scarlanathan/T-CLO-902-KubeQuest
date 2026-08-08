#!/bin/bash

###############################################################################
# KubeQuest - Installation de cert-manager pour Let's Encrypt
# Ce script installe cert-manager et configure Let's Encrypt
###############################################################################

set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

log_info "Installation de cert-manager..."

# Installer cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Attendre que cert-manager soit prêt
log_info "Attente de cert-manager (30s)..."
sleep 30

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=webhook -n cert-manager --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cainjector -n cert-manager --timeout=120s

log_success "cert-manager installé"

# Créer ClusterIssuer pour Let's Encrypt (staging pour les tests)
log_info "Configuration de Let's Encrypt (Staging)..."

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@kubequest.local
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

log_success "ClusterIssuer Staging créé"

# Créer ClusterIssuer pour Let's Encrypt (production)
log_info "Configuration de Let's Encrypt (Production)..."

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@kubequest.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

log_success "ClusterIssuer Production créé"

# Vérifier
log_info "Vérification de cert-manager..."
kubectl get pods -n cert-manager
echo ""
kubectl get clusterissuer

log_success "=== CERT-MANAGER INSTALLÉ ==="
echo ""
log_info "Les certificats seront automatiquement créés quand vous créerez des Ingress avec :"
echo "  annotations:"
echo "    cert-manager.io/cluster-issuer: 'letsencrypt-prod'"
echo ""
