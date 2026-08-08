# Infrastructure Terraform - T-CLO-902

Ce projet Terraform provisionne 4 machines virtuelles AWS EC2 pour le projet Kubernetes.

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│     kube-1      │         │     kube-2      │
│  (10.0.1.10)   │         │  (10.0.1.11)    │
│  Kubernetes     │         │  Kubernetes     │
│   Node 1       │         │   Node 2        │
└────────┬────────┘         └────────┬────────┘
         │                          │
         └──────────┬───────────────┘
                    │
         ┌──────────▼───────────┐
         │                    │
┌────────▼────────┐    ┌──────▼──────────┐
│     ingress     │    │    monitoring   │
│  (10.0.1.12)    │    │   (10.0.1.13)   │
│  nginx-ingress  │    │  Prometheus +   │
│   Controller   │    │     Grafana     │
└─────────────────┘    └─────────────────┘
```

## Instances

1. **kube-1** : Premier nœud Kubernetes (t3.medium, 30GB)
2. **kube-2** : Deuxième nœud Kubernetes (t3.medium, 30GB)
3. **ingress** : Contrôleur Ingress (t3.medium, 20GB)
4. **monitoring** : Serveur de monitoring (t3.medium, 30GB)

## Prérequis

### 1. Installer Terraform

```bash
# Sur macOS
brew install terraform

# Vérifier l'installation
terraform version
```

### 2. Obtenir vos credentials AWS

Vous avez deux options :

#### Option A : Via la console AWS IAM

1. Connectez-vous à : https://649966626926.signin.aws.amazon.com/console
2. Allez dans **IAM** → **Users** → **student-frankfurt-group-50**
3. Cliquez sur **Security credentials**
4. Créez ou récupérez vos **Access Keys**
5. Sauvegardez l'Access Key ID et Secret Access Key

#### Option B : Via AWS CLI (si installé)

```bash
aws configure
```

## Configuration

### 1. Créer le fichier terraform.tfvars

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Éditer terraform.tfvars avec vos credentials

```bash
nano terraform.tfvars
```

Remplacez avec vos vraies valeurs :
```hcl
aws_access_key = "AKIAIOSFODNN7EXAMPLE"
aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

### 3. Ajouter terraform.tfvars au .gitignore (dÉjà fait)

```bash
# Vérifier que terraform.tfvars est dans .gitignore
cat .gitignore | grep tfvars
```

## Déploiement

### Étape 1 : Initialiser Terraform

```bash
cd terraform
terraform init
```

Cela télécharge les providers AWS nécessaires.

### Étape 2 : Valider la configuration

```bash
terraform validate
```

### Étape 3 : Planifier le déploiement

```bash
terraform plan
```

Cela montre ce qui va être créé sans vraiment le faire.

**Répondez `yes` si le plan looks correct.**

### Étape 4 : Appliquer la configuration

```bash
terraform apply
```

Terraform va créer :
- 1 VPC (10.0.0.0/16)
- 1 Subnet publique (10.0.1.0/24)
- 1 Internet Gateway
- 1 Route Table
- 3 Security Groups (kubernetes-nodes, ingress, monitoring)
- 4 Instances EC2 avec les prérequis installés

**Le déploiement prend environ 5-10 minutes.**

### Étape 5 : Récupérer les informations de connexion

Une fois terminé, Terraform affichera les outputs :

```
Outputs:

ingress_public_ip = "xx.xx.xx.xx"
ingress_private_ip = "10.0.1.12"
kube_1_public_ip = "xx.xx.xx.xx"
kube_1_private_ip = "10.0.1.10"
kube_2_public_ip = "xx.xx.xx.xx"
kube_2_private_ip = "10.0.1.11"
monitoring_public_ip = "xx.xx.xx.xx"
monitoring_private_ip = "10.0.1.13"
ssh_connection_example = "ssh -i ssh-key-group-50.pem ubuntu@xx.xx.xx.xx"
ssh_key_path = "ssh-key-group-50.pem"
vpc_id = "vpc-xxxxxxxx"
```

## Vérification de l'accès SSH

### 1. La clé SSH a été téléchargée automatiquement

Vérifiez que la clé existe :
```bash
ls -lh ssh-key-group-50.pem
```

### 2. Connectez-vous à chaque VM

```bash
# kube-1
ssh -i ssh-key-group-50.pem ubuntu@<IP_PUBLIQUE_KUBE_1>

# kube-2
ssh -i ssh-key-group-50.pem ubuntu@<IP_PUBLIQUE_KUBE_2>

# ingress
ssh -i ssh-key-group-50.pem ubuntu@<IP_PUBLIQUE_INGRESS>

# monitoring
ssh -i ssh-key-group-50.pem ubuntu@<IP_PUBLIQUE_MONITORING>
```

### 3. Vérifier l'installation des prérequis

Sur chaque VM, exécutez :

```bash
# Vérifier Docker/containerd
docker --version
containerd --version

# Sur kube-1 et kube-2, vérifier Kubernetes
kubeadm version
kubectl version
kubelet --version

# Vérifier que les services sont actifs
sudo systemctl status docker
sudo systemctl status containerd
```

## Vérification des tags AWS

Allez dans la console AWS EC2 :
https://eu-central-1.console.aws.amazon.com/ec2/home?region=eu-central-1#Instances:search=:group-50

Vérifiez que chaque instance a les bons tags :
- **Name** : kube-1, kube-2, ingress, monitoring
- **Role** : kubernetes-node, ingress-controller, monitoring-server
- **Project** : T-CLO-902
- **Group** : group-50
- **Environment** : education

