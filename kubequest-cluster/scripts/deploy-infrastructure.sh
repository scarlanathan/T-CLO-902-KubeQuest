#!/bin/bash

# Script pour déployer toute l'infrastructure Kubernetes

set -e

echo "========================================="
echo "Déploiement de l'infrastructure KubeQuest"
echo "========================================="

# Vérifier que kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo "Erreur: kubectl n'est pas installé"
    exit 1
fi

# Vérifier que kustomize est installé
if ! command -v kustomize &> /dev/null; then
    echo "Erreur: kustomize n'est pas installé"
    echo "Installez kustomize avec: go install sigs.k8s.io/kustomize/kustomize/v5@latest"
    exit 1
fi

# Vérifier que helm est installé
if ! command -v helm &> /dev/null; then
    echo "Erreur: helm n'est pas installé"
    exit 1
fi

# Ajouter les repositories Helm requis
echo "Ajout des repositories Helm..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Créer les namespaces
echo "Création des namespaces..."
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace opa --dry-run=client -o yaml | kubectl apply -f -

# Déployer nginx-ingress
echo "Déploiement de nginx-ingress..."
cd gitops/infrastructure/base/nginx-ingress
kubectl apply -f namespace.yaml
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  -f values.yaml \
  --wait
cd ../../..

# Attendre que nginx-ingress soit prêt
echo "Attente du démarrage de nginx-ingress..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=ingress-nginx \
  --timeout=300s

# Déployer cert-manager
echo "Déploiement de cert-manager..."
cd gitops/infrastructure/base/cert-manager
kubectl apply -f namespace.yaml
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version 1.14.0 \
  --set installCRDs=true \
  --set replicaCount=2 \
  --wait
kubectl apply -f cluster-issuer.yaml
cd ../../..

# Attendre que cert-manager soit prêt
echo "Attente du démarrage de cert-manager..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=cert-manager \
  --timeout=300s

# Déployer kubernetes-dashboard
echo "Déploiement de kubernetes-dashboard..."
cd gitops/infrastructure/base/kubernetes-dashboard
kubectl apply -f namespace.yaml
kubectl apply -f admin-user.yaml
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --namespace kubernetes-dashboard \
  --version 7.0.0 \
  --set replicaCount=2 \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --set resources.limits.cpu=500m \
  --set resources.limits.memory=512Mi \
  --wait
kubectl apply -f ingress.yaml
cd ../../..

# Attendre que kubernetes-dashboard soit prêt
echo "Attente du démarrage de kubernetes-dashboard..."
kubectl wait --namespace kubernetes-dashboard \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=kubernetes-dashboard \
  --timeout=300s

# Déployer kube-prometheus
echo "Déploiement de kube-prometheus..."
cd gitops/infrastructure/base/monitoring
kubectl apply -f namespace.yaml
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 55.0.0 \
  -f values.yaml \
  --wait
kubectl apply -f ingress-grafana.yaml
kubectl apply -f ingress-prometheus.yaml
cd ../../..

# Attendre que prometheus soit prêt
echo "Attente du démarrage de prometheus..."
kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=prometheus \
  --timeout=300s

# Déployer Loki
echo "Déploiement de Loki..."
cd gitops/infrastructure/base/logging
kubectl apply -f namespace.yaml
helm upgrade --install loki grafana/loki-stack \
  --namespace logging \
  --version 2.10.2 \
  -f values.yaml \
  --wait
kubectl apply -f ingress-loki.yaml
kubectl apply -f ingress-grafana.yaml
cd ../../..

# Attendre que Loki soit prêt
echo "Attente du démarrage de Loki..."
kubectl wait --namespace logging \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=loki \
  --timeout=300s

# Déployer OPA
echo "Déploiement de OPA (Validating Webhook)..."
cd gitops/infrastructure/base/security
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f rbac.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Attendre que OPA soit prêt
echo "Attente du démarrage de OPA..."
kubectl wait --namespace opa \
  --for=condition=ready pod \
  --selector=app=opa \
  --timeout=300s

# Récupérer le CA bundle du service OPA
CA_BUNDLE=$(kubectl get configmap -n opa -o jsonpath='{.items[0].data.ca\.crt}' 2>/dev/null || kubectl get secret -n opa -o jsonpath='{.items[0].data.ca\.crt}' 2>/dev/null || echo "")

# Créer le webhook configuration avec le CA bundle
if [ -n "$CA_BUNDLE" ]; then
  sed "s/\${CA_BUNDLE}/$CA_BUNDLE/g" webhook-configuration.yaml | kubectl apply -f -
else
  echo "Avertissement: Impossible de récupérer le CA bundle, utilisation d'une valeur vide"
  sed "s/\${CA_BUNDLE}//g" webhook-configuration.yaml | kubectl apply -f -
fi
cd ../../..

echo ""
echo "========================================="
echo "Infrastructure déployée avec succès !"
echo "========================================="
echo ""
echo "URLs accessibles:"
echo "  - Grafana: https://grafana.kubequest.local"
echo "  - Prometheus: https://prometheus.kubequest.local"
echo "  - Loki: https://loki.kubequest.local"
echo "  - Logs: https://logs.kubequest.local"
echo "  - Kubernetes Dashboard: https://dashboard.kubequest.local"
echo ""
echo "Pour obtenir le token du dashboard:"
echo "  kubectl -n kubernetes-dashboard describe secret \$(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print \$1}')"
echo ""
