# 🎤 Discours de soutenance — KubeQuest (Infrastructure)

> Support : `docs/KubeQuest-infrastructure.pptx` (14 slides).
> Chaque section correspond au **numéro de la slide**. Le texte est rédigé pour être **dit à voix haute** (≈ 30–60 s par slide, ~10–12 min au total).
> Groupe 50 — Epitech MSc Pro Promo 2026.

---

## Slide 1 — Titre : KubeQuest

« Bonjour. Nous sommes le Groupe 50, et notre projet s'appelle **KubeQuest**. L'objectif : prendre une application **Laravel** qui tournait à l'origine en simple `docker-compose`, et la déployer sur un vrai **cluster Kubernetes multi-nœuds en production sur AWS** — avec toute la chaîne qu'on attend d'une plateforme sérieuse : infrastructure as code, load balancing, observabilité, GitOps, autoscaling, sauvegardes et sécurité.

Aujourd'hui, on ne va pas vous parler d'une maquette : on vous présente une **infrastructure complète, provisionnée, livrée, observée et sécurisée**. Je vais vous la dérouler couche par couche. »

---

## Slide 2 — Architecture : 4 nœuds spécialisés

« Voici la vue d'ensemble. Le cluster tourne sur **4 machines EC2**, et chaque nœud a un rôle précis — c'est un choix d'architecture, pas un hasard.

- **node-1**, le **control plane** : c'est le cerveau. L'API server, la base etcd qui stocke l'état du cluster, le scheduler, le contrôleur, la CNI Calico. Il fait aussi worker.
- **node-3**, l'**ingress** : la porte d'entrée unique du trafic externe, avec le TLS.
- **node-2**, le **worker métier** : c'est là que tournent l'application Laravel et sa base de données.
- **node-4**, le **monitoring** : Prometheus, Grafana, Loki — il observe tout le reste.

Deux flux à retenir. Le **flux applicatif** : l'utilisateur arrive sur l'ingress, qui route vers le Service, qui atteint le pod Laravel, qui parle à la base. Et le **flux d'observabilité** : les pods exposent des métriques que Prometheus récupère, Promtail pousse les logs vers Loki, et tout converge dans Grafana. Le tout sur un réseau privé stable, dans la région AWS de Francfort. »

---

## Slide 3 — Infrastructure as Code : Terraform

« Un point important : **rien n'est fait à la main sur AWS**. Tout le socle est décrit en **Terraform**, environ 580 lignes, et se reconstruit avec une seule commande, `terraform apply`.

Concrètement, Terraform crée :
- le **réseau** : un VPC dédié, une Internet Gateway, un subnet public, une route table, et un réseau privé stable en `10.2.50.0/24` ;
- la **sécurité réseau**, avec trois Security Groups — un pour les nœuds, un pour l'ingress, un pour le monitoring — qui jouent le rôle de pare-feu et n'ouvrent que les ports nécessaires : SSH, l'API Kubernetes sur 6443, le kubelet, les NodePorts ;
- les **4 instances EC2**, chacune avec un `user_data` qui pré-installe les prérequis Kubernetes dès le démarrage.

Et un détail qui compte pour la sécurité : la **clé SSH n'est jamais en clair**. Elle est lue depuis AWS SSM Parameter Store. L'infrastructure est donc **reproductible et auditable**. »

---

## Slide 4 — Socle Kubernetes

« Sur ces machines, le cluster Kubernetes est monté **à la main avec kubeadm** — on ne s'est pas reposés sur un service managé type EKS, justement pour maîtriser chaque étape.

`kubeadm init` sur node-1, puis les trois autres nœuds rejoignent le cluster avec `kubeadm join`. Résultat : **4 nœuds `Ready`**. Le runtime de conteneurs est **containerd**, et le réseau des pods est géré par la CNI **Calico**. On est en **Kubernetes v1.31**.

Un point technique qu'on maîtrise : le **ciblage des workloads**. Chaque composant est épinglé sur le bon nœud grâce aux **labels de rôle et au `nodeSelector`**. Par exemple, toute la stack de monitoring va sur le nœud portant le label `monitoring`, et l'application va précisément là où son image est disponible. C'est ce qui donne cette architecture propre, un rôle par nœud. »

---

## Slide 5 — Réseau & exposition

« Comment le trafic entre, et comment on l'isole.

L'entrée se fait par le **nginx-ingress** : un point d'entrée unique, qui route selon le nom d'hôte vers les bons Services. Petite subtilité AWS : sur des EC2 auto-gérées, il n'y a pas de LoadBalancer cloud natif, donc on expose aussi via **NodePort** en secours — c'est documenté, c'est assumé.

Le **TLS** est géré par **cert-manager** : un ClusterIssuer émet automatiquement les certificats HTTPS sur les Ingress, avec renouvellement automatique, sans qu'on ait à intervenir.

