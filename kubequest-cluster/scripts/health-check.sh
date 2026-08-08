#!/bin/bash

# Script de vérification de santé de l'infrastructure

set -e

echo "========================================="
echo "Vérification de santé de l'infrastructure"
echo "========================================="
echo ""

# Fonction pour vérifier l'état des pods dans un namespace
check_namespace() {
  local namespace=$1
  echo "Vérification des pods dans namespace: $namespace"
  kubectl get pods -n $namespace || echo "  Aucun pod trouvé"
  echo ""
}

# Vérifier tous les namespaces
check_namespace "ingress-nginx"
check_namespace "cert-manager"
check_namespace "monitoring"
check_namespace "logging"
check_namespace "kubernetes-dashboard"
check_namespace "opa"
check_namespace "laravel-app"

# Vérifier les ingress
echo "========================================="
echo "Vérification des Ingress"
echo "========================================="
kubectl get ingress --all-namespaces
echo ""

# Vérifier les services
echo "========================================="
echo "Vérification des Services"
echo "========================================="
kubectl get services --all-namespaces
echo ""

# Vérifier les HPAs
echo "========================================="
echo "Vérification des Horizontal Pod Autoscalers"
echo "========================================="
kubectl get hpa --all-namespaces
echo ""

# Vérifier les PVCs
echo "========================================="
echo "Vérification des Persistent Volume Claims"
echo "========================================="
kubectl get pvc --all-namespaces
echo ""

# Vérifier les CronJobs
echo "========================================="
echo "Vérification des CronJobs"
echo "========================================="
kubectl get cronjobs --all-namespaces
echo ""

# Vérifier les Certificates
echo "========================================="
echo "Vérification des Certificats"
echo "========================================="
kubectl get certificates --all-namespaces
echo ""

# Vérifier les ClusterIssuers
echo "========================================="
echo "Vérification des ClusterIssuers"
echo "========================================="
kubectl get clusterissuers
echo ""

echo "========================================="
echo "Vérification de santé terminée !"
echo "========================================="
