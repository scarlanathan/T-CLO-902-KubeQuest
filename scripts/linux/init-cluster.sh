#!/bin/bash
# init-cluster.sh
# Initialise le cluster Kubernetes sur node-1 via SSH
# Usage: ./init-cluster.sh

KEY="$HOME/.ssh/kubequest.pem"
NODE1="35.156.165.130"
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"

REMOTE_SCRIPT='
set -e
echo "[1/3] Desactivation du swap et configuration kernel..."
sudo swapoff -a
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "[2/3] Initialisation du cluster..."
sudo kubeadm init \
  --apiserver-advertise-address=10.2.50.23 \
  --pod-network-cidr=192.168.0.0/16 \
  --node-name=node-1

echo "[3/3] Configuration kubectl..."
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "=== DONE ==="
'

echo ">>> Initialisation du cluster sur node-1 ($NODE1)..."
ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE1" "$REMOTE_SCRIPT" 2>&1 | tee "$LOG_DIR/init-cluster.log"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo ">>> Cluster initialise avec succes !"
    echo ">>> Recuperation de la commande join..."
    JOIN_CMD=$(ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE1" "kubeadm token create --print-join-command 2>/dev/null")
    echo "$JOIN_CMD" > "$LOG_DIR/join-command.txt"
    echo ""
    echo "=== COMMANDE JOIN ==="
    echo "$JOIN_CMD"
    echo "Sauvegarde dans: $LOG_DIR/join-command.txt"
else
    echo ">>> ERREUR - voir $LOG_DIR/init-cluster.log"
fi
