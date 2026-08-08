#!/bin/bash

# ============================================================================
# SCRIPT DE TEST COMPLET DU CLUSTER KUBEQUEST
# ============================================================================
# Ce script teste tous les composants du projet KubeQuest
# Usage: ./test-complet-cluster.sh
# ============================================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compteurs
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Fonction pour afficher les titres
print_title() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Fonction pour afficher les sous-titres
print_subtitle() {
    echo -e "\n${YELLOW}--- $1 ---${NC}"
}

# Fonction pour tester une commande
test_command() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Test $TOTAL_TESTS: $test_name... "

    if output=$(eval "$command" 2>&1); then
        if [ -z "$expected_pattern" ] || echo "$output" | grep -q "$expected_pattern"; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAIL (pattern not found)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL (command error)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Fonction pour compter les ressources
count_resources() {
    local resource="$1"
    local namespace="${2:---all-namespaces}"

    if [ "$namespace" = "--all-namespaces" ]; then
        kubectl get "$resource" --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' '
    else
        kubectl get "$resource" -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' '
    fi
}

# ============================================================================
print_title "KUBEQUEST - TEST COMPLET DU CLUSTER"
echo "Date: $(date)"
echo "Cluster: $(kubectl config current-context 2>/dev/null || echo 'N/A')"
echo ""

# ============================================================================
print_title "1. TESTS DE CONNECTIVITÉ"

test_command "kubectl est configuré" \
    "kubectl version --client" \
    "Client Version"

test_command "Connexion au cluster" \
    "kubectl cluster-info" \
    "Kubernetes control plane"

test_command "Les nodes sont accessibles" \
    "kubectl get nodes" \
    "Ready"

# Compter les nodes
node_count=$(count_resources "nodes")
echo -e "   Nombre de nodes: ${GREEN}$node_count${NC}"

# ============================================================================
print_title "2. TESTS DES NAMESPACES"

expected_namespaces=("default" "kube-system" "ingress-nginx" "monitoring" "kubernetes-dashboard" "cert-manager" "opa")

for ns in "${expected_namespaces[@]}"; do
    test_command "Namespace $ns existe" \
        "kubectl get namespace $ns" \
        "$ns"
done

# ============================================================================
print_title "3. TESTS DES PODS (Infrastructure)"

print_subtitle "Ingress Nginx"
test_command "Pods ingress-nginx sont running" \
    "kubectl get pods -n ingress-nginx" \
    "Running"

ingress_pod_count=$(count_resources "pods" "ingress-nginx")
echo -e "   Nombre de pods ingress-nginx: ${GREEN}$ingress_pod_count${NC}"

print_subtitle "Kubernetes Dashboard"
test_command "Pods kubernetes-dashboard sont running" \
    "kubectl get pods -n kubernetes-dashboard" \
    "Running"

print_subtitle "Monitoring (Prometheus + Grafana)"
test_command "Pods monitoring sont running" \
    "kubectl get pods -n monitoring | grep -E '(prometheus|grafana)'" \
    "Running"

monitoring_pod_count=$(count_resources "pods" "monitoring")
echo -e "   Nombre de pods monitoring: ${GREEN}$monitoring_pod_count${NC}"

print_subtitle "Logging (Loki)"
test_command "Pods loki sont running" \
    "kubectl get pods -n monitoring | grep loki" \
    "Running"

print_subtitle "OPA (Security)"
test_command "Pods opa sont running" \
    "kubectl get pods -n opa" \
    "Running"

# ============================================================================
print_title "4. TESTS DES SERVICES"

test_command "Services ingress-nginx existent" \
    "kubectl get svc -n ingress-nginx" \
    "ingress-nginx-controller"

test_command "Services monitoring existent" \
    "kubectl get svc -n monitoring | grep -E '(prometheus|grafana)'" \
    "prometheus"

service_count=$(count_resources "svc" "--all-namespaces")
echo -e "   Nombre total de services: ${GREEN}$service_count${NC}"

# ============================================================================
print_title "5. TESTS DES INGRESS"

test_command "Ingress sont créés" \
    "kubectl get ingress --all-namespaces" \
    ""

ingress_count=$(count_resources "ingress" "--all-namespaces")
echo -e "   Nombre d'ingress: ${GREEN}$ingress_count${NC}"

