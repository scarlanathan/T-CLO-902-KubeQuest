# join-nodes.ps1
# Fait rejoindre node-2, node-3, node-4 au cluster Kubernetes

$key = "$env:USERPROFILE\.ssh\kubequest.pem"
$workers = @(
    "3.79.247.101",    # node-2 worker
    "3.77.235.74",     # node-3 ingress
    "3.120.183.206"    # node-4 monitoring
)

$joinCmd = Get-Content "$PSScriptRoot\logs\join-command.txt" -Raw
$joinCmd = $joinCmd.Trim()

$script = @"
set -e
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sudo $joinCmd
"@

$allOk = $true

foreach ($node in $workers) {
    Write-Host "`n>>> Jonction de $node au cluster..." -ForegroundColor Cyan
    $logFile = "$PSScriptRoot\logs\join-$node.log"

    ssh -i $key -o StrictHostKeyChecking=no ec2-user@$node $script 2>&1 | Tee-Object -FilePath $logFile

    if ($LASTEXITCODE -eq 0) {
        Write-Host ">>> $node : OK" -ForegroundColor Green
    } else {
        Write-Host ">>> $node : ERREUR (voir $logFile)" -ForegroundColor Red
        $allOk = $false
    }
}

if ($allOk) {
    Write-Host "`n=== Tous les noeuds ont rejoint le cluster ===" -ForegroundColor Green
    Write-Host "`nVerification de l'etat du cluster..."
    $key2 = "$env:USERPROFILE\.ssh\kubequest.pem"
    ssh -i $key2 -o StrictHostKeyChecking=no ec2-user@35.156.165.130 "kubectl get nodes"
} else {
    Write-Host "`n=== Des erreurs ont ete detectees ===" -ForegroundColor Red
}
