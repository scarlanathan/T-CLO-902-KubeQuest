# 🚀 GUIDE DE REDÉMARRAGE ET TESTS - KUBEQUEST

**Date:** 19 juin 2026
**Groupe:** 50
**Objectif:** Redémarrer le cluster AWS et exécuter tous les tests

---

## 📋 PRÉREQUIS

Vos accès AWS:
- **URL Console:** https://649966626926.signin.aws.amazon.com/console
- **Account ID:** 649966626926
- **Username:** student-frankfurt-group-50
- **Password:** JioPoulet98/
- **Région:** eu-central-1 (Frankfurt)

---

## ÉTAPE 1: REDÉMARRER LES INSTANCES AWS

### 1.1 Se connecter à AWS Console

1. Ouvrir: https://649966626926.signin.aws.amazon.com/console
2. Entrer:
   - Account ID: `649966626926`
   - Username: `student-frankfurt-group-50`
   - Password: `JioPoulet98/`
3. Cliquer **Sign in**

### 1.2 Accéder à EC2

1. Dans la barre de recherche (en haut), taper: `EC2`
2. Cliquer sur **EC2** (service)
3. Vérifier que la région est bien: **eu-central-1 (Frankfurt)**
   - En haut à droite, à côté de votre nom

### 1.3 Démarrer les 4 instances

1. Cliquer sur **Instances** dans le menu de gauche
2. Vous devriez voir 4 instances:
   - `ec2-group-50-node-1` (Control Plane)
   - `ec2-group-50-node-2` (Worker)
   - `ec2-group-50-node-3` (Ingress)
   - `ec2-group-50-node-4` (Monitoring)

3. **Sélectionner les 4 instances** (cocher les cases)
4. Cliquer **Instance state** > **Start instance**
5. Attendre 2-3 minutes que le **Instance state** devienne **Running**

### 1.4 Noter les nouvelles IP publiques

⚠️ **IMPORTANT:** Les IP publiques changent à chaque redémarrage !

Cliquer sur chaque instance et noter la **Public IPv4 address**:

```
node-1: ___________________  (Control Plane)
node-2: ___________________  (Worker)
node-3: ___________________  (Ingress)
node-4: ___________________  (Monitoring)
```

**Anciennes IPs (pour référence):**
- node-1: 35.156.165.130
- node-2: 3.79.247.101
- node-3: 3.77.235.74
- node-4: 3.120.183.206

---

## ÉTAPE 2: RÉCUPÉRER LA CLÉ SSH

### Option A: Depuis AWS Console (recommandé)

1. Dans AWS Console, cliquer sur **Services** > **Systems Manager**
2. Dans le menu de gauche, cliquer **Parameter Store**
3. Chercher: `/kubequest/group-50/ssh-private-key`
4. Cliquer sur le paramètre
5. Cliquer **Show** dans la section **Value**
6. Copier la clé privée complète (de `-----BEGIN` à `-----END-----`)

7. Sur votre Mac, ouvrir Terminal et créer le fichier:
```bash
cat > ~/.ssh/kubequest.pem << 'EOF'
[COLLER LA CLÉ ICI]
EOF

chmod 400 ~/.ssh/kubequest.pem
```

### Option B: Depuis AWS CloudShell

1. Dans AWS Console, cliquer sur l'icône **CloudShell** (en haut à droite)
2. Attendre que CloudShell démarre
3. Exécuter:
```bash
aws ssm get-parameter \
  --name "/kubequest/group-50/ssh-private-key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text
```

4. Copier le résultat dans votre Mac:
```bash
# Sur votre Mac
cat > ~/.ssh/kubequest.pem << 'EOF'
[COLLER LA CLÉ ICI]
EOF

chmod 400 ~/.ssh/kubequest.pem
```

---

## ÉTAPE 3: TESTER LA CONNEXION SSH

Remplacer `<IP-NODE-1>` par l'IP publique de node-1:

```bash
ssh -i ~/.ssh/kubequest.pem ec2-user@<IP-NODE-1>
```

Si ça fonctionne, vous verrez:
```
   ,     #_
   ~\_  ####_        Amazon Linux 2023
  ~~  \_#####\
  ~~     \###|
  ~~       \#/ ___   https://aws.amazon.com/linux/amazon-linux-2023
   ~~       V~' '->
    ~~~         /
      ~~._.   _/
         _/ _/
       _/m/'

[ec2-user@ip-10-2-50-23 ~]$
```

