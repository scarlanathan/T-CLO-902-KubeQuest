#!/bin/bash
# Génère un kubeconfig local pour accéder au Kubernetes Dashboard
# Usage : bash scripts/dashboard/generate-kubeconfig.sh

set -e

KEY="${1:-$HOME/.ssh/kubequest.pem}"
NODE1="35.156.165.130"

echo "Récupération du token depuis node-1..."
TOKEN=$(ssh -i "$KEY" ec2-user@"$NODE1" \
  "kubectl -n kubernetes-dashboard get secret admin-user-token -o jsonpath='{.data.token}' | base64 -d")

OUTPUT="$(dirname "$0")/kubeconfig-dashboard.yaml"

sed "s|<REMPLACER_PAR_LE_TOKEN>|$TOKEN|g" \
  "$(dirname "$0")/kubeconfig-dashboard.template.yaml" > "$OUTPUT"

echo "Fichier généré : $OUTPUT"
echo ""
echo "1. Lancer le tunnel SSH dans un terminal :"
echo "   ssh -i $KEY -L 8001:localhost:8001 ec2-user@$NODE1 \"kubectl proxy --port=8001 --address=127.0.0.1\""
echo ""
echo "2. Ouvrir dans le navigateur :"
echo "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo ""
echo "3. Sélectionner Kubeconfig et uploader : $OUTPUT"
