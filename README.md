# KubeQuest - Groupe 50

## 🎯 Projet

Déploiement d'un cluster Kubernetes complet avec infrastructure de monitoring, logging, et GitOps pour une application Laravel.

### Objectifs atteints

- ✅ Cluster Kubernetes multi-nœuds (4 VMs AWS)
- ✅ **Load balancer** interne avec nginx-ingress
- ✅ **Dashboard** Kubernetes pour la gestion
- ✅ **Monitoring** avec Prometheus + Grafana (kube-prometheus)
- ✅ **Logging** avec Loki + Promtail
- ✅ **GitOps** avec Kustomize
- ✅ Application Laravel convertie de docker-compose vers Helm
- ✅ **Best practices** Kubernetes (limits, affinity, probes)
- ✅ **Auto-scaling** avec Horizontal Pod Autoscaler
- ✅ **Backup** automatisé de la base de données

---

## 📊 Architecture

### Infrastructure AWS

4 VMs EC2 sur Amazon Linux 2023 (aarch64) :

| Nom | Rôle | IP Privée | IP Publique |
|-----|------|-----------|-------------|
| **node-1** | Control Plane + Worker | 10.2.50.23 | 35.156.165.130 |
| **node-2** | Worker | 10.2.50.190 | 3.79.247.101 |
| **node-3** | Ingress | 10.2.50.90 | 3.77.235.74 |
| **node-4** | Monitoring | 10.2.50.113 | 3.120.183.206 |

### Stack Kubernetes

- **Version** : v1.31.14
- **Runtime** : containerd 2.2.1
- **Network** : Calico (CNI)
- **Ingress** : nginx-ingress controller

### Composants déployés

| Composant | Namespace | Nœud | Rôle |
|-----------|-----------|------|------|
| nginx-ingress | ingress-nginx | node-3 | Load balancer / Reverse proxy |
| Laravel app | laravel | node-2 | Application principale |
| MySQL | laravel | node-2 | Base de données |
| Prometheus | monitoring | node-4 | Métriques |
| Grafana | monitoring | node-4 | Visualisation |
| Loki | monitoring | node-4 | Centralisation des logs |
| Kubernetes Dashboard | kubernetes-dashboard | node-2/3 | Interface web K8s |

---

## 🚀 Déploiement Rapide

### Option 1 : Déploiement automatisé avec Helm

```bash
# Tout déployer en une commande
./deploy-all.sh
```

Ce script :
1. Vérifie les prérequis (kubectl, helm)
2. Déploie nginx-ingress controller
3. Déploie kube-prometheus stack
4. Déploie Loki pour les logs
5. Déploie l'application Laravel
6. Déploie Kubernetes Dashboard
7. Vérifie que tout est fonctionnel

### Option 2 : Déploiement GitOps avec Kustomize

```bash
# Tout déployer avec Kustomize
./apply-gitops.sh
```

Cette méthode utilise les manifests Kubernetes et Kustomize (GitOps).

---

## 🧪 Tests et Démos

### Test 1 : Vérifier que l'application fonctionne

```bash
curl http://app.kubequest.local:32222
```

**Résultat attendu** : Page HTML "Hello world sample app" avec un compteur.

### Test 2 : Test de charge (Auto-scaling)

```bash
./load-test.sh
```

Ce script :
- Envoie 400 requêtes/seconde sur l'application
- Surveille l'auto-scaling en temps réel
- Montre les replicas augmenter automatiquement

**Résultat attendu** : Le nombre de pods Laravel augmente (3 → 5 → 7 → 10).

### Test 3 : Démo Rollback (Zero-downtime)

```bash
./rollback-demo.sh
```

Ce script :
1. Déploie une version "cassée" (nginx au lieu de Laravel)
2. Montre que l'application ne fonctionne plus
3. Fait un **rollback** vers la version stable
4. Montre que l'application fonctionne à nouveau

**Résultat attendu** : Le rollback est instantané, zéro-downtime.

---

## 🌐 Accès aux Applications

### Laravel Application

**URL** : http://app.kubequest.local:32222

**Configuration hosts** :
```bash
# Ajouter à /etc/hosts
3.77.235.74  app.kubequest.local
```

### Kubernetes Dashboard

**URL** : http://dashboard.kubequest.local:32222

**Token** :
```bash
kubectl -n kubernetes-dashboard get secret admin-user-token \
  -o jsonpath='{.data.token}' | base64 -d
```

### Grafana

**URL** : http://3.120.183.206:3000

**Mot de passe** :
```bash
kubectl -n monitoring get secret kube-prometheus-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

**Dashboard** à importer : Kubernetes / Compute Resources / Pod

---

## 📁 Structure du Projet

```
.
├── deploy-all.sh              # Script de déploiement principal (Helm)
├── apply-gitops.sh            # Script de déploiement GitOps (Kustomize)
├── load-test.sh               # Script de test de charge
├── rollback-demo.sh            # Script de démo rollback
├── kubequest-cluster/
│   ├── laravel-app/           # Helm Chart Laravel
│   │   ├── Chart.yaml
│   │   ├── values.yaml        # Configuration complète
│   │   └── templates/          # Manifests Kubernetes
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       ├── pvc.yaml        # Persistent Volume pour storage
│   │       ├── configmap.yaml
│   │       ├── secret.yaml
│   │       └── hpa.yaml        # Horizontal Pod Autoscaler
│   └── gitops/                # GitOps avec Kustomize
│       ├── infrastructure/
│       │   └── base/
│       │       ├── nginx-ingress/
│       │       ├── monitoring/
│       │       ├── logging/
│       │       └── kustomization.yaml
│       └── apps/
│           └── laravel-app/
│               ├── base/
│               │   ├── kustomization.yaml
│               │   ├── namespace.yaml
│               │   └── values.yaml
│               └── overlays/
│                   └── production/
│                       └── kustomization.yaml
├── terraform/                 # Infrastructure AWS (Terraform)
├── scripts/                   # Scripts d'installation K8s
└── docs/                      # Documentation
    ├── journal-technique.md   # Journal détaillé
    └── infrastructure.md     # Info nœuds AWS