**Tester que Kubernetes fonctionne:**
```bash
kubectl get nodes
```

Vous devriez voir les 4 nodes en status **Ready**.

Taper `exit` pour quitter.

---

## ÉTAPE 4: CONFIGURER KUBECTL LOCALEMENT

### 4.1 Récupérer le kubeconfig depuis node-1

```bash
# Remplacer <IP-NODE-1> par l'IP de node-1
ssh -i ~/.ssh/kubequest.pem ec2-user@<IP-NODE-1> "sudo cat /etc/kubernetes/admin.conf" > /tmp/kubeconfig-kubequest
```

### 4.2 Modifier le kubeconfig pour utiliser l'IP publique

```bash
# Remplacer l'IP locale par l'IP publique de node-1
sed -i '' "s/https:\/\/[0-9.]*:6443/https:\/\/<IP-NODE-1>:6443/" /tmp/kubeconfig-kubequest

# OU éditer manuellement:
# Ouvrir /tmp/kubeconfig-kubequest
# Chercher "server: https://10.2.50.23:6443"
# Remplacer par "server: https://<IP-NODE-1>:6443"
```

### 4.3 Sauvegarder votre kubeconfig actuel (si vous en avez un)

```bash
# Backup (optionnel)
cp ~/.kube/config ~/.kube/config.backup.$(date +%Y%m%d)
```

### 4.4 Utiliser le nouveau kubeconfig

**Option 1: Remplacer le kubeconfig par défaut**
```bash
cp /tmp/kubeconfig-kubequest ~/.kube/config
```

**Option 2: Utiliser un contexte séparé (recommandé)**
```bash
# Fusionner avec le kubeconfig existant
KUBECONFIG=~/.kube/config:/tmp/kubeconfig-kubequest kubectl config view --flatten > /tmp/merged-kubeconfig
cp /tmp/merged-kubeconfig ~/.kube/config

# Basculer vers le contexte kubequest
kubectl config use-context kubernetes-admin@kubernetes
```

### 4.5 Tester l'accès

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

**Si tout fonctionne, vous devriez voir:**
```
Kubernetes control plane is running at https://<IP-NODE-1>:6443
CoreDNS is running at https://<IP-NODE-1>:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

NAME     STATUS   ROLES           AGE   VERSION
node-1   Ready    control-plane   ...   v1.31.14
node-2   Ready    <none>          ...   v1.31.14
node-3   Ready    <none>          ...   v1.31.14
node-4   Ready    <none>          ...   v1.31.14
```

---

## ÉTAPE 5: METTRE À JOUR /etc/hosts

**Remplacer l'IP de node-3 par la nouvelle:**

```bash
# Éditer /etc/hosts
sudo nano /etc/hosts

# Ajouter ou modifier ces lignes (remplacer <IP-NODE-3> par l'IP de node-3):
<IP-NODE-3> app.kubequest.local
<IP-NODE-3> grafana.kubequest.local
<IP-NODE-3> prometheus.kubequest.local
<IP-NODE-3> dashboard.kubequest.local
<IP-NODE-3> loki.kubequest.local

# Sauvegarder: Ctrl+O, Enter, Ctrl+X
```

---

## ÉTAPE 6: VÉRIFIER L'ÉTAT ACTUEL DU CLUSTER

### 6.1 Script de vérification rapide

```bash
cd /Users/lioratoledano/Documents/Cloud/T-CLO-902-PAR_5

# Exécuter le script de health check
chmod +x kubequest-cluster/scripts/health-check.sh
./kubequest-cluster/scripts/health-check.sh
```

### 6.2 Vérifications manuelles

