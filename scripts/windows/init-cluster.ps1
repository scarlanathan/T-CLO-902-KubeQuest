# init-cluster.ps1
# Initialise le cluster Kubernetes sur node-1 (control plane)

$key = "$env:USERPROFILE\.ssh\kubequest.pem"
$node1 = "35.156.165.130"

$script = @'
set -e
echo "[1/3] Desactivation du swap..."
sudo swapoff -a

echo "[2/3] Activation des modules kernel..."
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "[3/3] Initialisation du cluster kubeadm..."
sudo kubeadm init \
  --apiserver-advertise-address=10.2.50.23 \
  --pod-network-cidr=192.168.0.0/16 \
  --node-name=node-1

echo "=== Configuration kubectl ==="
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "=== DONE ==="
'@

Write-Host ">>> Initialisation du cluster sur node-1 ($node1)..." -ForegroundColor Cyan

$logFile = "$PSScriptRoot\logs\init-cluster.log"
ssh -i $key -o StrictHostKeyChecking=no ec2-user@$node1 $script 2>&1 | Tee-Object -FilePath $logFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n>>> Cluster initialise avec succes !" -ForegroundColor Green
    Write-Host ">>> Recuperation de la commande kubeadm join..."

    # Recuperer la commande join
    $joinCmd = ssh -i $key -o StrictHostKeyChecking=no ec2-user@$node1 "kubeadm token create --print-join-command 2>/dev/null"
    Write-Host "`n=== COMMANDE JOIN (a utiliser pour les autres noeuds) ===" -ForegroundColor Yellow
    Write-Host $joinCmd -ForegroundColor White
    $joinCmd | Out-File -FilePath "$PSScriptRoot\logs\join-command.txt" -Encoding ascii
    Write-Host "`nSauvegarde dans: $PSScriptRoot\logs\join-command.txt" -ForegroundColor Green
} else {
    Write-Host "`n>>> ERREUR - voir $logFile" -ForegroundColor Red
}
