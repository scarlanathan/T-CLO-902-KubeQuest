# install-calico.ps1
# Installe le plugin reseau Calico sur le cluster

$key = "$env:USERPROFILE\.ssh\kubequest.pem"
$node1 = "35.156.165.130"

$script = @'
set -e
echo "Installation de Calico CNI..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo "Attente que les noeuds soient Ready (max 3 minutes)..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo "=== Etat du cluster ==="
kubectl get nodes -o wide
'@

Write-Host ">>> Installation de Calico sur le cluster..." -ForegroundColor Cyan
ssh -i $key -o StrictHostKeyChecking=no ec2-user@$node1 $script 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n>>> Calico installe avec succes !" -ForegroundColor Green
} else {
    Write-Host "`n>>> ERREUR lors de l'installation de Calico" -ForegroundColor Red
}
