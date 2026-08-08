# Guide de Déploiement Ingress - Kubernetes AWS

## Vue d'ensemble du projet

Votre ticket demande de configurer un contrôleur Ingress pour exposer vos applications Kubernetes sur AWS. Bonne nouvelle : **la configuration est déjà prête !** Vous avez juste à la déployer.

### Ce qui est déjà configuré dans votre projet :

1. **nginx-ingress controller** - Dans `kubequest-cluster/gitops/infrastructure/base/nginx-ingress/`
   - Utilise un AWS Network Load Balancer (NLB)
   - Configuration avec auto-scaling (2-5 replicas)
   - Monitoring avec Prometheus intégré

2. **Application Laravel** - Dans `kubequest-cluster/laravel-app/`
   - Ingress configuré pour `larapp.kubequest.local`
   - Support HTTPS avec cert-manager
   - Configuration de sécurité avancée

3. **cert-manager** - Pour la gestion automatique des certificats SSL/TLS

## Architecture réseau

```
Internet → AWS NLB (LoadBalancer) → nginx-ingress-controller → Laravel App (ClusterIP)
```

## Étape 1 : Se connecter au cluster Kubernetes

### 1.1 Accéder à la console AWS

```
URL: https://649966626926.signin.aws.amazon.com/console
Account ID: 649966626926
Username: student-frankfurt-group-50
Password: JioPoulet98/
```

### 1.2 Installer et configurer kubectl

Sur votre machine locale :

```bash
# Installer kubectl si ce n'est pas déjà fait
brew install kubectl  # Sur macOS
# ou
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Vérifier l'installation
kubectl version --client
```

### 1.3 Connecter kubectl à votre cluster EKS

Depuis la console AWS :
1. Allez dans EKS → Clusters
2. Sélectionnez votre cluster (probablement nommé avec "group-50")
3. Cliquez sur "Connect" → "Create EKS access role" si nécessaire
4. Copiez la commande `aws eks update-kubeconfig`

Sur votre machine locale :

```bash
# Installer AWS CLI si nécessaire
brew install awscli

# Configurer les credentials AWS
aws configure

# Entrer vos informations :
# AWS Access Key ID: [à récupérer depuis la console AWS IAM]
# AWS Secret Access Key: [à récupérer depuis la console AWS IAM]
# Default region: eu-central-1
# Default output format: json

# Connecter kubectl au cluster
aws eks update-kubeconfig --name <nom-du-cluster> --region eu-central-1

# Vérifier la connexion
kubectl get nodes
kubectl get svc
```

## Étape 2 : Déployer nginx-ingress controller

### 2.1 Créer l'espace de nommage

```bash
kubectl create namespace ingress-nginx
```

### 2.2 Déployer nginx-ingress avec Kustomize

```bash
# Aller dans le répertoire de configuration
cd kubequest-cluster/gitops/infrastructure/base/nginx-ingress

# Installer Kustomize si nécessaire
brew install kustomize

# Appliquer la configuration
kubectl apply -k .

# Vérifier le déploiement
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 2.3 Vérifier le LoadBalancer AWS

```bash
# Récupérer l'adresse du LoadBalancer
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Vous devriez voir une EXTERNAL-IP ou un hostname AWS
# L'output devrait ressembler à :
# ingress-nginx-controller   LoadBalancer   10.100.200.50   xxxxx.elb.eu-central-1.amazonaws.com
```

## Étape 3 : Déployer cert-manager (pour HTTPS)

```bash
# Installer cert-manager (nécessaire pour les certificats SSL)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Attendre que cert-manager soit ready
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s

# Vérifier
kubectl get pods -n cert-manager
```

## Étape 4 : Déployer l'application Laravel avec Ingress

### 4.1 Créer l'espace de nommage

```bash
kubectl create namespace laravel-app
```

### 4.2 Déployer l'application

```bash
# Depuis la racine du projet
cd kubequest-cluster/laravel-app

# Installer Helm si nécessaire
brew install helm

# Déployer l'application
helm install laravel-app . -n laravel-app -f values.yaml

# Vérifier le déploiement
kubectl get pods -n laravel-app
kubectl get svc -n laravel-app
kubectl get ingress -n laravel-app
```

## Étape 5 : Configurer les DNS et tester

### 5.1 Récupérer l'adresse du LoadBalancer

```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Notez l'EXTERNAL-IP ou le hostname AWS (ex: abc123.elb.eu-central-1.amazonaws.com)
```

### 5.2 Configurer le DNS local pour tester

Ajoutez cette ligne à votre fichier `/etc/hosts` :

```bash
# Éditer le fichier hosts
sudo nano /etc/hosts

# Ajouter la ligne (remplacez avec l'IP ou hostname réel)
<IP-OU-HOSTNAME-AWS>  larapp.kubequest.local
```

### 5.3 Tester l'accès HTTP

```bash
# Test HTTP
curl http://larapp.kubequest.local

# Test avec réponse détaillée
curl -v http://larapp.kubequest.local
```

### 5.4 Tester l'accès HTTPS

Pour le test HTTPS, vous pouvez :

**Option A : Sans DNS configuré (curl avec skip-verify)**

```bash
# Récupérer l'URL AWS
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Test HTTPS (en contournant la vérification SSL pour le test)
curl -k https://larapp.kubequest.local
```

**Option B : Avec certificat Let's Encrypt (production)**

```bash
# Vérifier le statut du certificat
kubectl get certificate -n laravel-app
kubectl describe certificate laravel-app-tls -n laravel-app