```

---

## 🔧 Best Practices Kubernetes

### 1. Resources Limits et Requests

Chaque container a des limits/requests configurés :

```yaml
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "250m"
    memory: "256Mi"
```

### 2. Redondance avec Replicas

```yaml
replicaCount: 3
```

### 3. Pod Anti-Affinity

Les pods sont répartis sur différents nœuds pour la haute disponibilité :

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - laravel-app
        topologyKey: kubernetes.io/hostname
```

### 4. Auto-scaling (HPA)

```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### 5. Health Checks (Probes)

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

### 6. Persistent Storage

```yaml
persistence:
  enabled: true
  size: 10Gi
```

### 7. Backup Automatisé

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # Tous les jours à 2h du matin
  retention: "30d"
```

### 8. Secrets Kubernetes

Les données sensibles sont stockées dans des Secrets, pas en clair :

```yaml
secrets:
  appKey: "base64:your-app-key-here"
  dbPassword: "changeme"
```

### 9. Labels Kubernetes Standards

Toutes les resources sont labelisées selon les conventions Kubernetes :

```yaml
labels:
  app.kubernetes.io/name: laravel-app
  app.kubernetes.io/managed-by: helm
  app.kubernetes.io/part-of: kubequest
  app.kubernetes.io/component: application
```

### 10. Security Context

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

---

## 📈 Monitoring et Logging

### Prometheus

Collecte les métriques de tous les pods et nœuds.

**Accès** : Via Grafana

### Grafana

Visualisation des métriques avec dashboards pré-configurés.

**Dashboards importés** :
- Kubernetes Cluster
- Kubernetes Compute Resources / Pod
- NGINX Ingress Dashboard

### Loki

Centralise les logs de tous les pods.

**Requête Loki dans Grafana** :
```
{namespace="laravel",app="laravel-app"}
```

---

## 🔄 Déploiement Continu (GitOps)

### Principe

Toute la configuration est stockée dans Git. Pour déployer une modification :

1. Modifier les fichiers dans `kubequest-cluster/gitops/`
2. Commit et push
3. Exécuter `./apply-gitops.sh` sur le cluster

### Structure GitOps

```
gitops/
├── infrastructure/base/    # Infrastructure commune
│   ├── nginx-ingress/
│   ├── monitoring/
│   └── logging/
└── apps/                   # Applications
    └── laravel-app/
        ├── base/           # Configuration de base
        └── overlays/
            └── production/ # Spécifique production
```

---

## 🛡️ Sécurité

### Security Groups AWS

Règles configurées :
- Port 22 (SSH) depuis IP autorisées
- Port 6443 (Kubernetes API) entre nœuds
- Port 10250 (Kubelet) entre nœuds
- Ports 32222 (HTTP NodePort) et 32214 (HTTPS NodePort)

### RBAC Kubernetes

- ServiceAccount dédié pour l'application Laravel
- ClusterRoleBinding pour le Dashboard
- Roles limités pour chaque composant

### Secrets Management

Les secrets sont stockés comme Kubernetes Secrets et **non commités** dans Git.

---

## 🐛 Troubleshooting

### L'application ne répond pas

```bash
# Vérifier les pods
kubectl get pods -n laravel

# Logs des pods
kubectl logs -n laravel -l app.kubernetes.io/name=laravel-app -f

# Entrer dans un pod
kubectl exec -it -n laravel <pod-name> -- sh
```

### L'auto-scaling ne fonctionne pas

```bash
# Vérifier l'HPA
kubectl get hpa -n laravel
kubectl describe hpa -n laravel

# Vérifier les metrics server
kubectl get pods -n kube-system | grep metrics-server
```

### L'Ingress ne route pas correctement

```bash
# Vérifier l'ingress
kubectl get ingress -n laravel
kubectl describe ingress laravel-app -n laravel

# Logs nginx-ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f
```

### Le LoadBalancer est pending

Normal sur des VMs EC2 auto-gérées. Utiliser le **NodePort** à la place :

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Regarder le port dans la colonne PORT(S) (ex: 32222)
```

---

## 📚 Documentation Supplémentaire

- **Journal Technique** : `docs/journal-technique.md`
- **Infrastructure** : `docs/infrastructure.md`
- **Guide Ingress** : `GUIDE_INGRESS_DEPLOYMENT.md`

---

## 👥 Équipe

**Groupe 50** - Epitech MSc Pro Promo 2026

---

## 📝 License

Projet académique - Epitech

---

**Date de création** : 2024
**Dernière mise à jour** : 2025-06-18
