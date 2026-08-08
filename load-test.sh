#!/bin/bash

###############################################################################
# KubeQuest Groupe 50 - Script de Test de Charge (Auto-scaling)
# Ce script envoie des requêtes en boucle pour démontrer l'auto-scaling
# Utilisation : ./load-test.sh
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Vérifier que l'application est accessible
check_app() {
    log_info "Vérification que l'application Laravel est accessible..."

    if ! curl -s -H "Host: app.kubequest.local" http://3.77.235.74:32222 > /dev/null; then
        log_error "Application non accessible !"
        log_error "Vérifiez que :"
        log_error "  1. Le cluster est up"
        log_error "  2. L'application est déployée (./deploy-all.sh)"
        log_error "  3. Vous avez ajouté '3.77.235.74  app.kubequest.local' à /etc/hosts"
        exit 1
    fi

    log_success "Application accessible"
}

# État initial
show_initial_state() {
    echo ""
    log_info "=== ÉTAT INITIAL AVANT TEST DE CHARGE ==="
    echo ""
    log_info "Pods Laravel :"
    kubectl get pods -n laravel
    echo ""
    log_info "HPA (Horizontal Pod Autoscaler) :"
    kubectl get hpa -n laravel || echo "HPA pas encore créé (normal si autoscaling disabled dans values.yaml)"
    echo ""
}

# Lancer le test de charge
run_load_test() {
    log_info "Démarrage du test de charge..."
    log_info "Envoi de requêtes en parallèle pour simuler une charge élevée"
    log_warning "Appuyez sur Ctrl+C pour arrêter le test"

    # Créer un fichier pour stocker les PIDs
    PID_FILE="/tmp/kubequest_load_test_pids.txt"
    echo "" > "$PID_FILE"

    # Fonction pour envoyer des requêtes en continu
    send_requests() {
        local worker_id=$1
        while true; do
            curl -s -H "Host: app.kubequest.local" \
                http://3.77.235.74:32222/api/counter/add > /dev/null 2>&1 || true
            echo -n "."
            sleep 0.05  # 20 requêtes/seconde par worker
        done
    }

    # Lancer 20 workers en parallèle (400 requêtes/seconde total)
    log_info "Lancement de 20 workers (400 requêtes/seconde)..."

    for i in {1..20}; do
        send_requests "$i" &
        echo $! >> "$PID_FILE"
    done

    # Surveiller pendant 60 secondes
    log_info "Surveillance de l'auto-scaling pendant 60 secondes..."
    log_info "Regardez les pods se multiplier !"
    echo ""

    for iteration in {1..12}; do
        echo "--- $(date +%H:%M:%S) ---"
        echo "Pods Laravel :"
        kubectl get pods -n laravel --no-headers | wc -l | tr -d ' ' | xargs echo "  Nombre de pods :"

        if kubectl get hpa -n laravel &> /dev/null; then
            echo "HPA :"
            kubectl get hpa -n laravel --no-columns | grep -v "REFS" | awk '{print "  Replicas: " $4 " / " $3 " (CPU: " $5 ")", "Memory: " $6 "%"}'
        fi

        sleep 5
    done

    echo ""
    log_info "Arrêt de tous les workers..."

    # Arrêter tous les processus
    if [ -f "$PID_FILE" ]; then
        while read pid; do
            kill "$pid" 2>/dev/null || true
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi

    # Kill all curl processes to be sure
    pkill -f "curl.*app.kubequest.local" || true

    log_success "Test de charge terminé"
}

# État final
show_final_state() {
    echo ""
    log_info "=== ÉTAT FINAL APRÈS TEST DE CHARGE ==="
    echo ""
    log_info "Pods Laravel :"
    kubectl get pods -n laravel
    echo ""
    log_info "HPA :"
    kubectl get hpa -n laravel 2>/dev/null || echo "HPA non disponible"
    echo ""
    log_success "L'auto-scaling a augmenté le nombre de replicas !"
    log_info "Attendez quelques minutes et les replicas vont redescendre (cool-down period)"
}

# Main
main() {
    echo "=========================================="
    echo "🔥 KUBEQUEST - TEST DE CHARGE (AUTO-SCALING)"
    echo "=========================================="
    echo ""

    check_app
    show_initial_state
    run_load_test
    show_final_state

    echo ""
    log_success "Test terminé !"
    echo ""
    echo "💡 Tip : Attendez 5-10 minutes et relancez ./load-test.sh pour voir l'auto-scaling à nouveau"
    echo "💡 Tip : Regardez dans Grafana (http://3.120.183.206:3000) pour voir les graphs de charge"
}

# Exécuter
main "$@"