# Attendre quelques minutes que cert-manager obtienne le certificat
# Puis testez
curl https://larapp.kubequest.local
```

### 5.5 Tests supplémentaires

```bash
# Test avec navigateur
open http://larapp.kubequest.local
open https://larapp.kubequest.local

# Vérifier les logs nginx-ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Vérifier les logs de l'application
kubectl logs -n laravel-app -l app.kubernetes.io/name=laravel-app --tail=50
```

## Étape 6 : Documenter la configuration

### 6.1 Créer un document avec vos informations

Créez un fichier `CONFIGURATION_RESEAU.md` avec les informations suivantes :

```markdown
# Configuration Réseau - Ingress Kubernetes

## Informations Cluster

- **Nom du cluster EKS** : [à compléter]
- **Région AWS** : eu-central-1 (Francfurt)
- **VPC ID** : [à récupérer depuis la console AWS]
- **Subnets** : [à récupérer depuis la console AWS]

## Configuration Ingress

### nginx-ingress Controller

- **Namespace** : ingress-nginx
- **Type de service** : LoadBalancer (AWS NLB)
- **Replicas** : 2 (auto-scaling 2-5)
- **LoadBalancer AWS** : [adresse externe à récupérer avec `kubectl get svc`]
- **Internal/External** : Internal (selon values.yaml)

### Application Laravel

- **Namespace** : laravel-app
- **Ingress Host** : larapp.kubequest.local
- **Port interne** : 9000
- **Type de service** : ClusterIP

### Certificats SSL/TLS

- **Géré par** : cert-manager
- **Cluster Issuer** : letsencrypt-prod
- **Secret** : laravel-app-tls

## Tests Réalisés

### Test HTTP
[Date] : [Résultat du test curl http://larapp.kubequest.local]

### Test HTTPS
[Date] : [Résultat du test curl https://larapp.kubequest.local]

### Accès depuis navigateur
[Date] : [Résultat]

## Architecture

```
Internet
    ↓
AWS Network Load Balancer (NLB)
    ↓
nginx-ingress-controller (ingress-nginx namespace)
    ↓
Laravel App Service (laravel-app namespace)
    ↓
Laravel Pods (3 replicas)
```

## Commandes utiles

```bash
# Vérifier l'état de l'Ingress
kubectl get ingress -n laravel-app
kubectl describe ingress laravel-app -n laravel-app

# Vérifier les services
kubectl get svc -n ingress-nginx
kubectl get svc -n laravel-app

# Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 -f
```
```

### 6.2 Récupérer les informations pour la documentation

```bash
# Informations cluster
kubectl cluster-info
kubectl get nodes

# Information Ingress
kubectl get ingress -A
kubectl describe ingress laravel-app -n laravel-app

# Information LoadBalancer
kubectl get svc -n ingress-nginx ingress-nginx-controller -o yaml

# Sauvegarder la configuration
kubectl get ingress laravel-app -n laravel-app -o yaml > ingress-config.yaml
```

## Dépannage

### Problème : L'Ingress retourne 502/503

```bash
# Vérifier que les pods sont ready
kubectl get pods -n laravel-app

# Vérifier que le service existe
kubectl get svc -n laravel-app

# Vérifier les logs nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
```

### Problème : Le LoadBalancer n'a pas d'EXTERNAL-IP

```bash
# Attendre quelques minutes (AWS prend du temps pour créer le LB)
kubectl get svc -n ingress-nginx -w

# Vérifier les tags et security groups AWS dans la console
```

### Problème : Certificat SSL non prêt

```bash
# Vérifier cert-manager
kubectl get pods -n cert-manager

# Vérifier les certificats
kubectl get certificate -A
kubectl describe certificate laravel-app-tls -n laravel-app

# Vérifier les challenges Let's Encrypt
kubectl get challenge -A
kubectl describe challenge <name> -n laravel-app
```

## Checklist de validation

- [ ] kubectl connecté au cluster EKS
- [ ] nginx-ingress déployé et ready
- [ ] LoadBalancer AWS créé avec EXTERNAL-IP
- [ ] cert-manager déployé
- [ ] Application Laravel déployée
- [ ] Ingress créé et configuré
- [ ] Test HTTP fonctionnel
- [ ] Test HTTPS fonctionnel
- [ ] Documentation rédigée
- [ ] Capture d'écran des tests

## Notes importantes

1. **Temps de déploiement** : Le LoadBalancer AWS peut prendre 2-5 minutes pour être prêt
2. **DNS** : Pour les tests en production, configurez un vrai domaine DNS pointant vers le LoadBalancer
3. **Sécurité** : Le LoadBalancer est configuré en mode "internal" - assurez-vous que c'est ce que vous voulez
4. **Coûts AWS** : Un LoadBalancer AWS engendre des coûts (~$0.022/heure + transfert de données)

## Ressources

- [Documentation nginx-ingress](https://kubernetes.github.io/ingress-nginx/)
- [Documentation cert-manager](https://cert-manager.io/docs/)
- [Documentation AWS EKS](https://docs.aws.amazon.com/eks/)
- [Votre projet](https://github.com/EpitechMscProPromo2026/T-CLO-902-PAR_5)
