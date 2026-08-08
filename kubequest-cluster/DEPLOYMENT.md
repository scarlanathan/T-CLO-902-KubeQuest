# Guide de Déploiement

Ce guide détaille le processus de déploiement complet pour la défense du projet.

## 🎯 Objectifs de la défense

1. **Déploiement frais** : Démarrer un cluster Kubernetes vierge
2. **Déploiement GitOps** : Utiliser uniquement `kubectl apply -f`, `kustomize`, et `helm`
3. **Démonstration live** : Exécuter des scripts pour montrer l'autoscaling
4. **Déploiement et rollback** : Démontrer un déploiement réussi et un rollback automatique

## 📋 Préparation avant la défense

### 1. Préparer le cluster

```bash
# Si vous utilisez Kind (pour les tests)
kind create cluster --config kind.yaml --name kubequest

# Si vous utilisez un cluster AWS
kubectl config use-context <votre-contexte-aws>

# Vérifier la connexion
kubectl cluster-info
kubectl get nodes
```

### 2. Cloner le dépôt

```bash
git clone <votre-repo>
cd kubequest-cluster

# Vérifier que vous êtes sur la bonne branche
git branch
```

### 3. Vérifier les outils

```bash
# Vérifier les versions
kubectl version --client
helm version
kustomize version

# Vérifier l'accès au cluster
kubectl get namespaces
```

## 🚀 Scénario de Déploiement (Defense)

### Étape 1 : Déploiement de l'infrastructure (5-10 minutes)

```bash
# Rendre les scripts exécutables
chmod +x scripts/*.sh

# Déployer toute l'infrastructure
./scripts/deploy-infrastructure.sh
```

**Ce que vous expliquez :**
- "Je déploie d'abord l'infrastructure de base"
- "nginx-ingress servira de load balancer interne"
- "cert-manager gérera automatiquement les certificats SSL"
- "Prometheus et Grafana pour le monitoring"
- "Loki pour la collecte centralisée des logs"
- "Kubernetes Dashboard pour la gestion visuelle"
- "OPA comme validating webhook pour la sécurité"

**Vérifications en direct :**

```bash
# Vérifier que tous les pods sont running
kubectl get pods --all-namespaces

# Attendre que tout soit ready (2-3 minutes)
watch kubectl get pods --all-namespaces
```

### Étape 2 : Vérification des composants (2-3 minutes)

```bash
# Exécuter le script de santé
./scripts/health-check.sh
```

**Ce que vous expliquez :**
- "Tous les composants sont opérationnels"
- "On peut voir les ingress, services, HPAs, PVCs, et certificats"

### Étape 3 : Déploiement de l'application (3-5 minutes)

```bash
# Déployer l'application Laravel
./scripts/deploy-app.sh
```

**Ce que vous expliquez :**
- "Je déploie maintenant l'application Laravel avec Helm"
- "PostgreSQL est déployé comme dépendance via le chart Bitnami"
- "Les secrets sont créés pour les données sensibles"
- "L'application a 3 replicas par défaut avec HPA configuré"
- "Un backup automatique quotidien est programmé via CronJob"

**Vérifications :**

```bash
# Vérifier les pods de l'application
kubectl -n laravel-app get pods

# Vérifier le HPA
kubectl -n laravel-app get hpa

# Vérifier l'ingress
kubectl -n laravel-app get ingress

# Vérifier les PVCs
kubectl -n laravel-app get pvc
```

### Étape 4 : Démonstration de l'autoscaling (5-10 minutes)

```bash
# Lancer le test de charge
./scripts/load-test.sh
```

**Ce que vous montrez :**
- "Je lance un test de charge avec Apache Bench"
- "10000 requêtes avec 100 connexions simultanées"
- "Regardez les replicas augmenter automatiquement"

**Expliquez la configuration :**
- "L'HPA est configuré pour scale entre 3 et 15 replicas"
- "Le seuil est de 70% d'utilisation CPU"
- "Les pods se distribuent sur les différents nodes grâce à l'anti-affinity"

**Vérifications :**

```bash
# Surveiller le HPA en temps réel
kubectl -n laravel-app get hpa laravel-app -w

# Surveiller les pods
kubectl -n laravel-app get pods -w
```

### Étape 5 : Démonstration de rollback (3-5 minutes)

```bash
# Lancer la démo de rollback
./scripts/rollback-demo.sh
```

**Ce que vous montrez :**
- "Je déploye une nouvelle version simulée (2.0.0)"
- "Puis je simule un déploiement défaillant avec une image inexistante"
- "Kubernetes détecte automatiquement le problème"
- "J'effectue un rollback vers la version précédente"
- "L'application revient à son état fonctionnel"

**Expliquez le processus :**
- "Kubernetes garde l'historique des révisions de déploiement"
- "Le rollback est instantané car l'image précédente est déjà téléchargée"
- "C'est un exemple de zero-downtime deployment"

**Vérifications :**

```bash
# Voir l'historique des déploiements
kubectl -n laravel-app rollout history deployment/laravel-app

# Vérifier l'état actuel
kubectl -n laravel-app get deployment laravel-app
```

### Étape 6 : Démonstration des bonnes pratiques (2-3 minutes)

```bash
# Montrer les labels Kubernetes
kubectl -n laravel-app get pods --show-labels

# Vérifier les resources limits/requests
kubectl -n laravel-app describe pod <pod-name> | grep -A 10 "Limits\|Requests"

# Vérifier la sécurité
kubectl -n laravel-app describe pod <pod-name> | grep -A 10 "Security Context"

# Vérifier les probes
kubectl -n laravel-app describe pod <pod-name> | grep -A 10 "Liveness\|Readiness"

# Vérifier l'anti-affinity
kubectl -n laravel-app describe deployment laravel-app | grep -A 20 "Pod Anti-Affinity"
```

