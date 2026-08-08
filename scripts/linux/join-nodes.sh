#!/bin/bash
# join-nodes.sh
# Fait rejoindre node-2, node-3, node-4 au cluster via SSH
# Usage: ./join-nodes.sh

KEY="$HOME/.ssh/kubequest.pem"
NODE1="35.156.165.130"
LOG_DIR="$(dirname "$0")/../logs"
WORKERS=(
    "3.79.247.101"     # node-2 worker
    "3.77.235.74"      # node-3 ingress
    "3.120.183.206"    # node-4 monitoring
)

JOIN_CMD=$(cat "$LOG_DIR/join-command.txt" 2>/dev/null)
if [ -z "$JOIN_CMD" ]; then
    echo "ERREUR: $LOG_DIR/join-command.txt introuvable."
    echo "Lancez d'abord init-cluster.sh"
    exit 1
fi

ALL_OK=true

for NODE in "${WORKERS[@]}"; do
    echo ""
    echo ">>> Jonction de $NODE au cluster..."

    REMOTE_SCRIPT="
set -e
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sudo $JOIN_CMD
"
    ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE" "$REMOTE_SCRIPT" 2>&1 | tee "$LOG_DIR/join-$NODE.log"
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo ">>> $NODE : OK"
    else
        echo ">>> $NODE : ERREUR"
        ALL_OK=false
    fi
done

if $ALL_OK; then
    echo ""
    echo "=== Tous les noeuds ont rejoint le cluster ==="
    echo ""
    ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE1" "kubectl get nodes"
else
    echo ""
    echo "=== Des erreurs ont ete detectees ==="
fi
