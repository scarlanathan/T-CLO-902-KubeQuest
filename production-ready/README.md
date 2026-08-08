# 🚀 KUBEQUEST - 100% PRODUCTION-READY

Ce dossier contient tous les fichiers nécessaires pour passer votre projet KUBEQUEST de **95% à 100% production-ready**.

## 📋 CONTENU

| Fichier | Description |
|---------|-------------|
| `01-backup-pv.yaml` | Configuration du PersistentVolume et CronJob de backup |
| `02-monitoring-ingress.yaml` | Ingress pour Grafana, Prometheus et Dashboard |
| `03-cert-manager-and-issuers.yaml` | Cert-manager, ClusterIssuers Let's Encrypt et certificats TLS |
| `04-alerting-rules.yaml` | Règles Prometheus pour alertes critiques et warning |
| `05-network-policies.yaml` | Network Policies pour sécuriser les communications |
| `deploy-production-ready.sh` | Script de déploiement automatisé |
| `test-production-ready.sh` | Script de tests automatisés |

---

## 🎯 LES 5 POINTS AMÉLIORÉS

### 1️⃣ **FIXER LE PVC DE BACKUP** (Critical)
- ✅ PersistentVolume avec hostPath
- ✅ PersistentVolumeClaim fonctionnel
- ✅ CronJob de backup avec rétention 7 jours
- ✅ Stockage local sur les nodes

### 2️⃣ **INGRESS POUR MONITORING** (High)
- ✅ Accès Grafana: `http://grafana.kubequest.local`
- ✅ Accès Prometheus: `http://prometheus.kubequest.local`
- ✅ Accès Dashboard: `http://dashboard.kubequest.local`

### 3️⃣ **CERTIFICATS TLS** (High)
- ✅ Cert-manager installé
- ✅ ClusterIssuer Let's Encrypt (Staging + Production)
- ✅ Certificats TLS automatiques pour:
  - app.kubequest.local (Laravel)
  - grafana.kubequest.local
  - dashboard.kubequest.local

### 4️⃣ **ALERTING & NOTIFICATIONS** (Medium)
- ✅ Alertes critiques (Pods down, MySQL down)
- ✅ Alertes warning (CPU élevé, Mémoire élevée, HPA max)
- ✅ Alertes infrastructure (Node down, Disque faible)
- ✅ Intégration Slack (placeholder à configurer)

### 5️⃣ **NETWORK POLICIES** (Medium)
- ✅ Policy deny-all par défaut dans namespace laravel
- ✅ Policy Laravel (Ingress → Laravel → MySQL)
- ✅ Policy MySQL (autorise seulement Laravel)
- ✅ Policy Monitoring (Prometheus scraping)
- ✅ Policy Grafana (accès depuis Ingress)

---

## 📦 DÉPLOIEMENT

### Option 1: Déploiement automatisé (Recommandé)

```bash
# Se rendre dans le dossier
cd production-ready/

# Rendre le script exécutable
chmod +x deploy-production-ready.sh

# Exécuter le déploiement
./deploy-production-ready.sh
```

### Option 2: Déploiement manuel

```bash
# Point 1: Backup PV
kubectl apply -f 01-backup-pv.yaml

# Point 2: Monitoring Ingress
kubectl apply -f 02-monitoring-ingress.yaml

# Point 3: Cert-manager (si pas installé)
# Installer cert-manager d'abord:
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.0 \
  --set installCRDs=true

# Puis appliquer les certificates
kubectl apply -f 03-cert-manager-and-issuers.yaml

# Point 4: Alerting
kubectl apply -f 04-alerting-rules.yaml

# Point 5: Network Policies
kubectl apply -f 05-network-policies.yaml
```

---

## 🧪 TESTS

### Lancer tous les tests

```bash
# Rendre le script exécutable
chmod +x test-production-ready.sh

# Exécuter les tests
./test-production-ready.sh
```

### Tests manuels

```bash
# Test 1: PVC
kubectl get pvc -n laravel
kubectl get pv
kubectl get cronjob -n laravel

# Test 2: Ingress
kubectl get ingress --all-namespaces
# Ajouter au /etc/hosts:
# 3.77.235.74 grafana.kubequest.local prometheus.kubequest.local dashboard.kubequest.local

# Test 3: Certificates
kubectl get certificates --all-namespaces
kubectl get clusterissuer
kubectl logs -n cert-manager deployment/cert-manager --tail=50

# Test 4: Alerting
kubectl get prometheusrules -n monitoring
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Ouvrir http://localhost:9090/alerts

# Test 5: Network Policies
kubectl get networkpolicies --all-namespaces
kubectl describe networkpolicy laravel-policy -n laravel
```

---

## 🔧 CONFIGURATION REQUISE

### Avant le déploiement

1. **Accès SSH aux nodes**
   ```bash
   # Créer le dossier de backup sur tous les nodes worker:
   ssh -i kubequest.pem ec2-user@<worker-ip>
   sudo mkdir -p /mnt/data/mysql-backups
   sudo chmod 777 /mnt/data/mysql-backups
   ```

2. **Connexion au cluster**
   ```bash
   # Vérifier que kubectl est connecté
   kubectl cluster-info
   kubectl get nodes
   ```

### Après le déploiement

1. **Mettre à jour /etc/hosts**
   ```bash
   # Sur votre machine locale
   sudo nano /etc/hosts

   # Ajouter:
   3.77.235.74 app.kubequest.local
   3.77.235.74 grafana.kubequest.local
   3.77.235.74 prometheus.kubequest.local
   3.77.235.74 dashboard.kubequest.local
   ```