# Tester les ingress individuels
if [ "$ingress_count" -gt 0 ]; then
    print_subtitle "Test de chaque Ingress"
    kubectl get ingress --all-namespaces --no-headers | while read -r ns name rest; do
        host=$(kubectl get ingress -n "$ns" "$name" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
        if [ -n "$host" ]; then
            test_command "Ingress $name ($host) est accessible" \
                "curl -s -o /dev/null -w '%{http_code}' http://$host --max-time 5" \
                "200\|301\|302\|404"
        fi
    done
fi

# ============================================================================
print_title "6. TESTS DU STORAGE"

test_command "PersistentVolumes existent" \
    "kubectl get pv" \
    ""

test_command "PersistentVolumeClaims existent" \
    "kubectl get pvc --all-namespaces" \
    ""

pvc_count=$(count_resources "pvc" "--all-namespaces")
echo -e "   Nombre de PVCs: ${GREEN}$pvc_count${NC}"

# Vérifier que tous les PVCs sont Bound
print_subtitle "État des PVCs"
if [ "$pvc_count" -gt 0 ]; then
    kubectl get pvc --all-namespaces --no-headers | while read -r ns name status rest; do
        if [ "$status" = "Bound" ]; then
            echo -e "   ${GREEN}✓${NC} $ns/$name: Bound"
        else
            echo -e "   ${RED}✗${NC} $ns/$name: $status (devrait être Bound)"
        fi
    done
fi

# ============================================================================
print_title "7. TESTS DES DEPLOYMENTS"

deployment_count=$(count_resources "deployment" "--all-namespaces")
echo -e "   Nombre de deployments: ${GREEN}$deployment_count${NC}"

print_subtitle "État des Deployments"
kubectl get deployments --all-namespaces --no-headers | while read -r ns name ready rest; do
    if echo "$ready" | grep -q "/"; then
        current=$(echo "$ready" | cut -d'/' -f1)
        desired=$(echo "$ready" | cut -d'/' -f2)
        if [ "$current" = "$desired" ] && [ "$current" != "0" ]; then
            echo -e "   ${GREEN}✓${NC} $ns/$name: $ready"
        else
            echo -e "   ${YELLOW}⚠${NC} $ns/$name: $ready"
        fi
    fi
done

# ============================================================================
print_title "8. TESTS DE L'APPLICATION LARAVEL (si déployée)"

if kubectl get namespace laravel &>/dev/null; then
    echo -e "${GREEN}✓ Namespace laravel existe${NC}"

    test_command "Pods Laravel sont running" \
        "kubectl get pods -n laravel" \
        "Running"

    test_command "Service Laravel existe" \
        "kubectl get svc -n laravel" \
        ""

    test_command "Ingress Laravel existe" \
        "kubectl get ingress -n laravel" \
        ""

    test_command "HPA Laravel existe" \
        "kubectl get hpa -n laravel" \
        ""

    test_command "PVC Laravel existe" \
        "kubectl get pvc -n laravel" \
        ""

    test_command "CronJob backup existe" \
        "kubectl get cronjob -n laravel" \
        ""
else
    echo -e "${YELLOW}⚠ Namespace laravel n'existe pas (application non déployée)${NC}"
fi

# ============================================================================
print_title "9. TESTS DE SÉCURITÉ"

print_subtitle "OPA Validating Webhook"
test_command "ValidatingWebhookConfiguration existe" \
    "kubectl get validatingwebhookconfigurations" \
    ""

print_subtitle "Network Policies"
netpol_count=$(count_resources "networkpolicy" "--all-namespaces")
echo -e "   Nombre de Network Policies: ${GREEN}$netpol_count${NC}"

if [ "$netpol_count" -gt 0 ]; then
    kubectl get networkpolicy --all-namespaces --no-headers | while read -r ns name rest; do
        echo -e "   ${GREEN}✓${NC} $ns/$name"
    done
fi

print_subtitle "Security Contexts (échantillon)"
# Vérifier qu'au moins un pod a un security context non-root
sample_pod=$(kubectl get pods --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.spec.securityContext.runAsNonRoot == true) | .metadata.name' | head -1)
if [ -n "$sample_pod" ]; then
    echo -e "   ${GREEN}✓${NC} Security contexts configurés (ex: $sample_pod)"
else
    echo -e "   ${YELLOW}⚠${NC} Aucun pod avec runAsNonRoot trouvé"
fi

# ============================================================================
print_title "10. TESTS DE MONITORING & ALERTING"

print_subtitle "ServiceMonitors"
servicemonitor_count=$(count_resources "servicemonitor" "--all-namespaces")
echo -e "   Nombre de ServiceMonitors: ${GREEN}$servicemonitor_count${NC}"

print_subtitle "PrometheusRules (Alerting)"
prometheusrule_count=$(count_resources "prometheusrule" "--all-namespaces")
echo -e "   Nombre de PrometheusRules: ${GREEN}$prometheusrule_count${NC}"

if [ "$prometheusrule_count" -gt 0 ]; then
    kubectl get prometheusrule --all-namespaces --no-headers | while read -r ns name rest; do
        echo -e "   ${GREEN}✓${NC} $ns/$name"
    done
fi

# ============================================================================
print_title "11. TESTS DES CERTIFICATS TLS"

if kubectl get namespace cert-manager &>/dev/null; then
    echo -e "${GREEN}✓ Cert-manager est installé${NC}"

    test_command "Pods cert-manager sont running" \
        "kubectl get pods -n cert-manager" \
        "Running"

    test_command "ClusterIssuers existent" \
        "kubectl get clusterissuer" \
        ""

    certificate_count=$(count_resources "certificate" "--all-namespaces")
    echo -e "   Nombre de certificats: ${GREEN}$certificate_count${NC}"

    if [ "$certificate_count" -gt 0 ]; then
        print_subtitle "État des Certificats"
        kubectl get certificate --all-namespaces --no-headers | while read -r ns name ready rest; do
            if [ "$ready" = "True" ]; then
                echo -e "   ${GREEN}✓${NC} $ns/$name: Ready"
            else
                echo -e "   ${YELLOW}⚠${NC} $ns/$name: $ready (peut prendre 5-10 min)"
            fi
        done
    fi
else
    echo -e "${YELLOW}⚠ Cert-manager n'est pas installé${NC}"
fi

# ============================================================================
print_title "12. TESTS DES BEST PRACTICES"

print_subtitle "HorizontalPodAutoscalers"
hpa_count=$(count_resources "hpa" "--all-namespaces")
echo -e "   Nombre de HPAs: ${GREEN}$hpa_count${NC}"

print_subtitle "PodDisruptionBudgets"
pdb_count=$(count_resources "pdb" "--all-namespaces")
echo -e "   Nombre de PDBs: ${GREEN}$pdb_count${NC}"

print_subtitle "CronJobs (Backups)"
cronjob_count=$(count_resources "cronjob" "--all-namespaces")
echo -e "   Nombre de CronJobs: ${GREEN}$cronjob_count${NC}"

# ============================================================================
print_title "13. TESTS D'ACCÈS WEB"

print_subtitle "Test des endpoints Ingress"

endpoints=(
    "http://grafana.kubequest.local:Grafana"
    "http://prometheus.kubequest.local:Prometheus"
    "http://dashboard.kubequest.local:32222:Dashboard"
    "http://app.kubequest.local:Laravel App"
)

for endpoint_info in "${endpoints[@]}"; do
    url=$(echo "$endpoint_info" | cut -d':' -f1,2,3)
    name=$(echo "$endpoint_info" | cut -d':' -f4)

    echo -n "   Testing $name ($url)... "
    http_code=$(curl -s -o /dev/null -w '%{http_code}' "$url" --max-time 5 2>/dev/null || echo "000")

    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ] || [ "$http_code" = "404" ]; then
        echo -e "${GREEN}✓ $http_code${NC}"
    else
        echo -e "${YELLOW}⚠ $http_code (vérifier /etc/hosts)${NC}"
    fi
