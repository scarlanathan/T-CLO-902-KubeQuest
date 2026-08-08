#!/bin/bash
# install-calico.sh
# Installe le plugin reseau Calico via SSH sur node-1
# Usage: ./install-calico.sh

KEY="$HOME/.ssh/kubequest.pem"
NODE1="35.156.165.130"

REMOTE_SCRIPT='
set -e
echo "Installation de Calico CNI..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
echo "=== DONE ==="
'

echo ">>> Installation de Calico sur le cluster..."
ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE1" "$REMOTE_SCRIPT"

if [ $? -eq 0 ]; then
    echo ""
    echo ">>> Calico installe ! Attente 30s..."
    sleep 30
    ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE1" "kubectl get nodes -o wide"
else
    echo ">>> ERREUR lors de l'installation de Calico"
fi