2. **Configurer Slack (optionnel)**
   ```bash
   # Éditer 04-alerting-rules.yaml
   # Remplacer l'URL webhook par votre véritable URL Slack
   kubectl create secret generic slack-webhook \
     --from-literal=url=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
     -n monitoring
   ```

3. **Attendre les certificats TLS (5-10 min)**
   ```bash
   # Surveiller la génération des certificats
   watch kubectl get certificates --all-namespaces

   # Vérifier les détails d'un certificate
   kubectl describe certificate app-kubequest-tls -n laravel
   ```

---

## 📊 RÉSULTAT ATTENDU

Après déploiement, vous aurez:

| Composant | Avant | Après |
|-----------|-------|-------|
| **Backup** | ❌ PVC Pending | ✅ PVC Bound avec backups quotidiens |
| **Monitoring** | ❌ Port-forward uniquement | ✅ Accès externe via Ingress |
| **TLS** | ❌ HTTP uniquement | ✅ HTTPS automatique avec Let's Encrypt |
| **Alerting** | ⚠️ Aucune alerte | ✅ Alertes critiques + warning |
| **Sécurité** | ⚠️ Tout autorisé | ✅ Policies restrictives |

---

## 🐛 DÉBOGUAGE

### PVC reste Pending

```bash
# Vérifier les events
kubectl describe pvc mysql-backup-pvc-new -n laravel

# Si "no persistent volumes available", créer le dossier sur le node:
ssh -i kubequest.pem ec2-user@<worker-ip> "sudo mkdir -p /mnt/data/mysql-backups && sudo chmod 777 /mnt/data/mysql-backups"

# Réappliquer le PV
kubectl delete pv mysql-backup-pv
kubectl apply -f 01-backup-pv.yaml
```

### Certificats TLS ne se génèrent pas

```bash
# Vérifier cert-manager
kubectl get pods -n cert-manager
kubectl logs -n cert-manager deployment/cert-manager

# Vérifier ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod

# Vérifier Certificate
kubectl get certificates --all-namespaces
kubectl describe certificate app-kubequest-tls -n laravel

# Forcer la recréation
kubectl delete certificate app-kubequest-tls -n laravel
kubectl apply -f 03-cert-manager-and-issuers.yaml
```

### Ingress ne fonctionne pas

```bash
# Vérifier l'ingress controller
kubectl get pods -n ingress-nginx

# Vérifier les ingress
kubectl get ingress --all-namespaces
kubectl describe ingress grafana-ingress -n monitoring

# Tester localement (ajouter au /etc/hosts d'abord)
curl -v http://grafana.kubequest.local
```

### Network Policies bloquent tout

```bash
# Vérifier les policies
kubectl get networkpolicies --all-namespaces

# Tester la connexion entre pods
kubectl run test-pod -n laravel --image=nicolaka/netshoot --rm -it --restart=Never -- wget -O- http://laravel:80

# Supprimer une policy spécifique pour tester
kubectl delete networkpolicy default-deny-all -n laravel
```

### Alertes ne se déclenchent pas

```bash
# Vérifier Prometheus rules
kubectl get prometheusrules -n monitoring
kubectl describe prometheusrules laravel-critical-alerts -n monitoring

# Vérifier AlertManager
kubectl get configmap alertmanager-config -n monitoring -o yaml

# Port-forward vers Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Ouvrir http://localhost:9090/rules
# Ouvrir http://localhost:9090/alerts
```

---

## 🎓 POUR VOTRE PRÉSENTATION

### Points forts à mentionner

1. **Backups automatisés** - CronJob quotidien avec rétention
2. **Monitoring accessible** - Grafana/Prometheus via Ingress
3. **HTTPS sécurisé** - Certificats automatiques Let's Encrypt
4. **Alerting proactif** - Alertes critiques et warning
5. **Sécurité renforcée** - Network Policies restrictives

### Démonstration en direct

```bash
# 1. Montrer les Network Policies
kubectl get networkpolicies --all-namespaces

# 2. Montrer les certificats TLS
kubectl get certificates --all-namespaces

# 3. Accéder à Grafana
curl -I https://grafana.kubequest.local

# 4. Vérifier les alertes Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Ouvrir http://localhost:9090/alerts

# 5. Tester le backup
kubectl get cronjob -n laravel
kubectl create job --from=cronjob/mysql-backup-fixed manual-backup -n laravel
kubectl logs -n laravel -l app=mysql-backup
```

---

## 📚 DOCUMENTATION UTILE

- [Cert-manager Documentation](https://cert-manager.io/docs/)
- [Prometheus Alerting](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

---

## ✅ CHECKLIST FINALE

Avant votre présentation, vérifiez:

- [ ] PVC mysql-backup-pvc-new est Bound
- [ ] Ingress Grafana, Prometheus et Dashboard créés
- [ ] Certificates sont Ready (peut prendre 10 min)
- [ ] PrometheusRules sont présentes dans monitoring
- [ ] NetworkPolicies sont créées dans tous les namespaces
- [ ] Tests automatisés passent: `./test-production-ready.sh`
- [ ] Application accessible via HTTPS
- [ ] Backups peuvent se créer manuellement

---

**Félicitations! Votre projet est maintenant 100% PRODUCTION-READY!** 🚀
