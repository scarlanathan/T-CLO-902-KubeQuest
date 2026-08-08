#!/bin/bash

# Script pour déployer l'application Laravel

set -e

echo "========================================="
echo "Déploiement de l'application Laravel"
echo "========================================="

# Vérifier que kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo "Erreur: kubectl n'est pas installé"
    exit 1
fi

# Vérifier que helm est installé
if ! command -v helm &> /dev/null; then
    echo "Erreur: helm n'est pas installé"
    exit 1
fi

# Vérifier que l'infrastructure est déployée
echo "Vérification de l'infrastructure..."
kubectl get namespace ingress-nginx &> /dev/null || { echo "Erreur: L'infrastructure n'est pas déployée. Lancez d'abord ./deploy-infrastructure.sh"; exit 1; }

# Créer le namespace de l'application
echo "Création du namespace de l'application..."
kubectl create namespace laravel-app --dry-run=client -o yaml | kubectl apply -f -

# Créer les secrets
echo "Création des secrets..."
kubectl create secret generic laravel-app-secrets \
  --from-literal=app-key="base64:$(openssl rand -base64 32)" \
  --from-literal=db-password="changeme-in-production" \
  --from-literal=redis-password="changeme-in-production" \
  --from-literal=mail-password="changeme-in-production" \
  --namespace laravel-app \
  --dry-run=client -o yaml | kubectl apply -f -

# Mettre à jour les dépendances Helm
echo "Mise à jour des dépendances Helm..."
cd laravel-app
helm dependency update
cd ..

# Déployer l'application
echo "Déploiement de l'application Laravel..."
helm upgrade --install laravel-app ./laravel-app \
  --namespace laravel-app \
  --create-namespace \
  --values gitops/apps/laravel-app/base/values.yaml \
  --wait \
  --timeout 10m

# Attendre que le déploiement soit prêt
echo "Attente du démarrage de l'application..."
kubectl wait --namespace laravel-app \
  --for=condition=available \
  deployment/laravel-app \
  --timeout=300s

# Attendre que PostgreSQL soit prêt
echo "Attente du démarrage de PostgreSQL..."
kubectl wait --namespace laravel-app \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=postgresql \
  --timeout=300s

echo ""
echo "========================================="
echo "Application déployée avec succès !"
echo "========================================="
echo ""
echo "URL de l'application:"
echo "  - https://larapp.kubequest.local"
echo ""
echo "Statut des pods:"
kubectl -n laravel-app get pods
echo ""
echo "Services:"
kubectl -n laravel-app get services
echo ""
echo "Ingress:"
kubectl -n laravel-app get ingress
echo ""