## Prochaines étapes

### 1. Initialiser le cluster Kubernetes sur kube-1

```bash
# SSH sur kube-1
ssh -i ssh-key-group-50.pem ubuntu@<IP_KUBE_1>

# Initialiser le cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=<IP_PRIVÉE_KUBE_1>

# Configurer kubectl
mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérifier
kubectl get nodes
```

### 2. Installer le réseau CNI (Flannel)

```bash
# Sur kube-1
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### 3. Joindre kube-2 au cluster

```bash
# Récupérer la commande join depuis kube-1
kubeadm token create --print-join-command

# Sur kube-2
ssh -i ssh-key-group-50.pem ubuntu@<IP_KUBE_2>
sudo <command_join_à_copier>

# Retour sur kube-1, vérifier
kubectl get nodes
```

### 4. Configurer nginx-ingress sur la VM ingress

(Voir le guide séparé pour la configuration d'ingress)

### 5. Installer Prometheus et Grafana sur monitoring

```bash
# SSH sur monitoring
ssh -i ssh-key-group-50.pem ubuntu@<IP_MONITORING>

# Créer docker-compose.yml pour Prometheus et Grafana
# (Voir section monitoring plus bas)
```

## Monitoring Stack (Docker Compose)

Sur la VM monitoring, créez `/home/ubuntu/docker-compose.yml` :

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - "9090:9090"
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    restart: unless-stopped

  node_exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
```

Et `/home/ubuntu/prometheus.yml` :

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'kubernetes_nodes'
    static_configs:
      - targets: ['<IP_PRIVÉE_KUBE_1>:9100', '<IP_PRIVÉE_KUBE_2>:9100']
```

Lancez :
```bash
cd /home/ubuntu
docker-compose up -d
```

Accédez à :
- **Prometheus** : http://<IP_MONITORING>:9090
- **Grafana** : http://<IP_MONITORING>:3000 (admin/admin)

## Gestion de l'infrastructure

### Voir l'état des ressources

```bash
terraform show
```

### Détruire toute l'infrastructure

```bash
terraform destroy
```

⚠️ **ATTENTION** : Cela détruira toutes les ressources créées.

### Mettre à jour la configuration

1. Modifiez `main.tf`
2. `terraform plan` pour voir les changements
3. `terraform apply` pour appliquer

## Documentation des commandes utilisées

### Terraform
```bash
terraform init          # Initialiser le projet
terraform validate      # Valider la syntaxe
terraform plan          # Planifier les changements
terraform apply         # Appliquer les changements
terraform destroy       # Détruire les ressources
terraform output        # Voir les outputs
terraform show          # Voir l'état complet
```

### SSH et vérification
```bash
# Connexion SSH
ssh -i ssh-key-group-50.pem ubuntu@<IP>

# Vérifier les services
systemctl status docker
systemctl status containerd
systemctl status kubelet

# Vérifier Kubernetes
kubectl get nodes
kubectl get pods --all-namespaces
```

## Sécurité

✅ **Bonnes pratiques appliquées :**
- Clés SSH avec permissions 0400
- Security groups restrictifs
- Tags pour identification
- HTTPS uniquement (pas de HTTP en production)
- Isolation dans VPC dédié

⚠️ **Points à améliorer pour la production :**
- Utiliser AWS Secrets Manager au lieu de terraform.tfvars
- Activer AWS CloudTrail
- Configurer des IAM roles spécifiques
- Utiliser un bastion host pour SSH
- Activer GuardDuty pour la sécurité

## Coûts estimés

Les coûts AWS pour cette infrastructure (eu-central-1) :

- **Instances EC2** : 4 x t3.medium @ ~$0.04/heure = $0.16/heure
- **Stockage EBS** : 110 GB total @ ~$0.08/GB/mois = $8.80/mois
- **Transfert de données** : Variable
- **Total estimé** : ~$120-150/mois si 24/7

**Pensez à éteindre les instances quand vous ne les utilisez pas !**

### Éteindre les instances (sans détruire l'infrastructure)

```bash
# Via AWS CLI
aws ec2 stop-instances --instance-ids <INSTANCE_ID_1> <INSTANCE_ID_2> ...

# Ou via Terraform (non recommandé pour stop/start)
terraform apply -var='instances_running=false'
```

## Dépannage

### Erreur : "Error: error configuring Terraform AWS Provider"

Vérifiez vos credentials dans `terraform.tfvars`.

### Erreur : "Timeout waiting for SSH"

Les instances prennent du temps à démarrer (user_data). Attendez 2-3 minutes.

### Erreur : "Permission denied (publickey)"

Vérifiez que la clé SSH a les bons permissions :
```bash
chmod 400 ssh-key-group-50.pem
```

### kubeadm échoue

Vérifiez que swap est désactivé :
```bash
sudo swapoff -a
free -m
```

## Ressources

- [Documentation Terraform](https://www.terraform.io/docs)
- [Provider AWS Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Documentation kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Documentation nginx-ingress](https://kubernetes.github.io/ingress-nginx/)
- [Votre projet GitHub](https://github.com/EpitechMscProPromo2026/T-CLO-902-PAR_5)

## Support

En cas de problème :
1. Vérifiez les logs Terraform : `terraform show`
2. Vérifiez la console AWS EC2
3. Consultez les logs des instances via AWS Console → EC2 → Instances → Actions → Instance Settings → Get system log
