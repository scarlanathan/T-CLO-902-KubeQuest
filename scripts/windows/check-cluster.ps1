# check-cluster.ps1
$key = "$env:USERPROFILE\.ssh\kubequest.pem"
$node1 = "35.156.165.130"

Write-Host "=== Etat des noeuds ===" -ForegroundColor Cyan
ssh -i $key -o StrictHostKeyChecking=no ec2-user@$node1 "kubectl get nodes -o wide"

Write-Host "`n=== Pods systeme ===" -ForegroundColor Cyan
ssh -i $key -o StrictHostKeyChecking=no ec2-user@$node1 "kubectl get pods -n kube-system"
