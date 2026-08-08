# 🎤 Questions / Réponses — Préparation à la soutenance orale

> Projet **KubeQuest** (Groupe 50) — Epitech MSc Pro Promo 2026.
> Banque de questions susceptibles d'être posées par le jury : *à quoi ça sert* et *comment ça marche*.
> Réponses synthétiques pour réviser, suivies des **questions pièges** les plus fréquentes.

---

## A. Questions générales sur le projet

### Q1 — En une phrase, c'est quoi votre projet ?
On a migré une application **Laravel** qui tournait en `docker-compose` vers un **cluster Kubernetes multi-nœuds sur AWS**, avec toute la chaîne production : load balancing, monitoring, logging, GitOps, autoscaling, sauvegardes et sécurité.

### Q2 — Pourquoi passer de docker-compose à Kubernetes ? À quoi ça sert ?
`docker-compose` tourne sur **une seule machine** et ne sait pas gérer la panne d'un serveur, la montée en charge, ni l'auto-réparation. Kubernetes apporte :
- **Haute disponibilité** : plusieurs replicas répartis sur plusieurs nœuds ;
- **Auto-scaling** : on ajoute/retire des pods automatiquement selon la charge ;
- **Auto-réparation** : un pod qui meurt est recréé automatiquement ;
- **Déploiements sans coupure** (rolling update + rollback) ;
- **Standardisation** : monitoring, secrets, réseau, tout est déclaratif.

