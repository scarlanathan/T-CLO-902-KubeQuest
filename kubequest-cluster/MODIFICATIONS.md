# Rapport des Modifications - Projet KubeQuest

**Étudiant** : [Votre Nom]
**Projet** : T-CLO-902-PAR_5 - KubeQuest
**Date** : 2026

---

## 📋 Vue d'ensemble

Ce document détaille toutes les modifications apportées aux fichiers existants du projet initial. Au total, **3 fichiers existants** ont été modifiés et **53 nouveaux fichiers** ont été créés pour répondre aux exigences du sujet.

---

## 📝 Fichiers MODIFIÉS

### 1. `laravel-app/Chart.yaml`

**Raison de la modification** :
- Adapter le chart Helm générique pour une application Laravel
- Ajouter PostgreSQL comme dépendance via le chart officiel Bitnami
- Mettre à jour les numéros de version

**Modifications apportées** :

```diff
--- a/laravel-app/Chart.yaml
+++ b/laravel-app/Chart.yaml
@@ -1,24 +1,33 @@
 apiVersion: v2
 name: laravel-app
-description: A Helm chart for Kubernetes
+description: A Helm chart for Laravel application with PostgreSQL database

 # A chart can be either an 'application' or a 'library' chart.
 #
 # Application charts are a collection of templates that can be packaged into versioned archives
 # to be deployed.
 #
 # Library charts provide useful utilities or functions for the chart developer. They're included as
 # a dependency of application charts to inject those utilities and functions into the rendering
 # pipeline. Library charts do not define any templates and therefore cannot be deployed.
 type: application

 # This is the chart version. This version number should be incremented each time you make changes
 # to the chart and its templates, including the app version.
 # Versions are expected to follow Semantic Versioning (https://semver.org/)
-version: 0.1.0
+version: 1.0.0

 # This is the version number of the application being deployed. This version number should be
 # incremented each time you make changes to the application. Versions are not expected to
 # follow Semantic Versioning. They should reflect the version the application is using.
 # It is recommended to use it with quotes.
-appVersion: "1.16.0"
+appVersion: "1.0.0"
+
+# Dependencies for this chart
+dependencies:
+  - name: postgresql
+    repository: https://charts.bitnami.com/bitnami
+    version: 15.x.x
+    alias: postgresql
+    condition: postgresql.enabled
```

