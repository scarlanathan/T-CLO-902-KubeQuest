#!/bin/bash
# install-k8s.sh
# Installe containerd + kubeadm sur les 4 noeuds via SSH
# Usage: ./install-k8s.sh

KEY="$HOME/.ssh/kubequest.pem"
NODES=(
    "35.156.165.130"   # node-1 control plane
    "3.79.247.101"     # node-2 worker
    "3.77.235.74"      # node-3 ingress
    "3.120.183.206"    # node-4 monitoring
)

REMOTE_SCRIPT='
set -e
echo "[1/5] Installation des dependances..."
sudo dnf install -y socat conntrack iproute-tc

echo "[2/5] Installation de containerd..."
sudo dnf install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/" /etc/containerd/config.toml
sudo systemctl enable --now containerd

echo "[3/5] Ajout du depot Kubernetes v1.31..."
sudo tee /etc/yum.repos.d/kubernetes.repo > /dev/null <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF

echo "[4/5] Installation de kubeadm kubelet kubectl..."
sudo dnf install -y kubelet kubeadm kubectl

echo "[5/5] Activation de kubelet..."
sudo systemctl enable --now kubelet

echo "=== DONE ==="
'

ALL_OK=true

for NODE in "${NODES[@]}"; do
    echo ""
    echo ">>> Connexion a $NODE ..."
    ssh -i "$KEY" -o StrictHostKeyChecking=no ec2-user@"$NODE" "$REMOTE_SCRIPT"
    if [ $? -eq 0 ]; then
        echo ">>> $NODE : OK"
    else
        echo ">>> $NODE : ERREUR"
        ALL_OK=false
    fi
done

if $ALL_OK; then
    echo ""
    echo "=== Tous les noeuds sont prets ==="
else
    echo ""
    echo "=== Des erreurs ont ete detectees ==="
fi
