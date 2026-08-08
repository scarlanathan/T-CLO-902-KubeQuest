# 📋 Compte rendu — Projet KubeQuest (Groupe 50)

> Document de synthèse : **ce qui a été fait, comment, et comment ça marche.**
> Projet Epitech MSc Pro Promo 2026 — déploiement d'une application Laravel sur un cluster Kubernetes AWS.

---

## 1. Vue d'ensemble

**Objectif :** migrer une application **Laravel** (initialement en `docker-compose`) vers un **cluster Kubernetes multi-nœuds sur AWS**, avec toute la chaîne « production-ready » : load balancing, monitoring, logging, GitOps, autoscaling, sauvegardes, sécurité (OPA, RBAC, TLS) et un scénario de démo pour la défense.

Le travail est organisé en **6 grands chantiers (Epics Jira KUB-1 → KUB-6)**, détaillés ci-dessous.

---

## 2. Infrastructure AWS — *« le socle »* (Epic KUB-1)

### Ce qui a été fait
Provisionnement de **4 VMs EC2** (Amazon Linux 2023, ARM64) formant le cluster :

| Nœud | Rôle K8s | Fonction |
|------|----------|----------|
| node-1 | Control Plane + Worker | cerveau du cluster (API server, etcd, scheduler) |
| node-2 | Worker | exécute l'app Laravel + base de données |
| node-3 | Ingress | point d'entrée du trafic externe |
| node-4 | Monitoring | Prometheus / Grafana / Loki |

### Comment c'est fait
Tout est en **Infrastructure as Code avec Terraform** (`terraform/main.tf`, ~580 lignes) :
- un **VPC** dédié + Internet Gateway + subnet public + route table ;
- **3 Security Groups** (`kubernetes_nodes`, `ingress`, `monitoring`) jouant le rôle de pare-feu : SSH (22), API K8s (6443), kubelet (10250), NodePorts (32222/32214), etc. ;
- les **4 instances EC2** (`kube_1`, `kube_2`, `ingress`, `monitoring`), chacune avec un `user_data` qui pré-installe les prérequis Kubernetes au démarrage ;
- des **outputs** renvoyant les IPs publiques/privées et un exemple de commande SSH.

La clé SSH est récupérée depuis **AWS SSM Parameter Store** (pas de secret en clair).

### Comment ça marche
`terraform apply` → AWS crée le réseau + les 4 VMs → le cluster Kubernetes (v1.31, runtime **containerd**, réseau **Calico**) est installé dessus. L'exposition externe se fait via **nginx-ingress** sur node-3 (KUB-9).

---

## 3. Application Laravel + Base de données — *« le métier »* (Epic KUB-4)

### Ce qui a été fait
L'app `docker-compose` a été convertie en **Helm Chart complet** (`kubequest-cluster/laravel-app/`), et la base de données est fournie par un **chart Helm officiel**.

### Comment c'est fait
Le chart contient tous les objets Kubernetes en templates :
- `deployment.yaml`, `service.yaml`, `ingress.yaml`, `configmap.yaml`, `secret.yaml`
- `hpa.yaml` (autoscaling), `pdb.yaml` (disponibilité), `pvc.yaml` (stockage), `serviceaccount.yaml`
- `backup-cronjob.yaml`, `servicemonitor.yaml`, `httproute.yaml` (Gateway API), tests Helm

La **base de données** est intégrée comme **dépendance Bitnami PostgreSQL** dans `Chart.yaml` (persistance, auth via Secret, metrics activées).

> ⚠️ **Incohérence à corriger :** le `README.md` mentionne MySQL, mais le chart livré utilise **PostgreSQL Bitnami**. À harmoniser avant la défense.

### Comment ça marche
`helm install laravel-app ./kubequest-cluster/laravel-app` déploie d'un coup l'app **et** sa base, lit la config depuis `values.yaml`, et Helm gère l'upgrade/rollback par versions.

---

## 4. Bonnes pratiques Kubernetes (Epic KUB-5)

Tout est paramétré dans `values.yaml` :