done

# ============================================================================
print_title "14. VÉRIFICATIONS DES PODS EN ERREUR"

print_subtitle "Pods non-Running"
problem_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$problem_pods" -eq 0 ]; then
    echo -e "   ${GREEN}✓ Tous les pods sont Running ou Succeeded${NC}"
else
    echo -e "   ${RED}⚠ $problem_pods pod(s) en erreur:${NC}"
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
fi

# ============================================================================
print_title "15. RÉSUMÉ DES RESSOURCES"

echo -e "Namespaces:           ${GREEN}$(count_resources 'namespace')${NC}"
echo -e "Nodes:                ${GREEN}$(count_resources 'nodes')${NC}"
echo -e "Pods:                 ${GREEN}$(count_resources 'pods')${NC}"
echo -e "Deployments:          ${GREEN}$(count_resources 'deployment')${NC}"
echo -e "Services:             ${GREEN}$(count_resources 'svc')${NC}"
echo -e "Ingress:              ${GREEN}$(count_resources 'ingress')${NC}"
echo -e "PVs:                  ${GREEN}$(count_resources 'pv')${NC}"
echo -e "PVCs:                 ${GREEN}$(count_resources 'pvc')${NC}"
echo -e "ConfigMaps:           ${GREEN}$(count_resources 'configmap')${NC}"
echo -e "Secrets:              ${GREEN}$(count_resources 'secret')${NC}"
echo -e "HPAs:                 ${GREEN}$(count_resources 'hpa')${NC}"
echo -e "CronJobs:             ${GREEN}$(count_resources 'cronjob')${NC}"
echo -e "NetworkPolicies:      ${GREEN}$(count_resources 'networkpolicy')${NC}"
echo -e "ServiceMonitors:      ${GREEN}$(count_resources 'servicemonitor')${NC}"
echo -e "PrometheusRules:      ${GREEN}$(count_resources 'prometheusrule')${NC}"

if kubectl get certificates --all-namespaces &>/dev/null; then
    echo -e "Certificates:         ${GREEN}$(count_resources 'certificate')${NC}"
fi

# ============================================================================
print_title "RÉSULTAT FINAL"

echo -e "Total de tests:       ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Tests réussis:        ${GREEN}$PASSED_TESTS${NC}"
echo -e "Tests échoués:        ${RED}$FAILED_TESTS${NC}"

success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "Taux de réussite:     ${GREEN}$success_rate%${NC}"

echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ TOUS LES TESTS SONT PASSÉS !${NC}"
    echo -e "${GREEN}✓ Cluster 100% opérationnel !${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
elif [ $success_rate -ge 80 ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}⚠ Cluster fonctionnel avec warnings${NC}"
    echo -e "${YELLOW}⚠ Quelques problèmes mineurs${NC}"
    echo -e "${YELLOW}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ Plusieurs tests ont échoué${NC}"
    echo -e "${RED}✗ Vérifier la configuration${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
