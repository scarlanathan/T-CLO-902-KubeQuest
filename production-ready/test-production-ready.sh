#!/bin/bash
# =====================================================
# SCRIPT DE TEST COMPLET - 100% PRODUCTION-READY
# =====================================================

set -e

echo "=========================================="
echo "🧪 TESTS COMPLETS - 100% PRODUCTION-READY"
echo "=========================================="
echo ""

PASS=0
FAIL=0

# Fonction pour vérifier un test
check_test() {
    if [ $? -eq 0 ]; then
        echo "✅ PASS: $1"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL: $1"
        FAIL=$((FAIL+1))
    fi
}

# =====================================================
# TEST 1: PVC DE BACKUP
# =====================================================
echo "📍 [TEST 1/5] PVC de Backup"
echo ""

kubectl get pvc mysql-backup-pvc-new -n laravel &> /dev/null
PVC_STATUS=$(kubectl get pvc mysql-backup-pvc-new -n laravel -o jsonpath='{.status.phase}')
echo "PVC Status: $PVC_STATUS"

if [ "$PVC_STATUS" == "Bound" ]; then
    echo "✅ PVC est Bound"
    PASS=$((PASS+1))
else
    echo "⚠️  PVC est $PVC_STATUS (devrait être Bound)"
    echo "   Note: Le PV doit être créé manuellement sur le node"
    FAIL=$((FAIL+1))
fi

# Vérifier le CronJob
kubectl get cronjob mysql-backup-fixed -n laravel &> /dev/null
check_test "CronJob de backup créé"

echo ""

# =====================================================
# TEST 2: INGRESS MONITORING
# =====================================================
echo "📍 [TEST 2/5] Ingress Monitoring"
echo ""

# Vérifier Grafana Ingress
kubectl get ingress grafana-ingress -n monitoring &> /dev/null
check_test "Ingress Grafana créé"

# Vérifier Prometheus Ingress
kubectl get ingress prometheus-ingress -n monitoring &> /dev/null
check_test "Ingress Prometheus créé"

# Vérifier Dashboard Ingress
kubectl get ingress kubernetes-dashboard-ingress -n kubernetes-dashboard &> /dev/null
check_test "Ingress Dashboard créé"

echo "📋 Ingress créés:"
kubectl get ingress --all-namespaces | grep -E "NAME|grafana|prometheus|dashboard"

echo ""

# =====================================================
# TEST 3: CERTIFICATS TLS
# =====================================================
echo "📍 [TEST 3/5] Certificats TLS"
echo ""

# Vérifier cert-manager
kubectl get namespace cert-manager &> /dev/null
check_test "Namespace cert-manager existe"

kubectl get pods -n cert-manager | grep cert-manager | grep Running &> /dev/null
check_test "Pod cert-manager running"

# Vérifier ClusterIssuers
kubectl get clusterissuer letsencrypt-prod &> /dev/null
check_test "ClusterIssuer Let's Encrypt Production créé"

kubectl get clusterissuer letsencrypt-staging &> /dev/null
check_test "ClusterIssuer Let's Encrypt Staging créé"

# Vérifier les certificates
echo "📋 Certificates:"
kubectl get certificates --all-namespaces || echo "Aucun certificate créé encore (cela peut prendre quelques minutes)"

echo ""

# =====================================================
# TEST 4: ALERTING
# =====================================================
echo "📍 [TEST 4/5] Alerting"
echo ""

# Vérifier les PrometheusRules
kubectl get prometheusrules laravel-critical-alerts -n monitoring &> /dev/null
check_test "PrometheusRule Laravel critical créée"

kubectl get prometheusrules laravel-warning-alerts -n monitoring &> /dev/null
check_test "PrometheusRule Laravel warning créée"

kubectl get prometheusrules infrastructure-alerts -n monitoring &> /dev/null
check_test "PrometheusRule Infrastructure créée"

# Vérifier AlertManager Config
kubectl get configmap alertmanager-config -n monitoring &> /dev/null
check_test "ConfigMap AlertManager créée"

echo "📋 Règles d'alerting configurées:"
kubectl get prometheusrules -n monitoring

echo ""

# =====================================================
# TEST 5: NETWORK POLICIES
# =====================================================
echo "📍 [TEST 5/5] Network Policies"
echo ""

# Vérifier les policies dans laravel
kubectl get networkpolicy default-deny-all -n laravel &> /dev/null
check_test "NetworkPolicy default-deny créé (laravel)"

kubectl get networkpolicy laravel-policy -n laravel &> /dev/null
check_test "NetworkPolicy Laravel créé"