| Pratique | Mise en œuvre | Ticket |
|----------|---------------|--------|
| **Resources** | `requests` 250m/256Mi, `limits` 500m/512Mi par conteneur | KUB-19 |
| **Redondance** | `replicaCount: 3` | KUB-21 |
| **Anti-affinité** | replicas répartis sur des nœuds différents (`podAntiAffinity` + `nodeAffinity` workers) | KUB-21 |
| **Persistance** | PVC 10Gi + CronJob de **backup quotidien** (`0 2 * * *`, rétention 30j) | KUB-21 |
| **Autoscaling** | HPA : min 3 / max 10 pods, seuils CPU 70 % / RAM 80 % | KUB-5 |
| **Probes** | liveness `/api/health`, readiness `/api/ready` | KUB-5 |
| **Secrets** | données sensibles (appKey, mots de passe DB/Redis/mail) via `Secret` K8s | KUB-20 |
| **Security context** | `runAsNonRoot`, `readOnlyRootFilesystem`, drop de toutes les capabilities | KUB-5 |

**Concrètement :** quand la charge CPU monte, l'HPA crée de nouveaux pods (3→10), que le scheduler place sur des nœuds différents grâce à l'anti-affinité ; les données de la DB survivent aux redémarrages grâce au PVC, et sont sauvegardées chaque nuit.

---

## 5. Observabilité (Epic KUB-2)

### Monitoring (KUB-11)
- **Stack `kube-prometheus`** (Prometheus + Alertmanager + Grafana) déployée via Helm dans le namespace `monitoring`, épinglée sur node-4.
- `values.yaml` : Prometheus en **2 replicas**, rétention 30j / 20Gi, Alertmanager en **3 replicas**, anti-affinité partout.
- Des `ServiceMonitor` font remonter les métriques de l'app Laravel.

### Logging (KUB-12)
- **Loki + Promtail** : Promtail collecte les logs de tous les pods, Loki les indexe (persistance 20Gi, rétention 168h), Grafana sert d'interface de recherche.
- Exemple de requête : `{namespace="laravel",app="laravel-app"}`

### Dashboard (KUB-10)
- **Kubernetes Dashboard v2.7.0** + un `admin-user` (ServiceAccount + ClusterRoleBinding `cluster-admin` + token), accessible via Ingress.

**Comment ça marche :** Prometheus *scrape* les métriques → Grafana les affiche ; Promtail pousse les logs → Loki → Grafana. Une seule UI (Grafana) pour métriques **et** logs.

---

## 6. GitOps (Epic KUB-3)

### Ce qui a été fait
Toute la configuration est versionnée dans Git et appliquée de façon déclarative avec **Kustomize**, séparée en deux domaines :

```
gitops/
├── infrastructure/base/   → nginx-ingress, cert-manager, monitoring,
│                            logging, kubernetes-dashboard, security (OPA)
└── apps/laravel-app/
    ├── base/              → config commune
    └── overlays/production/ → surcharges spécifiques prod (patch)
```

### Comment ça marche
On modifie un fichier dans `gitops/`, on commit/push, puis `./apply-gitops.sh` applique l'état désiré via `kubectl apply -k` (Kustomize). Les overlays permettent d'avoir une **base commune** et des **variantes par environnement** sans duplication.

> ⚠️ **KUB-15 (bonus) :** l'automatisation par **scripts Kustomize** est faite, mais **ArgoCD** (GitOps pull-based) n'est pas mis en place → seul ticket laissé « À faire ».

---

## 7. Sécurité & défense (Epic KUB-6)

### Validating Webhook OPA (KUB-22)
Un **Open Policy Agent (OPA 0.62)** est déployé (namespace `opa` : Deployment, Service, RBAC, ConfigMap, `ValidatingWebhookConfiguration`). Les politiques **Rego** (`configmap.yaml`) **refusent l'admission** de ressources non conformes :
- conteneur sans `resources` (limits/requests) → rejeté ;
- pod sans label `app.kubernetes.io/name` → rejeté ;
- conteneur tournant en `runAsUser: 0` (root) → rejeté ;
- Deployment avec `< 2 replicas` → rejeté ;
- Service sans `selector` → rejeté.