### Q3 — Quelle est l'architecture globale ?
4 VMs EC2 sur AWS :
- **node-1** : control plane + worker (cerveau du cluster) ;
- **node-2** : worker (app Laravel + base de données) ;
- **node-3** : ingress (point d'entrée du trafic) ;
- **node-4** : monitoring (Prometheus/Grafana/Loki).
Kubernetes v1.31, runtime **containerd**, réseau **Calico (CNI)**, **nginx-ingress** comme load balancer.

### Q4 — Comment on déploie tout ?
Deux méthodes :
1. **Helm** (impératif) : `./deploy-all.sh` installe tout dans l'ordre (ingress → monitoring → logging → app → dashboard).
2. **GitOps** (déclaratif) : `./apply-gitops.sh` applique l'état décrit dans Git via Kustomize.

---

## B. Infrastructure & Terraform

### Q5 — À quoi sert Terraform dans le projet ?
Terraform fait de **l'Infrastructure as Code** : au lieu de créer les serveurs AWS à la main dans la console, on les décrit dans un fichier (`terraform/main.tf`). Avantages : reproductible, versionné dans Git, et destructible/recréable en une commande.

### Q6 — Que crée concrètement votre code Terraform ?
Un **VPC** + Internet Gateway + subnet public + route table, **3 Security Groups** (pare-feu), et les **4 instances EC2**. En sortie (`outputs`), il donne les IPs et la commande SSH.

### Q7 — Comment gérez-vous la clé SSH / les secrets dans Terraform ?
La clé SSH est récupérée depuis **AWS SSM Parameter Store**, pas écrite en clair dans le code. Les credentials AWS passent par des variables (`terraform.tfvars`, non commité).

### Q8 — C'est quoi un Security Group et pourquoi 3 différents ?
Un Security Group est un **pare-feu au niveau de la VM**. On en a 3 car chaque type de nœud a des besoins différents : les nœuds K8s ouvrent l'API (6443) et le kubelet (10250), l'ingress ouvre les NodePorts (32222/32214), le monitoring ouvre Grafana (3000). Principe du **moindre privilège**.

---

## C. Kubernetes — concepts de base (souvent demandés)

### Q9 — C'est quoi la différence entre un Pod, un Deployment et un Service ?
- **Pod** : la plus petite unité, un ou plusieurs conteneurs qui tournent ensemble.
- **Deployment** : gère un ensemble de pods identiques (replicas), les recrée s'ils meurent, gère les mises à jour progressives.
- **Service** : une adresse réseau stable qui répartit le trafic vers les pods (les pods changent d'IP, pas le service).

### Q10 — C'est quoi un Ingress et en quoi c'est différent d'un Service ?
Le **Service** expose à l'intérieur du cluster. L'**Ingress** est la porte d'entrée HTTP/HTTPS **depuis l'extérieur** : il route selon le nom de domaine et l'URL (`app.kubequest.local` → service Laravel) et gère le TLS. Chez nous c'est **nginx-ingress** sur node-3.

### Q11 — C'est quoi un namespace ?
Un **espace de noms logique** pour isoler les ressources. On a `laravel`, `monitoring`, `ingress-nginx`, `kubernetes-dashboard`, `opa`… Ça évite les collisions et permet d'appliquer des règles par namespace.

### Q12 — Control plane vs worker, c'est quoi la différence ?
Le **control plane** (node-1) prend les décisions : API server, scheduler, etcd (base de données du cluster). Les **workers** (node-2, etc.) exécutent réellement les pods.

---

## D. Application Laravel & Helm

### Q13 — À quoi sert Helm ? Pourquoi pas juste des fichiers YAML ?
Helm est le **gestionnaire de paquets de Kubernetes**. Au lieu de gérer des dizaines de YAML séparés, on a un **chart** paramétrable par un seul `values.yaml`. Avantages : réutilisable, versionné, et `helm rollback` permet de revenir à une version précédente en une commande.

### Q14 — Comment la base de données est-elle gérée ?
Via une **dépendance Helm officielle Bitnami PostgreSQL** déclarée dans `Chart.yaml`. Elle a sa propre persistance (PVC), ses identifiants dans un Secret, et expose des métriques. *(Attention : le README parle encore de MySQL, à corriger.)*

### Q15 — Que se passe-t-il quand vous lancez `helm install` ?
Helm prend les templates + les valeurs de `values.yaml`, génère les manifests Kubernetes finaux, et les applique au cluster : Deployment de l'app + PostgreSQL + Service + Ingress + Secrets + HPA, etc., d'un seul coup.

### Q16 — Comment l'app trouve sa base de données ?
Par le **nom DNS du Service** PostgreSQL à l'intérieur du cluster (Kubernetes a un DNS interne, CoreDNS). Les identifiants sont injectés depuis un **Secret** en variables d'environnement.

---

## E. Bonnes pratiques Kubernetes

### Q17 — C'est quoi `requests` et `limits` ? Pourquoi c'est important ?
- **requests** : ce que le pod est *garanti* d'avoir (utilisé par le scheduler pour le placer).
- **limits** : le *maximum* qu'il peut consommer (au-delà, il est throttlé ou tué).
Ça empêche qu'un pod gourmand affame les autres. Chez nous : requests 250m/256Mi, limits 500m/512Mi.

### Q18 — C'est quoi l'auto-scaling (HPA) et comment ça marche ?
Le **Horizontal Pod Autoscaler** surveille la charge CPU/RAM via le metrics-server. Si le CPU moyen dépasse **70 %**, il **ajoute des pods** (de 3 jusqu'à 10) ; quand la charge baisse, il en retire. C'est la démo `load-test.sh`.

### Q19 — C'est quoi l'anti-affinité ? À quoi ça sert ?
La **pod anti-affinity** demande au scheduler de **ne pas mettre deux replicas sur le même nœud**. Comme ça, si un nœud tombe, il reste des pods ailleurs → haute disponibilité.

### Q20 — Comment garantissez-vous la disponibilité de l'app ?
Plusieurs mécanismes combinés : **3 replicas** + **anti-affinité** (répartition) + **probes** (readiness/liveness) + **PodDisruptionBudget** (PDB, empêche de tuer trop de pods en même temps) + **rolling updates**.

### Q21 — C'est quoi les probes liveness et readiness ?
- **liveness** (`/api/health`) : « le pod est-il vivant ? » Sinon Kubernetes le redémarre.
- **readiness** (`/api/ready`) : « le pod peut-il recevoir du trafic ? » Sinon il est retiré du load balancing (mais pas tué).

### Q22 — Comment gérez-vous la persistance des données ?
Avec un **PersistentVolumeClaim (PVC)** : un volume de stockage qui **survit au redémarrage/recréation** du pod. La base de données écrit dessus, donc les données ne sont jamais perdues. En plus, un **CronJob de backup quotidien** (2h du matin, rétention 30j).

---

## F. Sécurité

### Q23 — Comment gérez-vous les données sensibles (mots de passe) ?
Via des **Secrets Kubernetes** (appKey, mots de passe DB/Redis/mail), jamais en clair dans les manifests ni commités dans Git. Ils sont injectés dans les pods en variables d'environnement.

### Q24 — C'est quoi OPA et à quoi ça sert dans votre projet ?
**OPA (Open Policy Agent)** est un moteur de politiques. On l'a branché comme **Validating Admission Webhook** : à chaque création de ressource, l'API server demande à OPA si elle est conforme. Nos règles **Rego** refusent par exemple :
- un pod **sans limites de ressources** ;
- un pod **sans label** `app.kubernetes.io/name` ;
- un conteneur qui tourne **en root** ;
- un Deployment avec **moins de 2 replicas** ;
- un Service **sans selector**.
→ C'est de la **sécurité préventive / gouvernance** : on impose les bonnes pratiques automatiquement.

### Q25 — Comment fonctionne l'authentification / TLS ?
- **cert-manager** + un `ClusterIssuer` **Let's Encrypt** génèrent et renouvellent automatiquement les **certificats TLS** sur les Ingress (HTTPS).
- **RBAC** : des ServiceAccounts et ClusterRoleBindings dédiés limitent qui peut faire quoi.
- Le Dashboard utilise un **token** lié à un ServiceAccount.

### Q26 — C'est quoi le RBAC ?
**Role-Based Access Control** : on définit des **rôles** (ensembles de permissions) et on les **lie** à des utilisateurs/ServiceAccounts. Ça applique le moindre privilège : chaque composant n'a que les droits dont il a besoin.

---

## G. GitOps & Observabilité

### Q27 — C'est quoi le GitOps et pourquoi c'est utile ?
Le principe : **Git est la source unique de vérité**. Toute la configuration du cluster est dans un dépôt ; pour changer quelque chose, on modifie un fichier, on commit, et on applique. Avantages : **traçabilité** (chaque changement = un commit), **rollback** (revenir à un commit), **revue de code** sur l'infra.

### Q28 — C'est quoi Kustomize et pourquoi pas juste copier les YAML ?
Kustomize permet d'avoir une **base commune** et des **overlays** par environnement (ex : `production`) qui **patchent** la base, sans dupliquer les fichiers. On change juste ce qui diffère (nombre de replicas, ressources…).

### Q29 — À quoi servent Prometheus, Grafana et Loki ?
- **Prometheus** : collecte les **métriques** (CPU, RAM, requêtes…) en *scrapant* les pods.
- **Grafana** : **affiche** ces métriques sous forme de dashboards (et les logs aussi).
- **Loki** : centralise les **logs** de tous les pods (Promtail les collecte). 
En clair : Prometheus = chiffres, Loki = logs, Grafana = l'écran unique pour tout voir.

### Q30 — Comment vous savez si l'app va mal ?
Grafana affiche les métriques, **Alertmanager** (dans la stack kube-prometheus) peut envoyer des alertes, et Loki permet de chercher les erreurs dans les logs (`{namespace="laravel"}`).

---

## H. Démo de défense

### Q31 — Comment démontrez-vous l'auto-scaling en live ?
On lance `./load-test.sh` qui envoie ~400 requêtes/seconde. On regarde `kubectl get hpa` et `kubectl get pods` : on **voit les pods passer de 3 à 10** au fur et à mesure que le CPU monte, puis redescendre.

### Q32 — Comment démontrez-vous le rollback ?
`./rollback-demo.sh` : on déploie volontairement une **version cassée** (nginx au lieu de Laravel), on montre que le site est KO, puis on fait `helm rollback` → l'app revient **sans coupure (zéro-downtime)**.

### Q33 — Si un nœud tombe pendant la démo, que se passe-t-il ?
Grâce aux **3 replicas + anti-affinité**, des pods tournent encore sur les autres nœuds. Kubernetes **reschedule** automatiquement les pods perdus sur les nœuds restants. L'app reste disponible.

---

## I. Questions PIÈGES fréquentes (à anticiper)

### P1 — Pourquoi le LoadBalancer reste « pending » ?
Parce qu'on est sur des **EC2 auto-gérées**, sans cloud-controller AWS qui provisionnerait un vrai ELB. On contourne avec des **NodePorts** (32222/32214). C'est un choix assumé et documenté.

### P2 — Vous avez dit MySQL ou PostgreSQL ? (incohérence)
Le chart livré utilise **PostgreSQL (Bitnami)**. Le README mentionne encore MySQL : c'est une **incohérence de documentation** à corriger, mais l'implémentation réelle est PostgreSQL.

### P3 — Vous parlez de GitOps, mais utilisez-vous ArgoCD/Flux ?
**Non** — le GitOps est fait via **scripts + Kustomize** (`apply-gitops.sh`), en mode *push*. ArgoCD (mode *pull*) était un **bonus** non réalisé (ticket KUB-15). On sait expliquer la différence : ArgoCD synchronise en continu l'état Git ↔ cluster, alors que notre script applique à la demande.

### P4 — Votre authentification est-elle complète ?
On a **RBAC + TLS (cert-manager) + tokens**. En revanche, l'**OIDC complet avec dex + oauth-proxy** (mentionné dans l'énoncé) n'est **pas** mis en place. À assumer honnêtement.

### P5 — Que se passe-t-il si OPA tombe ?
Selon la `failurePolicy` du webhook : si elle est sur `Fail`, plus aucune ressource ne peut être créée (risque de blocage) ; si `Ignore`, les créations passent sans validation. Point important à connaître pour ne pas se faire piéger.

### P6 — Vos secrets sont-ils vraiment sécurisés ?
Les Secrets Kubernetes sont **encodés en base64, pas chiffrés** par défaut dans etcd. Pour aller plus loin il faudrait l'**encryption at rest** d'etcd ou un outil type **Sealed Secrets / Vault**. On connaît la limite.

### P7 — Pourquoi Calico et pas un autre CNI ?
Calico fournit le **réseau entre pods** + des **Network Policies** (pare-feu niveau pod). C'est robuste, répandu, et permet la micro-segmentation.

### P8 — Combien de temps pour tout reconstruire depuis zéro ?
Grâce à Terraform (infra) + Helm/Kustomize (apps), on peut **recréer tout le cluster et redéployer** en quelques commandes — c'est justement l'intérêt de l'Infrastructure as Code et du GitOps.

---

## J. Le mot de la fin (pitch de clôture)

> « KubeQuest démontre une **chaîne complète et automatisée** : du provisionnement AWS (Terraform) au déploiement applicatif (Helm), en passant par l'observabilité (Prometheus/Grafana/Loki), la résilience (replicas, anti-affinité, autoscaling, backups), la gouvernance (OPA) et le GitOps (Kustomize). Tout est **déclaratif, versionné et reproductible**, ce qui est exactement la promesse de Kubernetes en production. »

---

*Équipe : Groupe 50 — Epitech MSc Pro Promo 2026.*