```bash
# 1. Vérifier les nodes
echo "=== NODES ==="
kubectl get nodes -o wide

# 2. Vérifier les namespaces
echo -e "\n=== NAMESPACES ==="
kubectl get namespaces

# 3. Vérifier tous les pods
echo -e "\n=== PODS (tous) ==="
kubectl get pods --all-namespaces -o wide

# 4. Vérifier les pods NON-Running (problèmes potentiels)
echo -e "\n=== PODS EN ERREUR ==="
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# 5. Vérifier les services
echo -e "\n=== SERVICES ==="
kubectl get svc --all-namespaces

# 6. Vérifier les ingress
echo -e "\n=== INGRESS ==="
kubectl get ingress --all-namespaces

# 7. Vérifier les PVCs
echo -e "\n=== PERSISTENT VOLUME CLAIMS ==="
kubectl get pvc --all-namespaces

# 8. Vérifier les HPA
echo -e "\n=== HORIZONTAL POD AUTOSCALERS ==="
kubectl get hpa --all-namespaces

# 9. Vérifier les CronJobs
echo -e "\n=== CRONJOBS (Backups) ==="
kubectl get cronjob --all-namespaces

# 10. Vérifier les certificats TLS
echo -e "\n=== CERTIFICATS TLS ==="
kubectl get certificates --all-namespaces
```

---

## ÉTAPE 7: EXÉCUTER LES TESTS AUTOMATISÉS

### 7.1 Tests Production-Ready

```bash
cd /Users/lioratoledano/Documents/Cloud/T-CLO-902-PAR_5/production-ready

# Vérifier les prérequis
chmod +x check-prerequis.sh
./check-prerequis.sh

# Lancer les tests complets
chmod +x test-production-ready.sh
./test-production-ready.sh
```

### 7.2 Tests d'infrastructure

```bash
cd /Users/lioratoledano/Documents/Cloud/T-CLO-902-PAR_5

# Test 1: Ingress Controller
echo "=== TEST INGRESS CONTROLLER ==="
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Test 2: Kubernetes Dashboard
echo -e "\n=== TEST KUBERNETES DASHBOARD ==="
kubectl get pods -n kubernetes-dashboard
kubectl get svc -n kubernetes-dashboard

# Test 3: Monitoring (Prometheus + Grafana)
echo -e "\n=== TEST MONITORING ==="
kubectl get pods -n monitoring
kubectl get svc -n monitoring | grep -E "(prometheus|grafana)"

# Test 4: Logging (Loki)
echo -e "\n=== TEST LOGGING ==="
kubectl get pods -n monitoring | grep loki
kubectl get svc -n monitoring | grep loki

# Test 5: OPA (Security)
echo -e "\n=== TEST OPA ==="
kubectl get pods -n opa
kubectl get validatingwebhookconfigurations
```

### 7.3 Tests d'application Laravel

```bash
# Vérifier si l'application est déployée
echo "=== TEST APPLICATION LARAVEL ==="
kubectl get namespace laravel

# Si le namespace existe:
kubectl get pods -n laravel
kubectl get svc -n laravel
kubectl get ingress -n laravel
kubectl get pvc -n laravel
kubectl get hpa -n laravel

# Si le namespace n'existe pas, déployer:
cd /Users/lioratoledano/Documents/Cloud/T-CLO-902-PAR_5/kubequest-cluster
chmod +x scripts/deploy-app.sh
./scripts/deploy-app.sh
```

---

## ÉTAPE 8: TESTS D'ACCÈS WEB

### 8.1 Test Grafana

```bash
# Via Ingress
curl -I http://grafana.kubequest.local

# Si ça fonctionne, ouvrir dans le navigateur:
open http://grafana.kubequest.local

# Identifiants par défaut (vérifier dans les secrets):
kubectl get secret -n monitoring prometheus-kube-prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d
echo ""
# Username: admin
# Password: <le résultat de la commande ci-dessus>
```

### 8.2 Test Prometheus

```bash
# Via Ingress
curl -I http://prometheus.kubequest.local

# Ouvrir dans le navigateur:
open http://prometheus.kubequest.local
```

### 8.3 Test Kubernetes Dashboard

```bash
# Via Ingress
curl -I http://dashboard.kubequest.local:32222

# Récupérer le token d'accès:
kubectl -n kubernetes-dashboard create token admin-user

# Ouvrir dans le navigateur:
open http://dashboard.kubequest.local:32222

# Coller le token quand demandé
```

### 8.4 Test Application Laravel (si déployée)

```bash
# Via Ingress
curl -I http://app.kubequest.local

# Ouvrir dans le navigateur:
open http://app.kubequest.local
```

---

## ÉTAPE 9: TESTS DE CHARGE ET DÉMOS

### 9.1 Test de charge (Auto-Scaling)

```bash
cd /Users/lioratoledano/Documents/Cloud/T-CLO-902-PAR_5

chmod +x load-test.sh
./load-test.sh

# Observer les replicas augmenter:
watch kubectl get hpa -n laravel
# Ctrl+C pour arrêter
```

