# KubeQuest - Projet Kubernetes Complet

Projet complet de mise en place d'une infrastructure Kubernetes moderne avec monitoring, logging, sécurité et GitOps.

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Structure du projet](#structure-du-projet)
- [Composants déployés](#composants-déployés)
- [Bonnes pratiques implémentées](#bonnes-pratiques-implémentées)
- [Utilisation](#utilisation)
- [Tests et démonstrations](#tests-et-démonstrations)
- [Sécurité](#sécurité)
- [Dépannage](#dépannage)

## 🎯 Vue d'ensemble

Ce projet démontre la mise en place d'une infrastructure Kubernetes complète pour une application Laravel, incluant :

- **Load balancer interne** (nginx-ingress)
- **Dashboard de gestion** (kubernetes-dashboard)
- **Stack de monitoring** (kube-prometheus, Grafana)
- **Stack de logging** (Loki, Promtail, Grafana)
- **GitOps** (Kustomize)
- **Sécurité** (OPA Validating Webhook)
- **Chiffrement** (cert-manager, Let's Encrypt)

## 🏗️ Architecture

```
kubequest-cluster/
├── laravel-app/              # Chart Helm de l'application Laravel
├── gitops/                   # Répertoire GitOps
│   ├── infrastructure/       # Manifests Kustomize pour l'infrastructure
│   └── apps/                 # Manifests Kustomize pour les applications
└── scripts/                  # Scripts de déploiement et de tests
```

## 📦 Prérequis

- Kubernetes 1.25+ (cluster sur AWS avec 2 nodes)
- kubectl 1.25+
- Helm 3.x
- kustomize 5.x
- Apache Bench (pour les tests de charge)

### Installation des outils

```bash
# Sur macOS
brew install kubectl helm kustomize apr-util

# Sur Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Kustomize
go install sigs.k8s.io/kustomize/kustomize/v5@latest

# Apache Bench (Ubuntu)
sudo apt-get install -y apache2-utils
```

## 🚀 Installation

### 1. Cloner le dépôt

```bash
git clone <repository-url>
cd kubequest-cluster
```

### 2. Déployer l'infrastructure

```bash
chmod +x scripts/*.sh
./scripts/deploy-infrastructure.sh
```

Ce script déploie :
- nginx-ingress (Load Balancer)
- cert-manager (Certificats SSL)
- kubernetes-dashboard
- kube-prometheus (Monitoring)
- Loki (Logging)
- OPA (Sécurité)

### 3. Déployer l'application Laravel

```bash
./scripts/deploy-app.sh
```

### 4. Vérifier l'état de santé

```bash
./scripts/health-check.sh
```

## 📁 Structure du projet

### Chart Helm Laravel

```
laravel-app/
├── Chart.yaml                    # Définition du chart avec dépendances
├── values.yaml                   # Configuration complète
└── templates/
    ├── configmap.yaml           # Configuration Laravel (.env)
    ├── secret.yaml              # Secrets sensibles
    ├── pvc.yaml                 # Stockage persistant
    ├── backup-cronjob.yaml      # Backups automatiques
    ├── servicemonitor.yaml      # Intégration Prometheus
    ├── pdb.yaml                 # PodDisruptionBudget
    ├── deployment.yaml          # Déploiement de l'application
    ├── service.yaml             # Service de l'application
    ├── ingress.yaml             # Ingress nginx
    └── hpa.yaml                 # Auto-scaling
```

### GitOps Infrastructure

```
gitops/infrastructure/base/
├── kustomization.yaml           # Manifest racine
├── nginx-ingress/               # Load Balancer
├── cert-manager/                # Gestion des certificats
├── kubernetes-dashboard/        # Dashboard
├── monitoring/                  # Prometheus + Grafana
├── logging/                     # Loki + Grafana
└── security/                    # OPA Webhook
```

### GitOps Applications

```
gitops/apps/laravel-app/
├── base/                        # Configuration de base
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   └── values.yaml
└── overlays/
    └── production/              # Overrides production
        ├── kustomization.yaml
        └── production-patch.yaml
```

## 🎛️ Composants déployés

### 1. nginx-ingress
- **Rôle** : Load Balancer interne
- **Replicas** : 2 (avec pod anti-affinity)
- **Fonctionnalités** :
  - Load Balancer AWS Network Load Balancer
  - SSL/TLS termination
  - Rate limiting
  - Metrics avec ServiceMonitor

### 2. cert-manager
- **Rôle** : Gestion automatique des certificats SSL
- **Fonctionnalités** :
  - Certificats Let's Encrypt automatiques
  - Renouvellement automatique
  - ClusterIssuers pour production et staging

### 3. kubernetes-dashboard
- **Rôle** : Interface web de gestion
- **Replicas** : 2
- **Authentification** : ServiceAccount avec token
- **URL** : https://dashboard.kubequest.local

### 4. kube-prometheus
- **Rôle** : Monitoring et alerting
- **Composants** :
  - Prometheus (2 replicas, 20GB de stockage)
  - Grafana (2 replicas, 5GB de stockage)
  - Alertmanager (3 replicas)
  - Node Exporter
  - kube-state-metrics
- **URLs** :
  - Grafana : https://grafana.kubequest.local
  - Prometheus : https://prometheus.kubequest.local

### 5. Loki
- **Rôle** : Collecte et visualisation des logs
- **Composants** :
  - Loki (2 replicas, 20GB de stockage)
  - Promtail (sur tous les nodes)
  - Grafana dédié
- **URLs** :
  - Loki : https://loki.kubequest.local
  - Logs : https://logs.kubequest.local

### 6. OPA (Open Policy Agent)
- **Rôle** : Validating Webhook pour la sécurité
- **Politiques implémentées** :
  - Vérification des ressources (limits/requests)
  - Validation des labels
  - Interdiction de l'exécution en root
  - Minimum 2 replicas pour les Deployments
  - Sélecteurs obligatoires pour les Services

### 7. Application Laravel
- **Image** : Docker containerisé
- **Base de données** : PostgreSQL avec Bitnami Helm
- **Replicas** : 3 minimum (auto-scaling jusqu'à 15)
- **Fonctionnalités** :
  - Stockage persistant pour Laravel
  - Backups automatiques quotidiens
  - Monitoring avec Prometheus
  - Logging avec Loki
  - SSL/TLS avec cert-manager
  - HPA pour auto-scaling
- **URL** : https://larapp.kubequest.local

## ✅ Bonnes pratiques implémentées

### 1. Resources Limits et Requests
```yaml
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "250m"
    memory: "256Mi"
```

### 2. Secrets pour données sensibles
```yaml
apiVersion: v1
kind: Secret
type: Opaque
stringData:
  app-key: "base64:..."
  db-password: "..."
```

### 3. Labels Kubernetes
Toutes les ressources sont labellisées selon les recommandations :
- `app.kubernetes.io/name`
- `app.kubernetes.io/instance`
- `app.kubernetes.io/version`
- `app.kubernetes.io/component`
- `app.kubernetes.io/part-of`
- `app.kubernetes.io/managed-by`

### 4. Redondance
- **Replicas** : Minimum 3 pour tous les composants critiques
- **Pod Anti-Affinity** : Distribution sur les nodes
- **Node Affinity** : Placement sur nodes workers
- **PodDisruptionBudget** : Protection contre les disruptions

### 5. Stockage persistant
- **PostgreSQL** : 50Gi avec gp3
- **Laravel Storage** : 5Gi
- **Prometheus** : 20Gi
- **Loki** : 20Gi
- **Backups** : 20Gi avec rétention 30 jours

### 6. Probes de santé
```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: http
readinessProbe:
  httpGet:
    path: /api/ready
    port: http
```

### 7. Auto-scaling (HPA)
```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 15
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### 8. Sécurité
- **OPA Webhook** : Validation des ressources
- **Security Contexts** : Non-root, read-only filesystem
- **RBAC** : Principe du moindre privilège
- **Network Policies** : (à implémenter)

### 9. Backups
```yaml
backup:
  enabled: true
  schedule: "0 1 * * *"  # Quotidien à 1h
  retention: "30d"
```

## 🎮 Utilisation

### Accéder au Kubernetes Dashboard

```bash
# Obtenir le token
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')

# Ouvrir le navigateur
open https://dashboard.kubequest.local
```

### Accéder à Grafana

```bash
# URL
open https://grafana.kubequest.local

# Par défaut, créer un compte admin
```

### Voir les logs avec Loki

```bash
# URL
open https://logs.kubequest.local
```

### Vérifier l'état des pods

```bash
# Tous les pods
kubectl get pods --all-namespaces

# Pods d'un namespace spécifique
kubectl -n laravel-app get pods
```

### Consulter les logs

```bash
# Logs d'un pod
kubectl -n laravel-app logs -f deployment/laravel-app

# Logs de tous les pods
kubectl -n laravel-app logs -f -l app.kubernetes.io/name=laravel-app
```

### Exécuter une commande dans un pod

```bash
kubectl -n laravel-app exec -it deployment/laravel-app -- /bin/bash
```

## 🧪 Tests et démonstrations

### 1. Test de charge (Auto-scaling)

```bash
./scripts/load-test.sh
```

Ce script :
- Envoie 10000 requêtes avec 100 connexions simultanées
- Surveille le scaling en temps réel
- Affiche les résultats du test

### 2. Démonstration de Rollback

```bash
./scripts/rollback-demo.sh
```

Ce script :
- Déploie une nouvelle version
- Simule un problème (image inexistante)
- Effectue un rollback automatique
- Affiche l'historique des déploiements

### 3. Vérification de santé

```bash
./scripts/health-check.sh
```

Affiche l'état de tous les composants.

### 4. Nettoyage

```bash
./scripts/cleanup.sh
```

Supprime toute l'infrastructure (demande confirmation).

## 🔒 Sécurité

### OPA Policies

Les politiques OPA sont définies dans `gitops/infrastructure/base/security/configmap.yaml` :

1. **Validation des ressources** : Toutes les ressources doivent avoir des limits/requests
2. **Labels obligatoires** : `app.kubernetes.io/name` est requis
3. **Non-root** : Les conteneurs ne doivent pas s'exécuter en root
4. **Haute disponibilité** : Les Deployments doivent avoir au moins 2 replicas
5. **Sélecteurs Services** : Les Services doivent avoir des sélecteurs

### Certificats SSL

Cert-manager gère automatiquement les certificats Let's Encrypt :
- `letsencrypt-prod` : Pour la production
- `letsencrypt-staging` : Pour les tests

### Secrets

Les secrets sont créés avec `kubectl create secret` et stockés en base64.

## 🐛 Dépannage

### Pods en CrashLoopBackOff

```bash
# Voir les logs
kubectl logs -n <namespace> <pod-name>

# Décrire le pod
kubectl describe pod -n <namespace> <pod-name>
```

### HPA ne scale pas

```bash
# Vérifier les métriques
kubectl get hpa -n <namespace> -w

# Vérifier que les métriques-server sont installés
kubectl get deployment -n kube-system metrics-server
```

### Certificats non générés

```bash
# Vérifier les ClusterIssuers
kubectl get clusterissuers

# Vérifier les Certificates
kubectl get certificates --all-namespaces

# Logs de cert-manager
kubectl logs -n cert-manager deployment/cert-manager
```

### Ingress ne fonctionne pas

```bash
# Vérifier nginx-ingress
kubectl -n ingress-nginx get pods

# Vérifier l'ingress
kubectl get ingress -n <namespace>

# Logs de nginx-ingress
kubectl -n ingress-nginx logs deployment/ingress-nginx-controller
```

### Problèmes OPA

```bash
# Vérifier les pods OPA
kubectl -n opa get pods

# Voir les politiques
kubectl get configmap -n opa opa-policy -o yaml

# Logs OPA
kubectl -n opa logs deployment/opa

# Désactiver temporairement (si nécessaire)
kubectl delete validatingwebhookconfiguration opa-validating-webhook
```

## 📊 Monitoring et Alerting

### Grafana Dashboards

Les dashboards suivants sont pré-configurés :
- **Kubernetes / Compute Resources / Pod** : Utilisation des ressources
- **Kubernetes / Networking / Cluster** : Réseau
- **Kubernetes / Storage / Cluster** : Stockage
- **PostgreSQL** : Métriques de base de données

### Alerts

Les alertes par défaut sont activées pour :
- Pods en CrashLoopBackOff
- Pods non prêts
- Utilisation CPU/Memory élevée
- Espace disque insuffisant

## 📝 Développement

### Ajouter un nouveau composant

1. Créer le manifest dans `gitops/infrastructure/base/`
2. Ajouter une référence dans `gitops/infrastructure/base/kustomization.yaml`
3. Créer les scripts de déploiement si nécessaire
4. Documenter dans ce README

### Modifier l'application Laravel

1. Modifier `laravel-app/`
2. Mettre à jour le chart version dans `Chart.yaml`
3. Déployer avec :
   ```bash
   helm upgrade --install laravel-app ./laravel-app --namespace laravel-app --values gitops/apps/laravel-app/base/values.yaml
   ```

## 🤝 Contribution

Ce projet est destiné à des fins éducatives et de démonstration.

## 📄 Licence

MIT License

---

**Auteur** : Équipe KubeQuest
**Date** : 2026
**Version** : 1.0.0
