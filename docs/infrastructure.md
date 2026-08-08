# Infrastructure KubeQuest — Groupe 50

## Informations des nœuds AWS

| Nœud | Rôle | IP Publique | IP Privée |
|------|------|-------------|-----------|
| node-1 (`ec2-group-50-node-1`) | Plan de contrôle Kubernetes | 35.156.165.130 | 10.2.50.23 |
| node-2 (`ec2-group-50-node-2`) | Nœud Worker | _à rafraîchir_ ⚠️ | 10.2.50.190 |
| node-3 (`ec2-group-50-node-3`) | Contrôleur Ingress | 3.77.235.74 | 10.2.50.90 |
| node-4 (`ec2-group-50-node-4`) | Monitoring (Prometheus/Grafana/Loki) | 3.120.183.206 | 10.2.50.113 |

> **Vérifié le 2026-06-11** : node-1 joignable en SSH à `35.156.165.130` ; les 4 nœuds sont `Ready`.
> ⚠️ L'IP publique de **node-2** a changé (l'ancienne `3.79.247.101` ne répond plus en SSH) — la récupérer dans la console EC2 avant toute connexion directe. Les IP de node-3/node-4 sont peut-être également obsolètes.

## Accès SSH

- **Clé privée** : stockée dans AWS Systems Manager Parameter Store
  - Chemin : `/kubequest/group-50/ssh-private-key`
  - ARN : `arn:aws:ssm:eu-central-1:649966626926:parameter/kubequest/group-50/ssh-private-key`
- **Région AWS** : `eu-central-1`
- **Utilisateur SSH** : `ec2-user`
- **OS** : Amazon Linux 2023

### Commande de connexion

```bash
# Récupérer la clé depuis SSM (depuis AWS CloudShell)
aws ssm get-parameter \
  --name "/kubequest/group-50/ssh-private-key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > ~/.ssh/kubequest.pem
chmod 400 ~/.ssh/kubequest.pem

# Connexion aux nœuds
ssh -i ~/.ssh/kubequest.pem ec2-user@35.156.165.130  # node-1 (control plane)
ssh -i ~/.ssh/kubequest.pem ec2-user@3.79.247.101    # node-2 (worker)
ssh -i ~/.ssh/kubequest.pem ec2-user@3.77.235.74     # node-3 (ingress)
ssh -i ~/.ssh/kubequest.pem ec2-user@3.120.183.206   # node-4 (monitoring)
```

## Remarques importantes

- Les machines s'éteignent automatiquement chaque nuit — les redémarrer manuellement depuis la console AWS avant chaque session de travail.
- Les IP publiques **peuvent changer** à chaque redémarrage — toujours vérifier dans la console AWS.
- Les IP privées (`10.2.50.x`) sont stables et utilisées pour la communication interne du cluster.

## État d'avancement

> État vérifié en live sur le cluster le 2026-06-11.

- [x] Nœuds AWS démarrés et accessibles
- [x] Installation de kubeadm / kubelet / kubectl sur tous les nœuds (v1.31.14)
- [x] Initialisation du cluster Kubernetes (node-1)
- [x] Jonction des nœuds worker (node-2, node-3, node-4) — tous `Ready`
- [x] Installation du plugin réseau (Calico) — `CalicoIsUp` sur les nœuds
- [x] Installation de nginx-ingress
- [x] Installation de kube-prometheus (monitoring)
- [x] Installation de Loki (logs)
- [x] Déploiement de l'application Laravel (Helm Chart) — pods `laravel` + `mysql-0` `Running` sur node-2
- [ ] Configuration GitOps (Kustomize / ArgoCD)