### 9.2 Démo de Rollback

```bash
cd /Users/lioratoledano/Documents/Cloud/T-CLO-902-PAR_5

chmod +x rollback-demo.sh
./rollback-demo.sh

# Observer le processus de rollback
```

---

## ÉTAPE 10: TESTS DE SÉCURITÉ

### 10.1 Test OPA (Validating Webhook)

```bash
# Test 1: Créer un pod SANS labels (devrait être REJETÉ)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-no-labels
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx
EOF

# Résultat attendu: Error - pod rejeté par OPA
```

```bash
# Test 2: Créer un pod AVEC labels (devrait être ACCEPTÉ)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-with-labels
  namespace: default
  labels:
    app.kubernetes.io/name: test-app
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        cpu: "100m"
        memory: "128Mi"
      requests:
        cpu: "50m"
        memory: "64Mi"
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
EOF

# Résultat attendu: pod/test-pod-with-labels created
```

```bash
# Nettoyer
kubectl delete pod test-pod-with-labels
```

### 10.2 Test Network Policies

```bash
# Vérifier les Network Policies existantes
kubectl get networkpolicies --all-namespaces

# Tester la connectivité (si Laravel est déployé)
# Créer un pod de test dans le namespace laravel
kubectl run -n laravel test-curl --image=curlimages/curl -it --rm -- sh

# Depuis le pod:
# Test 1: Accès à MySQL (devrait fonctionner depuis Laravel namespace)
curl mysql:3306

# Test 2: Accès externe (devrait fonctionner via egress DNS)
curl -I https://google.com

# Taper 'exit' pour quitter
```

### 10.3 Test Certificats TLS

```bash
# Vérifier les certificats
kubectl get certificates --all-namespaces

# Vérifier l'état des certificats
kubectl describe certificate -n laravel app-kubequest-tls

# Tester HTTPS (si cert-manager est déployé)
curl -kI https://app.kubequest.local
```

---

## ÉTAPE 11: TESTS DE BACKUP

### 11.1 Vérifier le PVC de backup

```bash
# Vérifier que le PVC est Bound
kubectl get pvc -n laravel | grep backup

# Résultat attendu:
# mysql-backup-pvc   Bound   ...
```

### 11.2 Déclencher un backup manuel

```bash
# Créer un job manuel depuis le CronJob
kubectl create job --from=cronjob/mysql-backup manual-backup-test -n laravel

# Surveiller le job
kubectl get jobs -n laravel
kubectl logs job/manual-backup-test -n laravel

# Vérifier que le backup a été créé
kubectl exec -n laravel deployment/mysql -- ls -lh /backups/
```

### 11.3 Vérifier le CronJob de backup

```bash
# Vérifier le CronJob
kubectl get cronjob -n laravel

# Voir les derniers jobs exécutés
kubectl get jobs -n laravel | grep backup

# Voir les logs du dernier backup
kubectl logs -n laravel $(kubectl get pods -n laravel -l job-name --sort-by=.metadata.creationTimestamp | tail -1 | awk '{print $1}')
```

---

## ÉTAPE 12: TESTS DE MONITORING & ALERTING

### 12.1 Vérifier Prometheus Alerts

```bash
# Port-forward vers Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# Ouvrir dans le navigateur
open http://localhost:9090/alerts

# Vérifier que les alertes sont chargées:
# - LaravelPodDown
# - LaravelHighCPU
# - MySQLDown
# etc.

# Arrêter le port-forward
pkill -f "port-forward.*9090"
```

### 12.2 Vérifier les PrometheusRules

```bash
# Lister les PrometheusRules
kubectl get prometheusrules -n monitoring

# Voir le détail d'une règle
kubectl describe prometheusrule laravel-alerts -n monitoring
```

### 12.3 Vérifier Loki (Logs)

```bash
# Port-forward vers Loki
kubectl port-forward -n monitoring svc/loki 3100:3100 &

# Tester l'API Loki
curl http://localhost:3100/ready

# Dans Grafana, vérifier que Loki est connecté:
# Settings > Data Sources > Loki

# Arrêter le port-forward
pkill -f "port-forward.*3100"
```

---

## RÉCAPITULATIF DES COMMANDES RAPIDES

