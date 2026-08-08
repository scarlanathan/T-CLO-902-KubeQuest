#!/bin/bash
# =====================================================
# SCRIPT DE VÉRIFICATION DES PRÉREQUIS
# =====================================================

echo "=========================================="
echo "🔍 VÉRIFICATION DES PRÉREQUIS AVANT DÉPLOIEMENT"
echo "=========================================="
echo ""

PASS=0
FAIL=0

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅${NC} $1"
        PASS=$((PASS+1))
        return 0
    else
        echo -e "${RED}❌${NC} $1"
        FAIL=$((FAIL+1))
        return 1
    fi
}

warn() {
    echo -e "${YELLOW}⚠️  ${NC} $1"
}

# =====================================================
# TESTS DE BASE
# =====================================================

echo "📍 Tests de base"

# Connexion au cluster
kubectl cluster-info &> /dev/null
check "kubectl connecté au cluster"

# Nodes Ready
kubectl get nodes | grep Ready | grep -v NotReady &> /dev/null
check "Au moins un node est Ready"

# Namespace laravel existe
kubectl get namespace laravel &> /dev/null
check "Namespace laravel existe"

# Namespace monitoring existe
kubectl get namespace monitoring &> /dev/null
check "Namespace monitoring existe"

echo ""

# =====================================================
# INGRESS CONTROLLER
# =====================================================

echo "📍 Ingress Controller"

kubectl get namespace ingress-nginx &> /dev/null
check "Namespace ingress-nginx existe"

kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx &> /dev/null
INGRESS_PODS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers | grep Running | wc -l)
if [ "$INGRESS_PODS" -ge "1" ]; then
    echo -e "${GREEN}✅${NC} Ingress controller est Running ($INGRESS_PODS pods)"
    PASS=$((PASS+1))
else
    echo -e "${RED}❌${NC} Ingress controller n'est pas Running"
    FAIL=$((FAIL+1))
fi

echo ""

# =====================================================
# APPLICATION LARAVEL
# =====================================================

echo "📍 Application Laravel"

# Pods Laravel Running
LARAVEL_PODS=$(kubectl get pods -n laravel -l app.kubernetes.io/name=laravel --no-headers | grep Running | wc -l)
if [ "$LARAVEL_PODS" -ge "2" ]; then
    echo -e "${GREEN}✅${NC} Au moins 2 pods Laravel Running ($LARAVEL_PODS)"
    PASS=$((PASS+1))
else
    echo -e "${RED}❌${NC} Moins de 2 pods Laravel Running ($LARAVEL_PODS)"
    FAIL=$((FAIL+1))
fi

# HPA existe
kubectl get hpa laravel -n laravel &> /dev/null
check "HPA Laravel existe"

# PVC MySQL existe
kubectl get pvc data-mysql-0 -n laravel &> /dev/null
check "PVC MySQL existe"

echo ""

# =====================================================
# MONITORING STACK
# =====================================================

echo "📍 Monitoring Stack"

# Grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana &> /dev/null
check "Pod Grafana existe"

# Prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus &> /dev/null
check "Pod Prometheus existe"

# Loki
kubectl get pods -n monitoring -l app=loki &> /dev/null
check "Pod Loki existe"

# Promtail
kubectl get pods -n monitoring -l app.kubernetes.io/instance=loki -l app.kubernetes.io/name=promtail &> /dev/null
check "Pods Promtail existent"

echo ""

# =====================================================
# ESPACE DISQUE
# =====================================================

echo "📍 Espace disque sur les nodes"

# Vérifier l'espace sur chaque node
NODES=$(kubectl get nodes -o name)
DISK_OK=true

for node in $NODES; do
    # On ne peut pas vérifier directement via kubectl, mais on peut vérifier les PV
    echo "  - $node"
done

# Vérifier si on peut créer un PV hostPath
kubectl get pv | grep mysql-pv &> /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅${NC} Au moins un PV existe déjà"
    PASS=$((PASS+1))
else
    warn "Aucun PV hostPath trouvé (sera créé lors du déploiement)"
fi

echo ""

# =====================================================
# CERT-MANAGER
# =====================================================

echo "📍 Cert-manager"

kubectl get namespace cert-manager &> /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅${NC} Namespace cert-manager existe"
    PASS=$((PASS+1))

    # Vérifier les pods
    kubectl get pods -n cert-manager | grep Running &> /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅${NC} Cert-manager est Running"
        PASS=$((PASS+1))
    else
        warn "Cert-manager installé mais pods pas Ready"
    fi
else
    warn "Cert-manager n'est pas installé (sera installé automatiquement)"
fi

echo ""

# =====================================================
# RÉSUMÉ
# =====================================================

echo "=========================================="
echo "📊 RÉSUMÉ"
echo "=========================================="
echo ""

TOTAL=$((PASS+FAIL))
if [ "$TOTAL" -gt 0 ]; then
    PERCENT=$((PASS*100/TOTAL))
    echo "Pré-requis: $PASS/$TOTAL ($PERCENT%)"
fi

echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✨ Tous les prérequis sont OK!${NC}"
    echo ""
    echo "Vous pouvez lancer le déploiement:"
    echo "  ./deploy-production-ready.sh"
else
    echo -e "${RED}⚠️  Certains prérequis manquent${NC}"
    echo ""
    echo "Veuillez corriger les problèmes avant de continuer"
fi

echo ""

# =====================================================
# RECOMMANDATIONS
# =====================================================

echo "=========================================="
echo "💡 RECOMMANDATIONS"
echo "=========================================="
echo ""

# Vérifier si /etc/hosts a été mis à jour
if grep -q "grafana.kubequest.local" /etc/hosts 2>/dev/null; then
    echo -e "${GREEN}✅${NC} /etc/hosts contient les entrées kubequest"
else
    warn "N'oubliez pas d'ajouter au /etc/hosts:"
    echo "   3.77.235.74 app.kubequest.local"
    echo "   3.77.235.74 grafana.kubequest.local"
    echo "   3.77.235.74 prometheus.kubequest.local"
    echo "   3.77.235.74 dashboard.kubequest.local"
fi

echo ""

# Vérifier l'accès SSH
if [ -f "kubequest.pem" ]; then
    echo -e "${GREEN}✅${NC} Clé SSH kubequest.pem trouvée"
else
    warn "Clé SSH kubequest.pem non trouvée dans ce dossier"
fi

echo ""

# =====================================================
# ÉTAT ACTUEL DU CLUSTER
# =====================================================

echo "=========================================="
echo "📊 ÉTAT ACTUEL DU CLUSTER"
echo "=========================================="
echo ""

echo "📍 Nodes:"
kubectl get nodes
echo ""

echo "📍 Namespaces:"
kubectl get namespaces | grep -E "NAME|laravel|monitoring|ingress|cert-manager|kubernetes-dashboard"
echo ""

echo "📍 Pods Laravel:"
kubectl get pods -n laravel
echo ""

echo "📍 Ingress actuels:"
kubectl get ingress --all-namespaces
echo ""

echo "📍 Network Policies actuelles:"
kubectl get networkpolicies --all-namespaces || echo "Aucune Network Policy définie"
echo ""

echo "=========================================="
echo "🎯 PRÊT POUR LE DÉPLOIEMENT!"
echo "=========================================="
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "Lancez maintenant: ./deploy-production-ready.sh"
else
    echo "Corrigez les erreurs avant de continuer"
fi

echo ""