**Comment ça marche :** à chaque `kubectl apply`, l'API server appelle le webhook OPA, qui évalue les règles Rego et **bloque** ce qui ne respecte pas les bonnes pratiques.

### Authentification & TLS (KUB-23)
- **cert-manager** + `ClusterIssuer` Let's Encrypt → certificats **TLS automatiques** sur les Ingress (`letsencrypt-prod`).
- **RBAC** : ServiceAccounts + ClusterRoleBindings dédiés (app, dashboard).

> ⚠️ **À nuancer :** l'énoncé demandait **dex + oauth-proxy** + test de 2 profils (read-only/admin), non implémentés. Le projet couvre l'auth par tokens/RBAC/TLS mais pas l'OIDC complet.

### Scénario de défense / démo live (KUB-24)
Scripts prêts pour la soutenance :
- **`load-test.sh`** → envoie ~400 req/s, on **voit les pods passer de 3 à 10** (démo autoscaling).
- **`rollback-demo.sh`** → déploie une version « cassée » (nginx au lieu de Laravel), montre la panne, puis **rollback zéro-downtime** vers la version stable.
- `test-complet-cluster.sh`, `health-check.sh`, guides (`PRESENTATION_GUIDE.md`, `GUIDE_DEPLOIEMENT_RAPIDE.md`).

---

## 8. Les deux façons de tout déployer

| Méthode | Commande | Principe |
|---------|----------|----------|
| **Helm** (impératif) | `./deploy-all.sh` | vérifie les prérequis → nginx-ingress → kube-prometheus → Loki → app Laravel → Dashboard → vérifie l'état → affiche les accès |
| **GitOps** (déclaratif) | `./apply-gitops.sh` | applique l'état Git via Kustomize |

`deploy-all.sh` est idempotent : il détecte si un composant est déjà présent et fait un `helm upgrade` au lieu d'un `install`, et utilise `kubectl wait` pour attendre que l'ingress soit prêt avant de continuer.

---

## 9. Accès aux services (après déploiement)

- **Laravel** : `http://app.kubequest.local:32222` (NodePort)
- **Dashboard** : `http://dashboard.kubequest.local:32222` (token via `kubectl get secret admin-user-token`)
- **Grafana** : `http://<ip-node4>:3000` (password dans le secret `kube-prometheus-grafana`)

> ℹ️ Le LoadBalancer reste « pending » sur des EC2 auto-gérées (pas de cloud-controller) → on passe par les **NodePorts** (32222/32214), documenté dans le troubleshooting du README.

---

## 10. Bilan & points de vigilance

### ✅ Couvert et solide
Infra Terraform · chart Helm complet · observabilité (Prometheus/Grafana/Loki) · GitOps Kustomize · autoscaling HPA · anti-affinité · backups · OPA admission control · TLS cert-manager.

### ⚠️ Points de vigilance pour la défense
1. **KUB-15** — ArgoCD non fait (scripts seulement) — *encore « À faire ».*
2. **KUB-23** — auth via RBAC/TLS, **mais pas dex/oauth-proxy** comme demandé par l'énoncé.
3. **Incohérence MySQL vs PostgreSQL** : le README dit MySQL, le chart livre PostgreSQL Bitnami → à uniformiser.
4. Les tickets « tester de bout en bout sur cluster réel » (KUB-21 / KUB-24) ont tout le **matériel** prêt, mais la preuve d'exécution dépend du cluster live.

---

## Annexe — Correspondance Jira (projet KUB / KubeQuest)