```bash
# === STATUT GÉNÉRAL ===
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running
kubectl get ingress --all-namespaces

# === ACCÈS WEB ===
# Grafana
open http://grafana.kubequest.local
kubectl get secret -n monitoring prometheus-kube-prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d

# Prometheus
open http://prometheus.kubequest.local

# Dashboard
open http://dashboard.kubequest.local:32222
kubectl -n kubernetes-dashboard create token admin-user

# Laravel (si déployé)
open http://app.kubequest.local

# === TESTS AUTOMATISÉS ===
cd /Users/lioratoledano/Documents/Cloud/T-CLO-902-PAR_5/production-ready
./check-prerequis.sh
./test-production-ready.sh

# === DÉMOS ===
cd /Users/lioratoledano/Documents/Cloud/T-CLO-902-PAR_5
./load-test.sh         # Auto-scaling
./rollback-demo.sh     # Rollback

# === MONITORING ===
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n monitoring svc/loki 3100:3100
```

---

## PROBLÈMES COURANTS ET SOLUTIONS

### Problème 1: kubectl timeout / connection refused

**Cause:** Le port 6443 de node-1 n'est pas accessible

**Solution:**
```bash
# Vérifier Security Group dans AWS Console
# EC2 > Security Groups > Chercher le SG de node-1
# Vérifier que le port 6443 est ouvert depuis votre IP

# OU utiliser SSH tunnel:
ssh -i ~/.ssh/kubequest.pem -L 6443:localhost:6443 ec2-user@<IP-NODE-1>
# Puis modifier kubeconfig pour utiliser https://localhost:6443
```

### Problème 2: Pods en CrashLoopBackOff

```bash
# Voir les logs du pod
kubectl logs <pod-name> -n <namespace>

# Voir les événements
kubectl describe pod <pod-name> -n <namespace>

# Redémarrer le pod
kubectl delete pod <pod-name> -n <namespace>
```

### Problème 3: Ingress ne fonctionne pas

```bash
# Vérifier que nginx-ingress tourne
kubectl get pods -n ingress-nginx

# Vérifier les logs de nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Vérifier que /etc/hosts est correct
cat /etc/hosts | grep kubequest
```

### Problème 4: Certificats TLS en Pending

```bash
# Vérifier cert-manager
kubectl get pods -n cert-manager

# Voir l'état du certificat
kubectl describe certificate <cert-name> -n <namespace>

# Voir les logs de cert-manager
kubectl logs -n cert-manager deployment/cert-manager
```

### Problème 5: HPA ne scale pas

```bash
# Vérifier que metrics-server est installé
kubectl get deployment metrics-server -n kube-system

# Si pas installé:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Vérifier les métriques
kubectl top nodes
kubectl top pods -n laravel
```

---

## CHECKLIST FINALE

- [ ] Instances AWS démarrées et en **Running**
- [ ] IP publiques notées
- [ ] Clé SSH récupérée dans ~/.ssh/kubequest.pem
- [ ] Connexion SSH testée vers node-1
- [ ] kubectl configuré localement
- [ ] kubectl cluster-info fonctionne
- [ ] /etc/hosts mis à jour avec nouvelle IP de node-3
- [ ] Tous les pods en **Running** (vérifier avec kubectl get pods -A)
- [ ] Ingress accessibles (grafana, prometheus, dashboard)
- [ ] Tests automatisés exécutés (./test-production-ready.sh)
- [ ] Grafana accessible et login OK
- [ ] Prometheus accessible
- [ ] Dashboard accessible avec token
- [ ] Application Laravel déployée (optionnel)
- [ ] Test de charge fonctionnel (./load-test.sh)
- [ ] Démo rollback fonctionnelle (./rollback-demo.sh)
- [ ] OPA teste et rejette les pods non-conformes
- [ ] Backups configurés et testés
- [ ] Prometheus alerts visibles
- [ ] Loki accessible

---

## PROCHAINES ÉTAPES

Une fois que tous les tests passent:

1. ✅ Pratiquer la présentation complète (30 min)
2. ✅ Préparer les réponses aux questions courantes
3. ✅ Faire des screenshots des dashboards
4. ✅ Tester le déploiement from scratch (pour la défense)
5. ✅ Lire le guide de présentation: PRESENTATION_GUIDE.md

---

**Bon courage pour les tests ! 🚀**

**Questions ?** Relire l'AUDIT_PROJET_KUBEQUEST.md pour plus de détails.
