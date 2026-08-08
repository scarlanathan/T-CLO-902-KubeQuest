# Guide de Déploiement Rapide - T-CLO-902

Guide étape par étape pour provisionner 4 VMs AWS et configurer Ingress.

## 📋 Checklist

- [ ] Terraform installé ✅ (déjà fait)
- [ ] Credentials AWS obtenus
- [ ] 4 VMs provisionnées
- [ ] Accès SSH vérifié
- [ ] Kubernetes installé
- [ ] nginx-ingress configuré
- [ ] Tests HTTP/HTTPS passés

## Étape 1 : Obtenir vos Credentials AWS

### 1.1 Se connecter à AWS

```
URL: https://649966626926.signin.aws.amazon.com/console
Username: student-frankfurt-group-50
Password: JioPoulet98/
```

### 1.2 Créer des Access Keys

1. Cliquez sur votre nom en haut à droite → **Security Credentials**
2. Scrollez à **Access keys** → Cliquez sur **Create access key**
3. Choisissez **Application running outside AWS**
4. **IMPORTANT** : Copiez et sauvegardez immédiatement :
   - **Access Key ID** (commence par AKIA...)
   - **Secret Access Key** (longue chaîne de caractères)

⚠️ **Vous ne verrez le Secret Access Key qu'une seule fois !**

### Alternative : Via la console IAM

1. Allez dans **IAM** → **Users** → **student-frankfurt-group-50**
2. Cliquez sur **Security credentials**
3. Section **Access keys** → **Create access key**
4. Sauvegardez les deux clés

## Étape 2 : Configurer Terraform

### 2.1 Créer le fichier terraform.tfvars

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2.2 Éditer avec VOS credentials

```bash
nano terraform.tfvars
```

Remplacez avec VOS vraies valeurs :

```hcl
aws_access_key = "AKIAIOSFODNN7EXXXXXX"  # Remplacez avec votre Access Key
aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # Remplacez avec votre Secret
```

Sauvegardez (Ctrl+O, Entrée, Ctrl+X)

## Étape 3 : Provisionner les 4 VMs

### 3.1 Initialiser Terraform

```bash
cd terraform
terraform init
```

Output attendu :
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x...
...
Terraform has been successfully initialized!
```

### 3.2 Vérifier le plan

```bash
terraform plan
```

Terraform va afficher toutes les ressources qu'il va créer :
- 1 VPC
- 1 Subnet
- 1 Internet Gateway
- 3 Security Groups
- 4 Instances EC2 (kube-1, kube-2, ingress, monitoring)

Si tout looks good, répondez `yes` ou continuez.

### 3.3 Appliquer

```bash
terraform apply
```

Quand Terraform demande confirmation, tapez `yes` et Entrée.

**⏱️ Le déploiement prend environ 5-10 minutes**

### 3.4 Récupérer les informations

Une fois terminé, Terraform affiche les outputs :

```
Apply complete! Resources: X added, 0 changed, 0 destroyed.

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

**SAUVEGARDER CES INFORMATIONS !**

## Étape 4 : Vérifier l'accès SSH

### 4.1 La clé SSH a été téléchargée

Vérifiez :
```bash
ls -lh terraform/ssh-key-group-50.pem
```

Output attendu : `-r-------- 1 votre_user staff 1.7K Jun 11 15:30 ssh-key-group-50.pem`

### 4.2 Tester SSH sur chaque VM

```bash
# kube-1
ssh -i terraform/ssh-key-group-50.pem ubuntu@<IP_KUBE_1_PUBLIC>

# kube-2
ssh -i terraform/ssh-key-group-50.pem ubuntu@<IP_KUBE_2_PUBLIC>

# ingress
ssh -i terraform/ssh-key-group-50.pem ubuntu@<IP_INGRESS_PUBLIC>

# monitoring
ssh -i terraform/ssh-key-group-50.pem ubuntu@<IP_MONITORING_PUBLIC>
```

Si vous voyez le prompt ubuntu@... c'est que SSH fonctionne ! ✅

### 4.3 Vérifier les installations

Sur chaque VM (via SSH), exécutez :

```bash
# Sur kube-1 et kube-2
docker --version
kubeadm version
kubectl version
kubelet --version

# Sur ingress
docker --version
nginx -v

# Sur monitoring
docker --version
node_exporter --version
```

