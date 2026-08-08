#!/bin/bash

# Script de test de charge pour démontrer l'autoscaling

set -e

echo "========================================="
echo "Test de charge - Autoscaling Demo"
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
echo "État initial des pods:"
kubectl -n laravel-app get pods
echo ""

echo "État initial du HPA:"
kubectl -n laravel-app get hpa laravel-app
echo ""

# Obtenir le nombre initial de replicas
INITIAL_REPLICAS=$(kubectl -n laravel-app get deployment laravel-app -o jsonpath='{.spec.replicas}')
echo "Nombre initial de replicas: $INITIAL_REPLICAS"
echo ""

# Installer Apache Bench si nécessaire
if ! command -v ab &> /dev/null; then
    echo "Installation d'Apache Bench..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install apr-util
    else
        sudo apt-get install -y apache2-utils
    fi
fi

# Obtenir l'URL de l'application
APP_URL="https://larapp.kubequest.local"
echo "URL de l'application: $APP_URL"
echo ""

echo "========================================="
echo "Lancement du test de charge..."
echo "========================================="
echo ""

# Lancer le test de charge en arrière-plan
echo "Envoi de 10000 requêtes avec 100 requêtes simultanées..."
ab -n 10000 -c 100 $APP_URL/ > /tmp/load-test.log 2>&1 &
LOAD_TEST_PID=$!

echo "PID du test de charge: $LOAD_TEST_PID"
echo ""

# Surveiller le scaling en temps réel
echo "Surveillance du scaling en temps réel (Ctrl+C pour arrêter)..."
echo ""

for i in {1..30}; do
    echo "--- Iteration $i ---"
    kubectl -n laravel-app get pods
    kubectl -n laravel-app get hpa laravel-app

    # Vérifier si le test de charge est terminé
    if ! kill -0 $LOAD_TEST_PID 2>/dev/null; then
        echo "Test de charge terminé"
        break
    fi

    sleep 5
done

# Attendre que le scaling se stabilise
echo ""
echo "Attente de la stabilisation du scaling..."
sleep 30

echo ""
echo "========================================="
echo "Résultats finaux"
echo "========================================="
echo ""
echo "État final des pods:"
kubectl -n laravel-app get pods
echo ""
echo "État final du HPA:"
kubectl -n laravel-app get hpa laravel-app
echo ""

FINAL_REPLICAS=$(kubectl -n laravel-app get deployment laravel-app -o jsonpath='{.spec.replicas}')
echo "Nombre final de replicas: $FINAL_REPLICAS"
echo ""
echo "Échelle des replicas: $INITIAL_REPLICAS -> $FINAL_REPLICAS"
echo ""

if [ "$FINAL_REPLICAS" -gt "$INITIAL_REPLICAS" ]; then
    echo "✓ Autoscaling réussi ! Le nombre de pods a augmenté de $((FINAL_REPLICAS - INITIAL_REPLICAS))"
else
    echo "✗ Autoscaling non détecté. Vérifiez la configuration du HPA et les métriques."
fi

echo ""
echo "Résultats du test de charge:"
cat /tmp/load-test.log | grep -E "(Requests per second|Time taken|Failed requests)"

echo ""
echo "Les pods reviendront progressivement à leur nombre initial..."
