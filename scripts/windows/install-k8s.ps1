# install-k8s.ps1
# Installe kubeadm, kubelet, kubectl sur tous les noeuds

$key = "$env:USERPROFILE\.ssh\kubequest.pem"
$nodes = @(
    "35.156.165.130",  # node-1 control plane
    "3.79.247.101",    # node-2 worker
    "3.77.235.74",     # node-3 ingress
    "3.120.183.206"    # node-4 monitoring
)

$script = @'
set -e
echo "[1/5] Installation des dependances..."
sudo dnf install -y socat conntrack iproute-tc

echo "[2/5] Installation de containerd..."
sudo dnf install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl enable --now containerd

echo "[3/5] Ajout du depot Kubernetes..."
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
'@

$logDir = "$PSScriptRoot\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$allOk = $true

foreach ($node in $nodes) {
    Write-Host "`n>>> Connexion a $node ..." -ForegroundColor Cyan
    $logFile = "$logDir\install-$node.log"

    ssh -i $key -o StrictHostKeyChecking=no ec2-user@$node $script 2>&1 | Tee-Object -FilePath $logFile

    if ($LASTEXITCODE -eq 0) {
        Write-Host ">>> $node : OK" -ForegroundColor Green
    } else {
        Write-Host ">>> $node : ERREUR (voir $logFile)" -ForegroundColor Red
        $allOk = $false
    }
}

if ($allOk) {
    Write-Host "`n=== Tous les noeuds sont prets ===" -ForegroundColor Green
} else {
    Write-Host "`n=== Des erreurs ont ete detectees, verifiez les logs dans $logDir ===" -ForegroundColor Red
}
