#!/bin/bash

# Script pour démontrer le rollback de déploiement

set -e

echo "========================================="
echo "Démonstration de Rollback"
echo "========================================="

# Vérifier que kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo "Erreur: kubectl n'est pas installé"
    exit 1
fi

# Vérifier que l'application est déployée
if ! kubectl get deployment -n laravel-app laravel-app &> /dev/null; then
    echo "Erreur: L'application Laravel n'est pas déployée"
    exit 1
fi

echo ""
echo "État actuel du déploiement:"
kubectl -n laravel-app get deployment laravel-app
echo ""

# Obtenir la révision actuelle
CURRENT_REVISION=$(kubectl -n laravel-app get deployment laravel-app -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
echo "Révision actuelle: $CURRENT_REVISION"
echo ""

echo "========================================="
echo "Déploiement d'une nouvelle version (simulée)..."
echo "========================================="
echo ""

# Simuler un déploiement avec une nouvelle version
helm upgrade --install laravel-app ./laravel-app \
  --namespace laravel-app \
  --set image.tag="2.0.0" \
  --wait --timeout 5m

echo "Déploiement effectué"
echo ""

# Attendre un peu
sleep 5

echo "Nouvel état du déploiement:"
kubectl -n laravel-app get deployment laravel-app
echo ""

NEW_REVISION=$(kubectl -n laravel-app get deployment laravel-app -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
echo "Nouvelle révision: $NEW_REVISION"
echo ""

echo "Vérification du statut des pods..."
kubectl -n laravel-app get pods
echo ""

echo "========================================="
echo "Simulation d'un problème dans la nouvelle version..."
echo "========================================="
echo ""

# Simuler un problème en mettant les replicas à 0 (ce qui causerait une défaillance)
echo "Mise à jour délibérément défaillante..."
kubectl -n laravel-app set image deployment/laravel-app \
  laravel-app=nonexistent-image:broken \
  --record=true

echo "Attente de la détection du problème..."
sleep 10

echo ""
echo "État des pods après le mauvais déploiement:"
kubectl -n laravel-app get pods
echo ""

echo "========================================="
echo "Rollback vers la version précédente..."
echo "========================================="
echo ""

# Effectuer le rollback
kubectl -n laravel-app rollout undo deployment/laravel-app

echo "Rollback en cours..."
echo ""

# Attendre que le rollback soit terminé
kubectl -n laravel-app rollout status deployment/laravel-app

echo ""
echo "État après rollback:"
kubectl -n laravel-app get deployment laravel-app
echo ""

echo "État des pods après rollback:"
kubectl -n laravel-app get pods
echo ""

echo "Historique des déploiements:"
kubectl -n laravel-app rollout history deployment/laravel-app
echo ""

echo "========================================="
echo "Démonstration terminée avec succès !"
echo "========================================="
echo ""
echo "✓ Rollback automatique démontré"
echo "✓ L'application est revenue à son état précédent"
echo ""
