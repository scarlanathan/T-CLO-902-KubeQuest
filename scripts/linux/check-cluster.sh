#!/bin/bash
# check-cluster.sh
# Verifie l'etat du cluster via SSH depuis node-1
# Usage: ./check-cluster.sh

KEY="$HOME/.ssh/kubequest.pem"
NODE1="35.156.165.130"

echo "=== Etat des noeuds ==="
ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE1" "kubectl get nodes -o wide"

echo ""
echo "=== Pods systeme ==="
ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE1" "kubectl get pods -n kube-system"