| Ticket | Tâche | État |
|--------|-------|------|
| KUB-1 → KUB-6 | Epics (cluster, observabilité, GitOps, migration, best practices, sécurité) | ✅ Terminé |
| KUB-7 | Provisionner les VM AWS (Terraform) | ✅ Terminé |
| KUB-8 | Installer/configurer le cluster | ✅ Terminé |
| KUB-9 | Nœud Ingress (exposition externe) | ✅ Terminé |
| KUB-10 | Dashboard Kubernetes sécurisé | ✅ Terminé |
| KUB-11 | Monitoring kube-prometheus | ✅ Terminé |
| KUB-12 | Stack de logs Loki | ✅ Terminé |
| KUB-13 | Dépôt GitOps infrastructure | ✅ Terminé |
| KUB-14 | Dépôt GitOps application | ✅ Terminé |
| KUB-15 | Automatiser déploiements (ArgoCD, bonus) | ⏳ À faire (scripts OK, ArgoCD non) |
| KUB-16 | Chart Helm application | ✅ Terminé |
| KUB-17 | BDD via chart Helm officiel (PostgreSQL Bitnami) | ✅ Terminé |
| KUB-18 | Automatiser déploiement + vérification app | ✅ Terminé |
| KUB-19 | Limites & requests de ressources | ✅ Terminé |
| KUB-20 | Secrets (données sensibles) | ✅ Terminé |
| KUB-21 | Redondance, affinités, persistance | ✅ Terminé |
| KUB-22 | Validating Webhook OPA | ✅ Terminé |
| KUB-23 | Authentification API K8s & outils | ✅ Terminé (RBAC/TLS ; dex/oauth-proxy non fait) |
| KUB-24 | Scénario de défense (démo live) | ✅ Terminé |

---

*Équipe : Groupe 50 — Epitech MSc Pro Promo 2026.*


 la façon dont les vulnérabilités ont été trouvées. La démarche n'était pas une simple relecture « à l'œil », mais un audit structuré en 3 temps :

Temps 1 — Audit multi-axes (7 angles d'attaque en parallèle)

Le code a été passé au crible selon 7 lentilles distinctes, chacune cherchant un type de faille précis :

1. Secrets — identifiants/clés en clair dans le dépôt
2. Divulgation / debug — mode debug, messages d'erreur exposant des infos
3. Injection / flux de données — SQL injection, mass-assignment, désérialisation
4. Contrôle d'accès / CSRF / CORS — endpoints non authentifiés, politiques permissives
5. XSS — encodage des sorties HTML
6. Durcissement conteneur — Dockerfile (root, deps de dev, image de base)
7. CVE des dépendances — versions vulnérables de librairies

Temps 2 — Vérification contradictoire (réfuter chaque trouvaille)

Chaque constat candidat est réexaminé par un second analyste dont le but est de le démolir : est-ce réellement exploitable dans CE contexte ? La sévérité est-elle juste ? Est-ce un faux positif déjà mitigé par un défaut de Laravel ? → Ce filtre élimine les fausses alertes.

C'est ce qui a permis, par exemple, de rétrograder l'APP_KEY de « Critical » à « Medium », et d'écarter 3 CVE souvent cités (CVE-2023-3824/3823, CVE-2021-3129, CVE-2018-15133) parce qu'ils ne s'appliquaient pas à la version réellement utilisée.

Temps 3 — Vérification en ligne des CVE (sources officielles)

Pour chaque CVE cité, vérification sur NVD (NIST) et les GitHub Security Advisories : versions affectées, version corrigée, score CVSS. Aucun numéro de CVE inventé. C'est cette étape qui a rattrapé une erreur du premier audit (mauvaise version corrigée de PHP).

Le bilan chiffré de cet entonnoir

37 constats candidats → 23 confirmés → 18 problèmes distincts (après dédoublonnage), 14 pistes écartées (faux positifs ou déjà corrigés).

Répartition finale : 1 High, 6 Medium, 9 Low, 2 Info.

---
En une phrase pour la soutenance : « On a cherché selon 7 axes en parallèle, puis chaque trouvaille a dû survivre à une contre-analyse qui essayait de la réfuter, et enfin chaque CVE a été vérifié sur NVD — la rigueur avant la peur. »

Le périmètre couvert : l'appli PHP/Laravel (app-master/), sa chaîne de déploiement (Dockerfile, docker-compose, manifestes Helm/K8s) et le durcissement du cluster live.

Veux-tu que je détaille aussi comment chaque faille marquante a été concrètement repérée dans le code (fichier + ligne), ou plutôt le lien avec les corrections apportées ?