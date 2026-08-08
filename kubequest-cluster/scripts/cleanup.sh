#!/bin/bash

# Script pour nettoyer toute l'infrastructure

set -e

echo "========================================="
echo "Nettoyage de l'infrastructure KubeQuest"
echo "========================================="
echo ""
read -p "Êtes-vous sûr de vouloir tout supprimer ? (oui/non): " confirmation

if [ "$confirmation" != "oui" ]; then
    echo "Annulation du nettoyage"
    exit 0
fi

echo "Suppression de l'application Laravel..."
helm uninstall -n laravel-app laravel-app 2>/dev/null || true
kubectl delete namespace laravel-app --ignore-not-found=true

echo "Suppression de OPA..."
kubectl delete -f gitops/infrastructure/base/security/webhook-configuration.yaml --ignore-not-found=true
kubectl delete -f gitops/infrastructure/base/security/deployment.yaml --ignore-not-found=true
kubectl delete -f gitops/infrastructure/base/security/service.yaml --ignore-not-found=true
kubectl delete -f gitops/infrastructure/base/security/rbac.yaml --ignore-not-found=true
kubectl delete -f gitops/infrastructure/base/security/configmap.yaml --ignore-not-found=true
kubectl delete namespace opa --ignore-not-found=true

echo "Suppression de Loki..."
helm uninstall -n logging loki 2>/dev/null || true
kubectl delete -f gitops/infrastructure/base/logging/ingress-loki.yaml --ignore-not-found=true
kubectl delete -f gitops/infrastructure/base/logging/ingress-grafana.yaml --ignore-not-found=true
kubectl delete namespace logging --ignore-not-found=true

echo "Suppression de Prometheus..."
helm uninstall -n monitoring prometheus 2>/dev/null || true
kubectl delete -f gitops/infrastructure/base/monitoring/ingress-grafana.yaml --ignore-not-found=true
kubectl delete -f gitops/infrastructure/base/monitoring/ingress-prometheus.yaml --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true

echo "Suppression de Kubernetes Dashboard..."
helm uninstall -n kubernetes-dashboard kubernetes-dashboard 2>/dev/null || true
kubectl delete -f gitops/infrastructure/base/kubernetes-dashboard/ingress.yaml --ignore-not-found=true
kubectl delete -f gitops/infrastructure/base/kubernetes-dashboard/admin-user.yaml --ignore-not-found=true
kubectl delete namespace kubernetes-dashboard --ignore-not-found=true

echo "Suppression de Cert-Manager..."
helm uninstall -n cert-manager cert-manager 2>/dev/null || true
kubectl delete -f gitops/infrastructure/base/cert-manager/cluster-issuer.yaml --ignore-not-found=true
kubectl delete namespace cert-manager --ignore-not-found=true

echo "Suppression de nginx-ingress..."
helm uninstall -n ingress-nginx ingress-nginx 2>/dev/null || true
kubectl delete namespace ingress-nginx --ignore-not-found=true

echo ""
echo "========================================="
echo "Nettoyage terminé !"
echo "========================================="
echo ""
echo "Vérification des namespaces restants:"
kubectl get namespaces
echo ""