## Étape 5 : Vérifier les tags dans AWS Console

Allez sur :
https://eu-central-1.console.aws.amazon.com/ec2/home?region=eu-central-1#Instances:search=:group-50

Vérifiez que chaque instance a les bons tags :
- ✅ **Name** : kube-1, kube-2, ingress, monitoring
- ✅ **Role** : kubernetes-node, ingress-controller, monitoring-server
- ✅ **Project** : T-CLO-902
- ✅ **Group** : group-50
- ✅ **Environment** : education

## Étape 6 : Initialiser Kubernetes

### 6.1 Sur kube-1 - Initialiser le cluster

```bash
ssh -i terraform/ssh-key-group-50.pem ubuntu@<IP_KUBE_1_PUBLIC>

# Initialiser Kubernetes
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=<IP_KUBE_1_PRIVÉE> \
  --ignore-preflight-errors=NumCPU

# Configurer kubectl
mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérifier que le nœud est Ready (attendre ~30 secondes)
kubectl get nodes
```

Attendre que kube-1 passe en status `Ready` (peut prendre 1-2 minutes).

### 6.2 Installer le réseau Flannel

```bash
# Sur kube-1
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Attendre 1-2 minutes
kubectl get pods -n kube-flannel
```

### 6.3 Récupérer la commande join

```bash
# Sur kube-1
kubeadm token create --print-join-command
```

**Copiez la commande affichée**, elle ressemble à :
```
sudo kubeadm join 10.0.1.10:6443 --token xxxxx.xxx --discovery-token-ca-cert-hash sha256:xxxxx
```

### 6.4 Joindre kube-2 au cluster

```bash
# Sur kube-2
ssh -i terraform/ssh-key-group-50.pem ubuntu@<IP_KUBE_2_PUBLIC>

# Coller la commande join ici
sudo kubeadm join 10.0.1.10:6443 --token xxxxx.xxx --discovery-token-ca-cert-hash sha256:xxxxx
```

### 6.5 Vérifier que les deux nœuds sont Ready

```bash
# Sur kube-1
kubectl get nodes
```

Output attendu :
```
NAME     STATUS   ROLES           AGE   VERSION
kube-1   Ready    control-plane   5m    v1.28.x
kube-2   Ready    <none>          2m    v1.28.x
```

## Étape 7 : Configurer nginx-ingress sur la VM ingress

### 7.1 Copier la configuration kubeconfig

```bash
# Sur ingress
ssh -i terraform/ssh-key-group-50.pem ubuntu@<IP_INGRESS_PUBLIC>

# Créer le fichier kubeconfig manuellement
mkdir -p ~/.kube
nano ~/.kube/config
```

Copiez le contenu de `/home/ubuntu/.kube/config` depuis kube-1 vers ingress :
```bash
# Depuis votre machine locale
scp -i terraform/ssh-key-group-50.pem ubuntu@<IP_KUBE_1_PUBLIC>:.kube/config ./
scp -i terraform/ssh-key-group-50.pem ./config ubuntu@<IP_INGRESS_PUBLIC>:.kube/config
ssh -i terraform/ssh-key-group-50.pem ubuntu@<IP_INGRESS_PUBLIC> "chmod 600 ~/.kube/config"
```

### 7.2 Installer Helm sur ingress

```bash
# Sur ingress
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 7.3 Déployer nginx-ingress

```bash
# Sur ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443

# Vérifier le déploiement
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 7.4 Déployer une application de test

```bash
# Sur ingress
kubectl create namespace test-app

# Déployer un simple serveur HTTP
kubectl run echo-server \
  --image=ealen/echo-server:latest \
  --namespace=test-app \
  --port=80 \
  --expose \
  --port=80

# Créer l'Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo-ingress
  namespace: test-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: echo.kubequest.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: echo-server
            port:
              number: 80
EOF
```

## Étape 8 : Tester l'accès HTTP

### 8.1 Récupérer l'IP de ingress

```bash
# Sur votre machine locale
echo "IP_INGRESS_PUBLIC=<IP_PUBLIQUE_INGRESS>"
```

### 8.2 Configurer le DNS local

```bash
# Sur votre machine locale (macOS)
echo "<IP_INGRESS_PUBLIC>  echo.kubequest.local" | sudo tee -a /etc/hosts
```