Et surtout, l'isolation : on a mis en place des **NetworkPolicies**. Par défaut, l'application n'est joignable que par l'ingress et le monitoring — **tous les autres namespaces sont bloqués**. On l'a vérifié en direct : un pod lancé depuis le namespace `default` qui essaie de joindre l'app tombe en **timeout**. La segmentation réseau est réelle, pas théorique. »

---

## Slide 6 — Livraison applicative : Helm

« L'application, maintenant. Elle n'est pas déployée avec des `kubectl apply` éparpillés : elle est **packagée dans un chart Helm complet**, qui contient tous les objets Kubernetes en templates.

On y trouve le **Deployment**, le **Service**, l'**Ingress**, la **ConfigMap**, le **Secret** pour les données sensibles, mais aussi tout ce qui fait une app de production : le **HPA** pour l'autoscaling, le **PodDisruptionBudget** pour la disponibilité, le **PVC** pour le stockage, le **ServiceAccount**, un **CronJob de backup**, un **ServiceMonitor** pour le monitoring, et même des tests Helm.

La **base de données** est fournie par un chart Helm officiel, intégrée comme dépendance — avec persistance, authentification via Secret et métriques.

L'avantage : `helm install` déploie l'app **et** sa base d'un coup, toute la config est centralisée dans un `values.yaml`, et Helm gère proprement les **upgrades et les rollbacks** par versions. »

---

## Slide 7 — Bonnes pratiques Kubernetes

« Cette slide résume ce qui fait qu'on a une app pensée **pour la production**, et pas juste « qui tourne ». Huit pratiques :

- **Ressources** : chaque conteneur a ses `requests` et `limits` CPU et mémoire.
- **Redondance** : 3 replicas, plus un PodDisruptionBudget.
- **Anti-affinité** : ces replicas sont répartis sur des nœuds différents — si un nœud tombe, l'app survit.
- **Autoscaling** : un HPA qui va de 3 à 10 pods selon la charge CPU et RAM.
- **Persistance** : un PVC pour les données, plus un backup quotidien avec 30 jours de rétention.
- **Probes** : liveness et readiness, ce qui permet des mises à jour en rolling update sans coupure.
- **Secrets** : toutes les données sensibles passent par des Secrets Kubernetes.
- **Security context** : conteneur non-root, système de fichiers en lecture seule, et suppression de toutes les capabilities Linux.

Concrètement : la charge monte, l'HPA crée des pods, le scheduler les place sur des nœuds différents grâce à l'anti-affinité, les données survivent aux redémarrages, et sont sauvegardées chaque nuit. »

---

## Slide 8 — Observabilité (1/2) : Monitoring

« On ne pilote pas ce qu'on ne mesure pas. Donc on a déployé une stack de monitoring complète sur le nœud dédié, avec trois briques :

- **Prometheus**, qui *scrape* les métriques des pods et des nœuds, et récupère celles de l'app via des **ServiceMonitors** ;
- **Alertmanager**, qui déclenche des alertes sur seuils, en haute disponibilité ;
- **Grafana**, qui visualise tout ça — et qui affiche à la fois les **métriques et les logs** dans une seule interface.

Pour être précis et honnête sur le réel : la stack déployée est **kube-prometheus-stack en version 82.16.1**, avec le prometheus-operator v0.89 et Grafana 12, dans le namespace `monitoring`, épinglée sur node-4. C'est une stack récente et à jour. »

---

## Slide 9 — Observabilité (2/2) : Logs & Dashboard

« Le complément du monitoring, c'est la **centralisation des logs** et une **console d'administration**.

Côté logs, on utilise **Loki et Promtail**. Promtail est un DaemonSet : il tourne sur chaque nœud et collecte les logs de **tous les pods**. Loki les indexe et les agrège, avec de la persistance. Et on les consulte directement dans Grafana — on a ajouté la source de données Loki, donc les logs sont interrogeables, par exemple par namespace. L'intérêt : **une seule UI, Grafana, pour les métriques ET les logs**.

Côté administration, on a le **Kubernetes Dashboard** : une console web pour voir en temps réel les pods, les déploiements, les events. L'accès est sécurisé — un ServiceAccount dédié `admin-user`, des droits RBAC via ClusterRoleBinding et un token — et il est exposé via Ingress. »

---

## Slide 10 — GitOps : ArgoCD

« Maintenant, comment on déploie de façon fiable et traçable : le **GitOps avec ArgoCD**.

Le principe : **Git est la source de vérité**. On décrit l'état désiré dans le dépôt, et ArgoCD réconcilie le cluster en continu pour qu'il corresponde à Git. On a créé un AppProject `kubequest`, et — un point qui nous a demandé du travail — configuré l'accès au **dépôt privé** de l'organisation, protégé par **SAML SSO** : il a fallu un token classique explicitement autorisé pour le SSO. On a aussi activé Helm dans Kustomize.

On a fait un choix d'architecture assumé. L'**infrastructure** est découpée en **6 Applications** — une par composant : nginx-ingress, cert-manager, dashboard, monitoring, logging et security. Elles sont en **sync manuel**, volontairement, pour ne pas perturber une infra déjà vivante.

