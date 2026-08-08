# Guide de Présentation - KubeQuest Défense

## 🎯 Plan de la Présentation (10-15 minutes)

### 1. Introduction (1-2 min)

"Bonjour, je vous présente KubeQuest, notre projet Kubernetes complet. L'objectif était de déployer un cluster Kubernetes de production avec monitoring, logging, et une application Laravel en suivant les best practices."

**Points clés** :
- 4 VMs AWS EC2
- Kubernetes v1.31 auto-géré
- Application Laravel convertie de docker-compose vers Helm
- GitOps avec Kustomize

### 2. Infrastructure (2 min)

**Afficher** : `kubectl get nodes`

"Nous avons provisionné 4 nœuds :
- node-1 : Control Plane (le cerveau du cluster)
- node-2 : Worker (exécute les applications)
- node-3 : Ingress (point d'entrée pour le trafic externe)
- node-4 : Monitoring (Prometheus, Grafana, Loki)

L'infrastructure est codée avec Terraform pour être reproductible."

### 3. Déploiement Live - PARTIE 1 (3-4 min)

**Action** : Exécuter `./deploy-all.sh`

"Maintenant je vais déployer toute l'infrastructure et les applications :

```bash
./deploy-all.sh
```

Ce script :
1. Déploie nginx-ingress controller (LoadBalancer)
2. Déploie kube-prometheus stack (monitoring)
3. Déploie Loki (logging)
4. Déploie l'application Laravel avec Helm
5. Déploie Kubernetes Dashboard

Pendant l'exécution, expliquer :
- "nginx-ingress va recevoir le trafic externe"
- "kube-prometheus va collecter toutes les métriques"
- "Laravel app est déployée avec 3 replicas par défaut"

### 4. Vérification (1-2 min)

**Afficher** :
```bash
kubectl get pods -A
kubectl get ingress -A
```

"On voit que tous les pods sont Ready :
- ingress-nginx controller tourne sur node-3
- laravel-app a 3 replicas répartis sur node-2
- prometheus et grafana sont sur node-4"

### 5. Démo Auto-scaling (2-3 min)

**Action** : Exécuter `./load-test.sh`

"Je vais maintenant lancer un test de charge pour démontrer l'auto-scaling :

```bash
./load-test.sh
```

Ce script envoie 400 requêtes/seconde sur l'application.

**Pendant l'exécution** :
- Regardez, le nombre de pods augmente automatiquement (3 → 5 → 7...)
- C'est grâce à l'Horizontal Pod Autoscaler configuré à 70% CPU
- Quand la charge augmente, Kubernetes crée automatiquement plus de replicas

**Après le test** :
"Les pods vont redescendre automatiquement après la cool-down period (5-10 min)."

### 6. Démo Rollback (2-3 min)

**Action** : Exécuter `./rollback-demo.sh`

"Je vais maintenant montrer la gestion des deployments et le rollback :

```bash
./rollback-demo.sh
```

Ce script :
1. Déploie une version 'cassée' de l'application
2. Montre que l'application ne répond plus correctement
3. Fait un rollback instantané vers la version stable
4. Montre que l'application fonctionne à nouveau

**Pendant l'exécution** :
- "On déploie une version avec nginx au lieu de Laravel"
- "L'application ne répond plus comme attendu"
- "Avec Helm, on peut faire un rollback en une commande"
- "Le rollback est instantané, zéro-downtime"

### 7. Monitoring et Logging (1-2 min)

**Afficher Grafana** :

"Pour le monitoring, nous avons Grafana avec des dashboards pré-configurés :
- Métriques CPU/Mémoire par pod
- Réseau et I/O
- Performances de l'application

Tout est automatiquement collecté par Prometheus."

**Afficher Loki** :

"Pour les logs, Loki centralise tout :
- On peut filtrer par namespace, pod, conteneur
- Recherche full-text dans les logs
- Intégré directement dans Grafana"

### 8. GitOps (1-2 min)

**Afficher la structure** :

```bash
ls kubequest-cluster/gitops/
cat kubequest-cluster/gitops/infrastructure/base/kustomization.yaml
```

"Toute notre configuration est stockée dans Git (GitOps).

On peut déployer tout le cluster avec :

```bash
./apply-gitops.sh
```

Cela utilise Kustomize pour appliquer tous les manifests."

### 9. Best Practices (1 min)

"Nous avons appliqué toutes les best practices Kubernetes :

1. **Resources limits/requests** : Chaque container a des limits CPU/ mémoire
2. **3 replicas** : Redondance pour la haute disponibilité
3. **Pod anti-affinity** : Les pods sont répartis sur différents nœuds
4. **Auto-scaling** : HPA qui scale automatiquement de 3 à 10 replicas
5. **Health checks** : Liveness et readiness probes
6. **Persistent storage** : PVC pour la base de données
7. **Backup automatisé** : CronJob qui backup tous les jours à 2h
8. **Secrets** : Données sensibles dans des Secrets Kubernetes
9. **Labels standards** : Toutes les resources sont labelisées
10. **Security context** : Containers non-root, drop capabilities"

### 10. Conclusion (1 min)

"Pour conclure, nous avons :

✅ Un cluster Kubernetes complet et fonctionnel
✅ Toute la stack de monitoring et logging
✅ Une application déployée avec Helm
✅ GitOps avec Kustomize
✅ Auto-scaling fonctionnel
✅ Zero-downtime avec rollback
✅ Toutes les best practices Kubernetes

Le projet est prêt pour la production."

---

## 🎯 Questions Probables et Réponses

### Q1 : "Pourquoi nginx-ingress et pas un autre Ingress ?"

**R** : "nginx-ingress est le plus mature, bien documenté, et recommandé par Kubernetes. Il supporte toutes les features dont on a besoin : SSL passthrough, rate limiting, circuit breaking. De plus, il est facile à déployer avec Helm."

### Q2 : "Comment gère-vous la sécurité ?"

**R** : "Plusieurs couches :
1. Security Groups AWS qui limitent les ports ouverts
2. RBAC Kubernetes avec ServiceAccounts dédiés
3. Secrets pour les données sensibles
4. Security context : containers non-root, drop capabilities
5. Network Policies (si implémenté) pour limiter le trafic entre pods"

### Q3 : "Pourquoi 3 replicas minimum ?"

**R** : "Pour la haute disponibilité. Avec 3 replicas :
- On peut perdre 1 pod sans impact
- Pod anti-affinity les répartit sur 3 nœuds différents
- Si un nœud tombe, l'application continue sur les 2 autres"

### Q4 : "Comment fonctionne l'auto-scaling ?"

**R** : "L'HPA surveille les métriques CPU/mémoire des pods via Metrics Server. Quand les pods dépassent 70% CPU, l'HPA crée automatiquement des replicas jusqu'à 10. Quand la charge redescend, il supprime les replicas en excès après une cool-down period."

### Q5 : "Pourquoi GitOps ?"

**R** : "GitOps apporte :
1. **Traçabilité** : Toute modification est dans Git
2. **Reproductibilité** : On peut recréer le cluster à l'identique
3. **Rollback** : On peut revenir à une version précédente du Git
4. **Collaboration** : Plusieurs personnes peuvent travailler sur la config
5. **Audit** : On sait qui a modifié quoi et quand"

### Q6 : "Comment gère-vous les mises à jour ?"

**R** : "Avec Helm :
1. `helm upgrade` pour déployer une nouvelle version
2. Si échec, `helm rollback` pour revenir instantanément
3. Les stratégies de déploiement (RollingUpdate) assurent zéro-downtime
4. On peut faire des canary deploys en changeant progressivement les replicas"

### Q7 : "Pourquoi Loki et pas ELK ?"

**R** : "Loki est plus léger et adapté à Kubernetes :
- Indexe seulement les labels, pas le contenu des logs
- Coût de stockage réduit
- Intégration native avec Grafana
- Promtail comme agent sur chaque nœud"

### Q8 : "Comment surveillez-vous la santé du cluster ?"

**R** : "Plusieurs niveaux :
1. **Prometheus** collecte les métriques de tous les composants
2. **Grafana** visualise avec des dashboards
3. **Alertmanager** (configuré) peut envoyer des alertes
4. **Liveness/readiness probes** vérifient les pods
5. **Kubernetes Dashboard** pour l'interface web"

### Q9 : "Quelle aurait été la prochaine étape ?"

**R** : "Si on avait plus de temps :
1. **cert-manager** pour Let's Encrypt (SSL automatique)
2. **ArgoCD** pour le GitOps automatisé (sync continu depuis Git)
3. **OPA/Gatekeeper** pour des policies de validation
4. **Trivy scanner** pour vérifier la sécurité des images
5. **Backup S3** pour stocker les backups sur AWS"

### Q10 : "Le LoadBalancer est pending, pourquoi ?"

**R** : "On est sur des VMs EC2 auto-gérées, pas sur EKS (le service managé AWS). Du coup, pas de provisionneur LoadBalancer AWS automatique. On utilise NodePort à la place (port 32222). Si on était sur EKS, le LoadBalancer serait créé automatiquement par AWS."

---

## 🛠️ Commandes à Avoir Sous la Main

### Pendant la présentation

```bash
# Voir les nœuds
kubectl get nodes -L node-role.kubernetes.io/ingress,node-role.kubernetes.io/monitoring

# Voir tous les pods
kubectl get pods -A

# Voir l'Ingress
kubectl get ingress -A

# Voir l'HPA
kubectl get hpa -A

# Voir les services
kubectl get svc -A

# Logs en temps réel
kubectl logs -n laravel -l app.kubernetes.io/name=laravel-app -f

# Entrer dans un pod
kubectl exec -it -n laravel <pod-name> -- sh

# Tester l'application
curl http://app.kubequest.local:32222
curl -H "Host: app.kubequest.local" http://3.77.235.74:32222
```

### En cas de problème

```bash
# Restart un pod
kubectl delete pod -n laravel <pod-name>

# Restart tout
kubectl rollout restart deployment -n laravel laravel-app

# Voir les events
kubectl describe pod -n laravel <pod-name>
kubectl get events -A --sort-by='.lastTimestamp'

# Check resources
kubectl top nodes
kubectl top pods -A
```

---

## 📊 Démo Order Checklist

**Avant la présentation** :
- [ ] Vérifier que tous les nœuds sont Ready
- [ ] Vérifier que les scripts sont exécutables (`chmod +x *.sh`)
- [ ] Avoir le token du Dashboard prêt
- [ ] Avoir le password Grafana prêt
- [ ] Avoir `/etc/hosts` configuré

**Pendant la présentation** :
1. [ ] Intro rapide
2. [ ] `./deploy-all.sh` (attendre qu'il finisse)
3. [ ] Vérifier les pods (`kubectl get pods -A`)
4. [ ] `./load-test.sh` (montrer auto-scaling)
5. [ ] `./rollback-demo.sh` (montrer rollback)
6. [ ] Afficher Grafana (dashboard)
7. [ ] Montrer GitOps (`ls kubequest-cluster/gitops/`)
8. [ ] Conclusion

**Après la présentation** :
- [ ] Prévenir les scripts nettoyage (s'il y en a)

---

## 💡 Astuces pour la Présentation

### Avant de commencer
1. **Testez tous les scripts** la veille
2. **Ayez un backup** de votre cluster (screenshot de l'état)
3. **Préparez un cheat sheet** avec les commandes importantes

### Pendant la présentation
1. **Parlez lentement** et clairement
2. **Montrez, ne dites pas juste** - les démos live sont impressionnantes
3. **Anticipez les erreurs** - si un script échoue, continuez avec autre chose
4. **Regardez l'audience** - pas juste l'écran
5. **Soyez honnête** - si vous ne savez pas, dites-le

### Si quelque chose échoue
1. **Ne paniquez pas**
2. **Continuez avec autre chose** - montrez que vous connaissez le sujet
3. **Diagnostiquez** - montrez que vous savez troubleshooter
4. **Soyez transparent** - "Ah, ce script a un bug, mais je peux vous montrer manuellement..."

---

## 🎯 Ce Que les Jurys Voulent Voir

1. **Que vous comprenez Kubernetes** - Expliquez les concepts
2. **Que vous avez des best practices** - Parlez-en explicitement
3. **Que vous savez troubleshooter** - Si un problème arrive
4. **Que vous avez pensé production** - Monitoring, backup, sécurité
5. **Que vous savez utiliser les outils** - Helm, Kustomize, kubectl

---

## 📝 Entraînement

**Entraînez-vous à dire** :
- "Helm" pas "Helme"
- "Kubernetes" pas "Kubernetes" (le "K" sonne comme "C")
- "Ingress" pas "Ingresse"
- "Pod" comme en anglais, pas "Pod" français
- "Replicas" avec un "s" même en français

**Entraînez-vous à** :
- Faire les démos en moins de 5 minutes
- Répondre aux questions sans hésiter
- Trouver les infos dans kubectl rapidement

---

**Bonne chance ! Vous êtes prêts !** 🚀