### 8.3 Tester HTTP

```bash
# Test basique
curl http://echo.kubequest.local:30080

# Test détaillé
curl -v http://echo.kubequest.local:30080
```

Output attendu :
```json
{
  "request": {
    "host": "echo.kubequest.local:30080",
    ...
  }
}
```

### 8.4 Test HTTPS (optionnel - sans certificat SSL)

```bash
# On utilise HTTP pour le test
curl -v http://echo.kubequest.local:30080
```

## Étape 9 : Documentation et Validation

### 9.1 Créer le document de validation

Créez `VALIDATION.md` avec :

```markdown
# Validation du Projet T-CLO-902

## Infrastructure

- [x] 4 VMs EC2 provisionnées via Terraform
- [x] VPC et réseau configuré
- [x] Security groups créés et configurés
- [x] Tags correctement appliqués

## Instances

- kube-1 : <IP_PUBLIQUE> (<IP_PRIVÉE>) ✅
- kube-2 : <IP_PUBLIQUE> (<IP_PRIVÉE>) ✅
- ingress : <IP_PUBLIQUE> (<IP_PRIVÉE>) ✅
- monitoring : <IP_PUBLIQUE> (<IP_PRIVÉE>) ✅

## Kubernetes

- [x] Cluster initialisé sur kube-1
- [x] kube-2 joint au cluster
- [x] Flannel CNI installé
- [x] 2 nœuds en status Ready

## Ingress

- [x] nginx-ingress installé
- [x] Service exposé sur NodePort 30080
- [x] Application de test déployée
- [x] Ingress configuré pour echo.kubequest.local

## Tests

### Test HTTP
\`\`\`bash
$ curl http://echo.kubequest.local:30080
<OUTPUT>
\`\`\`

### Test SSH
\`\`\`bash
$ ssh -i ssh-key-group-50.pem ubuntu@<IP_KUBE_1>
$ kubectl get nodes
NAME     STATUS   ROLES           AGE   VERSION
kube-1   Ready    control-plane   10m   v1.28.x
kube-2   Ready    <none>          8m    v1.28.x
\`\`\`

## Commandes utilisées

### Terraform
\`\`\`bash
terraform init
terraform plan
terraform apply
\`\`\`

### Kubernetes
\`\`\`bash
kubeadm init --pod-network-cidr=10.244.0.0/16
kubectl apply -f https://...flannel.yml
kubeadm join ...
\`\`\`

### Ingress
\`\`\`bash
helm install ingress-nginx ingress-nginx/ingress-nginx ...
kubectl apply -f ingress.yaml
\`\`\`

## Coûts

Estimation mensuelle : ~$120-150 pour 24/7
- 4 x t3.medium : $0.16/heure
- Stockage 110 GB : $8.80/mois
```

### 9.2 Captures d'écran à prendre

1. **Console AWS EC2** : Vue des 4 instances avec tags
2. **kubectl get nodes** : Les 2 nœuds Ready
3. **kubectl get pods -n ingress-nginx** : nginx-ingress pods running
4. **curl test** : Output de la requête HTTP
5. **Ingress dans navigateur** : http://echo.kubequest.local:30080

## 🎉 Félicitations !

Votre infrastructure Kubernetes avec Ingress est opérationnelle !

## 🧹 Nettoyage (quand vous avez fini)

### Éteindre les instances (sans détruire)

Via la console AWS :
- Sélectionnez les 4 instances
- Actions → Instance State → Stop

### Détruire toute l'infrastructure

```bash
cd terraform
terraform destroy
```

⚠️ **ATTENTION** : Cela supprime tout !

## 📚 Ressources

- [README Terraform complet](terraform/README.md)
- [Documentation Terraform](https://terraform.io)
- [Documentation kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Documentation nginx-ingress](https://kubernetes.github.io/ingress-nginx/)

## 💡 Tips

- **Temps de provisionnement** : 5-10 minutes
- **Temps d'initialisation Kubernetes** : 3-5 minutes
- **User_data s'exécute au boot** : Attendez 2-3 min avant SSH
- **Si SSH échoue** : L'instance est encore en train de s'initialiser
- **Coûts** : Éteignez les instances quand vous ne les utilisez pas !

---

**Bonne chance pour votre projet ! 🚀**