kubectl get networkpolicy mysql-policy -n laravel &> /dev/null
check_test "NetworkPolicy MySQL créé"

# Vérifier les policies dans monitoring
kubectl get networkpolicy monitoring-policy -n monitoring &> /dev/null
check_test "NetworkPolicy Monitoring créé"

kubectl get networkpolicy grafana-policy -n monitoring &> /dev/null
check_test "NetworkPolicy Grafana créé"

echo "📋 Network Policies créées:"
kubectl get networkpolicies --all-namespaces

echo ""

# =====================================================
# TESTS D'INTÉGRATION
# =====================================================
echo "📍 [TESTS INTÉGRATION] Vérification de l'application"
echo ""

# Vérifier les pods Laravel
LARAVEL_PODS=$(kubectl get pods -n laravel -l app.kubernetes.io/name=laravel --no-headers | wc -l)
LARAVEL_RUNNING=$(kubectl get pods -n laravel -l app.kubernetes.io/name=laravel --no-headers | grep Running | wc -l)

echo "Pods Laravel: $LARAVEL_RUNNING/$LARAVEL_PODS Running"

if [ "$LARAVEL_RUNNING" -ge "2" ]; then
    echo "✅ Au moins 2 pods Laravel Running"
    PASS=$((PASS+1))
else
    echo "❌ Moins de 2 pods Laravel Running"
    FAIL=$((FAIL+1))
fi

# Vérifier HPA
kubectl get hpa laravel -n laravel &> /dev/null
HPA_REPLICAS=$(kubectl get hpa laravel -n laravel -o jsonpath='{.status.currentReplicas}')
echo "HPA Laravel: $HPA_REPLICAS replicas"

if [ "$HPA_REPLICAS" -ge "2" ]; then
    echo "✅ HPA fonctionne avec $HPA_REPLICAS replicas"
    PASS=$((PASS+1))
else
    echo "❌ HPA n'a pas assez de replicas"
    FAIL=$((FAIL+1))
fi

# Vérifier monitoring stack
GRAFANA_RUNNING=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers | grep Running | wc -l)
PROMETHEUS_RUNNING=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers | grep Running | wc -l)
LOKI_RUNNING=$(kubectl get pods -n monitoring -l app=loki --no-headers | grep Running | wc -l)

echo "Monitoring Stack:"
echo "  - Grafana: $GRAFANA_RUNNING Running"
echo "  - Prometheus: $PROMETHEUS_RUNNING Running"
echo "  - Loki: $LOKI_RUNNING Running"

if [ "$GRAFANA_RUNNING" -ge "1" ] && [ "$PROMETHEUS_RUNNING" -ge "1" ] && [ "$LOKI_RUNNING" -ge "1" ]; then
    echo "✅ Monitoring stack opérationnel"
    PASS=$((PASS+1))
else
    echo "❌ Monitoring stack incomplet"
    FAIL=$((FAIL+1))
fi

echo ""

# =====================================================
# RÉSUMÉ
# =====================================================
echo "=========================================="
echo "📊 RÉSUMÉ DES TESTS"
echo "=========================================="
echo ""
echo "✅ Tests passés: $PASS"
echo "❌ Tests échoués: $FAIL"
echo ""

TOTAL=$((PASS+FAIL))
PERCENT=$((PASS*100/TOTAL))

echo "Score: $PERCENT%"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "🎉 TOUS LES TESTS SONT PASSÉS!"
    echo "✨ PROJET 100% PRODUCTION-READY!"
else
    echo "⚠️  Certains tests ont échoué"
    echo "   Vérifiez les logs et corrigez les problèmes"
fi

echo ""
echo "=========================================="
echo "📋 COMMANDES UTILES"
echo "=========================================="
echo ""
echo "# Vérifier les PVC"
echo "kubectl get pvc -n laravel"
echo ""
echo "# Vérifier les certificates"
echo "kubectl get certificates --all-namespaces"
echo "kubectl describe certificate <nom> -n <namespace>"
echo ""
echo "# Vérifier ingress"
echo "kubectl get ingress --all-namespaces"
echo ""
echo "# Tester l'accès (après avoir ajouté au /etc/hosts)"
echo "curl -I https://grafana.kubequest.local"
echo "curl -I https://app.kubequest.local"
echo ""
echo "# Vérifier les alertes Prometheus"
echo "kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090"
echo "# Ouvrir http://localhost:9090/alerts"
echo ""
echo "# Vérifier les Network Policies"
echo "kubectl get networkpolicies --all-namespaces -o wide"
echo ""
echo "# Logs de cert-manager"
echo "kubectl logs -n cert-manager deployment/cert-manager -f"
echo ""