En revanche, l'**application Laravel** est le vrai livrable GitOps : elle est en **Synced / Healthy**, avec **auto-sync, prune et selfHeal**. Autrement dit, **tout push sur `main` redéploie l'app automatiquement**, dans son namespace dédié. On a même ajouté un health-check personnalisé pour les Ingress dans ArgoCD. La séparation est nette : l'app en pull automatique, l'infra sous contrôle. »

---

## Slide 11 — Sécurité (1/2) : Admission & confiance

« La sécurité, en deux temps. D'abord, faire en sorte que **le cluster impose lui-même les bonnes pratiques**.

Pour ça, on a un **validating webhook OPA / Gatekeeper**. À chaque `kubectl apply`, l'API server consulte ce webhook, qui **refuse l'admission** de tout ce qui n'est pas conforme :
- un pod sans le label obligatoire → refusé ;
- un conteneur qui tourne en root → refusé ;
- un conteneur sans limites de ressources → refusé ;
- un déploiement avec moins de 2 replicas → refusé.

Un point que je veux souligner, parce qu'il montre notre rigueur : le dépôt contenait au départ un OPA « maison » configuré en `failurePolicy: Fail` sur **tout le cluster** et sans TLS fonctionnel. Le déployer tel quel aurait **bloqué la création de n'importe quel pod**. On l'a remplacé par **Gatekeeper**, l'implémentation standard et sûre, en fail-open et excluant les namespaces système.

À droite, le reste de la confiance : le **TLS** avec cert-manager pour chiffrer le trafic externe, et le **RBAC** avec des ServiceAccounts dédiés en moindre privilège, plus les **Secrets Kubernetes** — jamais de mot de passe en clair. »

---

## Slide 12 — Sécurité (2/2) : Contrôle d'accès

« Deuxième temps de la sécurité : **qui a le droit d'accéder aux outils**.

On a mis en place un **SSO** avec **dex et oauth2-proxy** : une authentification unifiée en OIDC devant les outils d'exploitation. Concrètement, si quelqu'un tente d'accéder à Prometheus sans être authentifié, il est **redirigé, avec un 302, vers dex**. Un seul point d'authentification, et une surface d'exposition réduite.

Et surtout, l'idée générale, c'est la **défense en profondeur** : on ne mise pas sur une seule barrière. On empile des couches **indépendantes** — une basic-auth devant Prometheus, les NetworkPolicies pour l'isolation réseau, OPA pour l'admission, le TLS et le RBAC. Comme ça, **aucune couche unique n'est un point de défaillance**. Si l'une cède, les autres tiennent. »

---

## Slide 13 — Résilience & preuve

« Une infra, ça se dit robuste, mais surtout ça se **prouve**. On a préparé trois scénarios qu'on montre en direct.

- **L'autoscaling** : on envoie une charge d'environ 400 requêtes par seconde avec un `load-test`, et on **voit les pods passer de 3 à 10** en temps réel, directement dans Grafana.
- **Le rollback zéro-downtime** : on déploie volontairement une version cassée de l'app, on constate la panne, puis on **revient à la version stable sans coupure de service**.
- **Les sauvegardes** : on avait un blocage — il manquait une StorageClass, donc le PVC de backup restait en attente. On l'a corrigé, et les **backups de la base sont maintenant fonctionnels**, avec le CronJob quotidien.

Le message : **chaos maîtrisé**. Charge, panne, version cassée — pour chaque cas, on peut montrer le comportement du cluster, en direct, dans le monitoring. »

---

## Slide 14 — Bilan

« Pour conclure. On est partis d'une application Laravel en docker-compose, et on livre une **infrastructure de production de bout en bout** :

- un **socle** entièrement en Terraform : 4 EC2, VPC, Security Groups ;
- un **cluster** Kubernetes v1.31 monté à la main, avec containerd et Calico ;
- une **livraison** industrialisée : Helm et GitOps avec ArgoCD en auto-sync sur l'application ;
- une **observabilité** complète : Prometheus, Grafana, Loki, et le Dashboard ;
- de la **résilience** : autoscaling, anti-affinité, PodDisruptionBudget, sauvegardes ;
- et une **sécurité multi-couches** : OPA, TLS, RBAC, SSO, NetworkPolicies.

En un mot : on a traité ce projet comme une **vraie infrastructure de production**, pas comme un exercice. Merci — on est prêts pour vos questions. »

---

### ⏱️ Repères de timing
| Bloc | Slides | Durée cible |
|------|--------|-------------|
| Ouverture & architecture | 1–2 | ~1 min 30 |
| Socle (IaC + cluster + réseau) | 3–5 | ~2 min 30 |
| Application & bonnes pratiques | 6–7 | ~2 min |
| Observabilité | 8–9 | ~1 min 30 |
| GitOps | 10 | ~1 min |
| Sécurité | 11–12 | ~2 min |
| Résilience & bilan | 13–14 | ~1 min 30 |

*Total ≈ 11–12 minutes.*