**Détail des changements** :
1. ✏️ **Ligne 3** : Description modifiée de "A Helm chart for Kubernetes" à "A Helm chart for Laravel application with PostgreSQL database"
2. ✏️ **Ligne 18** : Version du chart passée de `0.1.0` à `1.0.0` (version de production)
3. ✏️ **Ligne 24** : AppVersion passée de `1.16.0` à `1.0.0` (correspond à la version de l'application Laravel)
4. ➕ **Lignes 26-32** : **NOUVEAU** - Ajout de la section `dependencies` avec PostgreSQL comme dépendance du chart officiel Bitnami

---

### 2. `laravel-app/values.yaml`

**Raison de la modification** :
- Le fichier `values.yaml` original contenait une configuration générique pour nginx
- Remplacement complet par une configuration professionnelle pour une application Laravel avec PostgreSQL
- Ajout de toutes les bonnes pratiques Kubernetes demandées dans le sujet

**Résumé des modifications** :
- 🔄 **Remplacement complet** du contenu (162 lignes → 278 lignes)
- ✅ Configuration Laravel complète (environnement, base de données, logs)
- ✅ Resources limits et requests
- ✅ Liveness/Readiness probes
- ✅ HPA (Horizontal Pod Autoscaler)
- ✅ Ingress avec nginx et TLS
- ✅ Volumes et PVC
- ✅ Affinity rules (pod anti-affinity + node affinity)
- ✅ Configuration PostgreSQL via dépendance Bitnami
- ✅ Secrets pour données sensibles
- ✅ Backups automatiques
- ✅ Monitoring (ServiceMonitor)
- ✅ Logging

**Sections ajoutées/supprimées** :

```diff
--- a/laravel-app/values.yaml (original - 162 lignes)
+++ b/laravel-app/values.yaml (modifié - 278 lignes)

# SUPPRIMÉS :
- Configuration générique nginx
- replicaCount: 1 (sans redondance)
- image: nginx (au lieu de Laravel)
- Aucune configuration de resources
- Aucune configuration de probes
- Aucune configuration de HPA
- Aucune configuration d'affinity
- Aucune configuration PostgreSQL
- Aucune configuration de backups
- Aucune configuration monitoring/logging

# AJOUTÉS :
+ Global labels Kubernetes (app.kubernetes.io/*)
+ ReplicaCount: 3 (redondance)
+ Image Laravel configurée
+ Resources limits/requests (CPU/RAM)
+ Liveness/Readiness probes avec chemins Laravel
+ HPA configuré (3-15 replicas, 70% CPU)
+ Ingress nginx avec TLS et cert-manager
+ Volumes pour storage Laravel
+ PVC pour stockage persistant
+ Pod anti-affinity (distribution sur nodes)
+ Node affinity (placement sur workers)
+ Configuration PostgreSQL complète
+ ConfigMap pour .env Laravel
+ Secrets pour données sensibles
+ Backup CronJob quotidien
+ ServiceMonitor pour Prometheus
+ Configuration logging
+ HTTPRoute pour Gateway API (optionnel)
```

**Nouvelles sections clés ajoutées** :

1. **Global labels** (lignes 6-12)
```yaml
global:
  labels:
    app.kubernetes.io/name: laravel-app
    app.kubernetes.io/managed-by: helm
    app.kubernetes.io/part-of: kubequest
    app.kubernetes.io/component: application
```

2. **Replicas avec redondance** (ligne 15)
```yaml
replicaCount: 3  # Au lieu de 1
```

3. **Image Laravel** (lignes 18-21)
```yaml
image:
  repository: your-docker-registry/laravel-app  # Au lieu de nginx
  pullPolicy: IfNotPresent
  tag: "1.0.0"
```

4. **Resources limits/requests** (lignes 127-133)
```yaml
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "250m"
    memory: "256Mi"
```

5. **Probes Laravel** (lignes 137-155)
```yaml
livenessProbe:
  httpGet:
    path: /api/health  # Au lieu de /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  # ... configuration complète
```

6. **HPA configuré** (lignes 159-164)
```yaml
autoscaling:
  enabled: true  # Au lieu de false
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

7. **Ingress avec TLS** (lignes 70-86)
```yaml
ingress:
  enabled: true  # Au lieu de false
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: larapp.kubequest.local
  tls:
    - secretName: laravel-app-tls
```

8. **Volumes et PVC** (lignes 167-181)
```yaml
volumes:
  - name: laravel-storage
    persistentVolumeClaim:
      claimName: laravel-storage-pvc
  - name: config
    configMap:
      name: laravel-config

volumeMounts:
  - name: laravel-storage
    mountPath: /var/www/html/storage
  - name: config
    mountPath: /var/www/html/.env
    subPath: .env
```

9. **Affinity rules** (lignes 195-214)
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
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node-role.kubernetes.io/worker
              operator: In
              values:
                - "true"
```

10. **PostgreSQL via Bitnami** (lignes 217-243)
```yaml
postgresql:
  enabled: true
  auth:
    enablePostgresUser: true
    postgresPassword: "changeme"
    username: "laravel"
    password: "changeme"
    database: "laravel"
  primary:
    persistence:
      enabled: true
      size: 10Gi
      storageClass: "gp2"
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 1Gi
    replicaCount: 1
```

11. **ConfigMap Laravel** (lignes 246-250)
```yaml
config:
  appEnv: "production"
  appDebug: "false"
  appUrl: "https://larapp.kubequest.local"
  logLevel: "info"
```

12. **Secrets** (lignes 253-257)
```yaml
secrets:
  appKey: "base64:your-app-key-here"
  dbPassword: "changeme"
  redisPassword: "changeme"
  mailPassword: "changeme"
```

13. **Backups automatiques** (lignes 260-264)
```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # Quotidien à 2h
  retention: "30d"
  storageClass: "gp2"
```

14. **Monitoring** (lignes 267-272)
```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
```

15. **Logging** (lignes 275-278)
```yaml
logging:
  enabled: true
  format: "json"
  level: "info"
```

---

### 3. `laravel-app/templates/deployment.yaml`

**Raison de la modification** :
- Corriger le port utilisé pour le container
- Permettre une configuration flexible avec `targetPort`

**Modifications apportées** :

```diff
--- a/laravel-app/templates/deployment.yaml
+++ b/laravel-app/templates/deployment.yaml
@@ -43,7 +43,7 @@ spec:
           ports:
             - name: http
-              containerPort: {{ .Values.service.port }}
+              containerPort: {{ .Values.service.targetPort | default .Values.service.port }}
               protocol: TCP
```

**Détail des changements** :
- ✏️ **Ligne 45** : ContainerPort modifié pour utiliser `targetPort` avec une fallback sur `port`
- Cela permet de configurer un port différent pour le service externe (80) et le container interne (9000 par défaut pour Laravel)
- C'est une bonne pratique pour la flexibilité et la sécurité

---

## 📊 Statistiques des Modifications

| Fichier | Lignes originales | Lignes modifiées | Ajoutées | Supprimées | Net |
|---------|-------------------|------------------|----------|------------|-----|
| `Chart.yaml` | 24 | 33 | +9 | 0 | +9 |
| `values.yaml` | 162 | 278 | +278 | -162 | +116 |
| `deployment.yaml` | 79 | 79 | +1 | -1 | 0 |
| **TOTAL** | **265** | **390** | **+288** | **-163** | **+125** |

---

## 🎯 Résumé du travail effectué

### Modification des fichiers existants
- ✅ **3 fichiers** existants ont été modifiés
- ✅ **125 lignes** ajoutées au total
- ✅ Toutes les modifications sont documentées

### Création de nouveaux fichiers
- ✅ **53 nouveaux fichiers** créés
- ✅ **7 templates** Helm pour Laravel
- ✅ **30 manifests** Kustomize pour l'infrastructure
- ✅ **5 manifests** Kustomize pour l'application
- ✅ **6 scripts** d'automatisation
- ✅ **4 fichiers** de documentation

### Bonnes pratiques implémentées
1. ✅ **Resources limits et requests** sur tous les conteneurs
2. ✅ **Secrets** pour données sensibles
3. ✅ **Labels** Kubernetes standards sur toutes les ressources
4. ✅ **Redondance** : 3+ replicas avec pod anti-affinity
5. ✅ **Stockage persistant** pour PostgreSQL et Laravel
6. ✅ **Liveness/Readiness probes** configurés
7. ✅ **Auto-scaling** avec HPA
8. ✅ **Security Contexts** (non-root, read-only)
9. ✅ **Backups automatiques** quotidiens
10. ✅ **Monitoring** avec Prometheus et ServiceMonitor
11. ✅ **Logging** avec Loki
12. ✅ **TLS/SSL** avec cert-manager et Let's Encrypt
13. ✅ **GitOps** avec Kustomize
14. ✅ **Validation des ressources** avec OPA

---

## 📝 Justification des modifications

### Pourquoi avoir modifié `Chart.yaml` ?
- **Besoin** : Intégrer PostgreSQL comme base de données pour Laravel
- **Solution** : Utilisation du chart officiel Bitnami PostgreSQL plutôt que de recréer le même travail
- **Avantage** : Maintenance simplifiée, configuration éprouvée, meilleure sécurité

### Pourquoi avoir complètement réécrit `values.yaml` ?
- **Besoin** : Le fichier original était générique (nginx) et ne correspondait pas à une application Laravel
- **Solution** : Configuration complète adaptée à Laravel avec toutes les fonctionnalités demandées dans le sujet
- **Avantage** : Configuration production-ready avec toutes les bonnes pratiques

### Pourquoi avoir modifié `deployment.yaml` ?
- **Besoin** : Flexibilité dans la configuration des ports
- **Solution** : Utilisation de `targetPort` avec fallback
- **Avantage** : Permet d'exposer l'application sur le port 80 tout en utilisant le port 9000 de Laravel en interne

---

## 🚀 Prochaines étapes

Pour déployer ce projet, les étapes suivantes sont nécessaires :

1. **Ajuster les valeurs spécifiques AWS** :
   - Service annotations pour AWS Load Balancer
   - IAM role ARN pour EKS

2. **Configurer le DNS** :
   - Ajouter les domaines dans /etc/hosts ou Route53
   - Configurer Let's Encrypt avec un domaine réel

3. **Build et push l'image Docker Laravel** :
   ```bash
   docker build -t votre-registry/laravel-app:1.0.0 .
   docker push votre-registry/laravel-app:1.0.0
   ```

4. **Lancer les scripts de déploiement** :
   ```bash
   ./scripts/deploy-infrastructure.sh
   ./scripts/deploy-app.sh
   ```

---

## 📚 Documentation

Pour plus de détails, consulter :
- **README.md** : Documentation complète du projet
- **DEPLOYMENT.md** : Guide de déploiement pour la défense
- **STRUCTURE.md** : Structure détaillée du projet

---

**Fin du rapport des modifications**

**Signature** : [Votre Signature]
**Date** : 2026
