#!/bin/bash
# =====================================================
# COMMANDES RAPIDES - 100% PRODUCTION-READY
# =====================================================

echo "=========================================="
echo "🚀 KUBEQUEST - COMMANDES RAPIDES"
echo "=========================================="
echo ""

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

case "${1:-help}" in
  "check")
    echo -e "${BLUE}📍 Vérification des prérequis${NC}"
    echo ""
    ./check-prerequis.sh
    ;;

  "deploy")
    echo -e "${BLUE}📍 Déploiement des 5 points${NC}"
    echo ""
    ./deploy-production-ready.sh
    ;;

  "test")
    echo -e "${BLUE}📍 Tests automatisés${NC}"
    echo ""
    ./test-production-ready.sh
    ;;

  "backup")
    echo -e "${BLUE}📍 Test manuel du backup${NC}"
    echo ""
    echo "Création d'un job de backup manuel..."
    kubectl create job --from=cronjob/mysql-backup-fixed manual-backup-$(date +%s) -n laravel
    echo ""
    echo "Logs du backup:"
    kubectl logs -n laravel -l app=mysql-backup --tail=20 -f
    ;;

  "ingress")
    echo -e "${BLUE}📍 Vérification des Ingress${NC}"
    echo ""
    kubectl get ingress --all-namespaces
    echo ""
    echo "Tests HTTP:"
    echo "  - curl -I http://grafana.kubequest.local"
    echo "  - curl -I http://prometheus.kubequest.local"
    echo "  - curl -I http://dashboard.kubequest.local"
    ;;

  "tls")
    echo -e "${BLUE}📍 Vérification des certificats TLS${NC}"
    echo ""
    kubectl get certificates --all-namespaces
    echo ""
    echo "Détails d'un certificate:"
    echo "  kubectl describe certificate app-kubequest-tls -n laravel"
    echo ""
    echo "Logs cert-manager:"
    echo "  kubectl logs -n cert-manager deployment/cert-manager --tail=50"
    ;;

  "alerts")
    echo -e "${BLUE}📍 Vérification des alertes${NC}"
    echo ""
    kubectl get prometheusrules -n monitoring
    echo ""
    echo "Port-forward vers Prometheus:"
    echo "  kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090"
    echo ""
    echo "Ouvrir dans le navigateur:"
    echo "  - http://localhost:9090/rules"
    echo "  - http://localhost:9090/alerts"
    ;;

  "policies")
    echo -e "${BLUE}📍 Vérification des Network Policies${NC}"
    echo ""
    kubectl get networkpolicies --all-namespaces
    echo ""
    echo "Détails d'une policy:"
    echo "  kubectl describe networkpolicy laravel-policy -n laravel"
    ;;

  "status")
    echo -e "${BLUE}📍 État global du cluster${NC}"
    echo ""
    echo "=== Nodes ==="
    kubectl get nodes
    echo ""
    echo "=== Namespaces ==="
    kubectl get namespaces | grep -E "NAME|laravel|monitoring|ingress|cert-manager"
    echo ""
    echo "=== PVC ==="
    kubectl get pvc -n laravel
    echo ""
    echo "=== Ingress ==="
    kubectl get ingress --all-namespaces
    echo ""
    echo "=== Certificates ==="
    kubectl get certificates --all-namespaces
    echo ""
    echo "=== PrometheusRules ==="
    kubectl get prometheusrules -n monitoring
    echo ""
    echo "=== NetworkPolicies ==="
    kubectl get networkpolicies --all-namespaces
    ;;

  "full")
    echo -e "${GREEN}🚀 DÉPLOIEMENT COMPLET${NC}"
    echo ""
    echo "Cette commande va:"
    echo "  1. Vérifier les prérequis"
    echo "  2. Déployer les 5 points"
    echo "  3. Lancer les tests"
    echo ""
    read -p "Continuer? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      ./check-prerequis.sh
      ./deploy-production-ready.sh
      ./test-production-ready.sh
    fi
    ;;

  "help"|*)
    echo "Usage: ./QUICK_COMMANDS.sh <commande>"
    echo ""
    echo "Commandes disponibles:"
    echo ""
    echo -e "  ${GREEN}check${NC}       - Vérifier les prérequis"
    echo -e "  ${GREEN}deploy${NC}      - Déployer les 5 points"
    echo -e "  ${GREEN}test${NC}        - Lancer les tests automatisés"
    echo -e "  ${GREEN}backup${NC}      - Tester manuellement le backup"
    echo -e "  ${GREEN}ingress${NC}     - Vérifier les Ingress"
    echo -e "  ${GREEN}tls${NC}         - Vérifier les certificats TLS"
    echo -e "  ${GREEN}alerts${NC}      - Vérifier les alertes Prometheus"
    echo -e "  ${GREEN}policies${NC}    - Vérifier les Network Policies"
    echo -e "  ${GREEN}status${NC}      - État global du cluster"
    echo -e "  ${GREEN}full${NC}        - Déploiement complet (check + deploy + test)"
    echo ""
    echo "Exemples:"
    echo "  ./QUICK_COMMANDS.sh check"
    echo "  ./QUICK_COMMANDS.sh deploy"
    echo "  ./QUICK_COMMANDS.sh test"
    echo "  ./QUICK_COMMANDS.sh full"
    echo ""
    ;;
esac