**Ce que vous expliquez :**
- "Toutes les ressources sont labellisées selon les recommandations Kubernetes"
- "Chaque conteneur a des limits et requests configurés"
- "Les conteneurs s'exécutent en non-root avec un filesystem read-only"
- "Les probes liveness/readiness assurent la santé des pods"
- "L'anti-affinity distribue les pods sur différents nodes"

### Étape 7 : Démonstration du monitoring et logging (2-3 minutes)

```bash
# Vérifier les ServiceMonitors
kubectl get servicemonitor --all-namespaces

# Vérifier les métriques Prometheus
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 &
# Ouvrir http://localhost:9090

# Vérifier les logs Loki
kubectl -n logging port-forward svc/loki 3100:3100 &
# Ouvrir http://localhost:3100
```

**Ce que vous expliquez :**
- "Tous les composants exposent des métriques Prometheus"
- "Grafana visualise les métriques avec des dashboards pré-configurés"
- "Loki collecte tous les logs de l'application et de l'infrastructure"
- "Promtail sur chaque node envoie les logs à Loki"

### Étape 8 : Démonstration de la sécurité (2-3 minutes)

```bash
# Vérifier le webhook OPA
kubectl get validatingwebhookconfigurations

# Tester une politique OPA (exemple : pod sans labels)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: nginx
    image: nginx
EOF

# Voir l'erreur de validation
kubectl describe pod test-pod
```

**Ce que vous expliquez :**
- "OPA valide toutes les créations/modifications de ressources"
- "Il vérifie les labels, les resources, la sécurité, etc."
- "Ce pod a été rejeté car il n'a pas les labels requis"

## 🎓 Points clés à mentionner

### Architecture
- "L'architecture est basée sur des microservices indépendants"
- "Chaque composant a ses propres replicas, storage et configuration"
- "L'infrastructure est gérée avec GitOps via Kustomize"

### Haute disponibilité
- "Tous les composants critiques ont au moins 2 replicas"
- "L'anti-affinity distribue les pods sur les nodes"
- "Les PodDisruptionBudgets protègent contre les disruptions planifiées"

### Scalabilité
- "L'HPA permet l'auto-scaling automatique"
- "Les resources sont bien dimensionnées avec limits et requests"
- "L'infrastructure peut scale horizontalement en ajoutant des nodes"

### Sécurité
- "OPA enforce les politiques de sécurité"
- "Les secrets ne sont jamais stockés dans les manifests"
- "Les conteneurs s'exécutent en non-root"
- "Les certificats SSL sont gérés automatiquement"

### Observabilité
- "Prometheus collecte les métriques système et applicatives"
- "Grafana fournit des dashboards de visualisation"
- "Loki centralise tous les logs"
- "Les alertes sont configurées pour les cas critiques"

### GitOps
- "Tout est versionné dans Git"
- "Kustomize gère les variations d'environnement"
- "Les déploiements sont reproductibles et auditables"

## 🔄 Nettoyage après la défense

```bash
# Nettoyer tout
./scripts/cleanup.sh
```

## 💡 Conseils pour la défense

1. **Soyez préparé** : Pratiquez le déploiement plusieurs fois avant
2. **Expliquez ce que vous faites** : Ne lancez pas juste les commandes
3. **Montrez la compréhension** : Expliquez pourquoi vous faites chaque chose
4. **Anticipez les questions** : Préparez des réponses pour les questions courantes
5. **Gérez le temps** : Ne vous attardez pas sur les détails techniques
6. **Soyez confiant** : Vous avez fait un excellent travail !

## ❓ Questions fréquentes possibles

### Q : Pourquoi nginx-ingress et pas un autre ingress controller ?
R : "Nginx-ingress est le plus populaire, bien documenté, et offre de nombreuses fonctionnalités comme le rate limiting, l'authentification, et les metrics natifs."

### Q : Pourquoi Loki et pas ELK/EFK ?
R : "Loki est plus léger, s'intègre nativement avec Prometheus et Grafana, et a un coût de stockage plus faible car il n'indexe que les métadonnées et pas le contenu complet des logs."

### Q : Pourquoi OPA et pas Kyverno ?
R : "OPA est plus flexible et permet des politiques complexes avec Rego. J'ai montré la compréhension des validating webhooks en général."

### Q : Comment gériez-vous les secrets en production ?
R : "En production, j'utiliserais une solution comme HashiCorp Vault, AWS Secrets Manager, ou Sealed Bitnami pour chiffrer les secrets dans Git."

### Q : Comment amélioriez-vous cette architecture ?
R : "J'ajouterais Network Policies, j'implémenterais des RBAC plus granulaires, j'utiliserais ArgoCD pour le GitOps continu, et j'ajouterais des tests automatisés avec Helm tests."

## 📊 Check-list pour la défense

- [ ] Cluster Kubernetes prêt
- [ ] Tous les outils installés (kubectl, helm, kustomize)
- [ ] Scripts exécutables
- [ ] Premier déploiement testé
- [ ] Documentation relue
- [ ] Réponses préparées aux questions
- [ ] Screenshots prêts (si nécessaire)
- [ ] Connexion internet stable
- [ ] Temps de préparation suffisant (au moins 15 min avant)

Bonne chance pour votre défense ! 🚀
