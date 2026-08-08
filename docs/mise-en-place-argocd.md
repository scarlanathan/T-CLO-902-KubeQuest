# Mise en place d'ArgoCD (GitOps) — KubeQuest

> Document de synthèse — rédigé le 30/06/2026. Décrit l'installation et la configuration
> d'ArgoCD sur le cluster AWS, les problèmes rencontrés et leurs corrections.
> **Non commité** (document de travail / support de soutenance).

---

## 1. Objectif

Mettre en place **ArgoCD** pour piloter le déploiement en **GitOps continu** : le cluster se
synchronise automatiquement sur l'état décrit dans le dépôt Git, au lieu de scripts manuels
(`apply-gitops.sh`).

---

## 2. Contexte technique

- **Cluster** : Kubernetes v1.31 sur AWS EC2 (4 nœuds : control-plane + worker + ingress + monitoring).
- **Accès** : pas de contexte kube en local (le `kubectl` local pointait sur un minikube arrêté).
  On opère via SSH sur l'instance : `ssh -i ~/.ssh/kubequest.pem ec2-user@35.156.165.130`.
- **Dépôt** : `github.com/EpitechMscProPromo2026/T-CLO-902-PAR_5` (privé, organisation avec **SAML SSO**).
- **App** : application Laravel (compteur) + base MySQL, image locale `kubequest-app:latest`.

---

## 3. Installation d'ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Composants déployés et fonctionnels : `argocd-server`, `argocd-repo-server`,
`argocd-application-controller`, `argocd-redis`, `argocd-dex-server`, `argocd-notifications-controller`.

### Activation de Helm dans Kustomize (indispensable ici)

Les `kustomization.yaml` du dépôt utilisent des `helmCharts:` (inflation de charts Helm par
Kustomize). ArgoCD exige alors le flag `--enable-helm` :

```bash
kubectl patch configmap argocd-cm -n argocd --type merge \
  --patch-file helmpatch.yaml   # data: { kustomize.buildOptions: --enable-helm }
kubectl rollout restart deployment argocd-repo-server -n argocd
```

---

## 4. Le point dur : l'accès au dépôt privé (SAML SSO)

C'est l'étape qui a demandé le plus d'itérations. Chronologie des erreurs et solutions :

| Tentative | Résultat | Cause |
|---|---|---|
| Token **fine-grained** | `403 – Repository not found` | Les tokens fine-grained sur un repo d'orga exigent une **approbation admin** de l'organisation. |
| Token **classique** (sans SSO) | `403 – organization has enabled SAML SSO` | L'orga Epitech impose le **SAML SSO** ; le token doit être explicitement autorisé. |
| Token **classique + SSO autorisé** | ✅ `git ls-remote` OK | **Solution retenue.** |

### Configuration finale du credential

```bash
kubectl create -n argocd secret generic repo-kubequest \
  --from-literal=type=git \
  --from-literal=url=https://github.com/EpitechMscProPromo2026/T-CLO-902-PAR_5.git \
  --from-literal=username=argocd \
  --from-literal=password=<TOKEN_CLASSIQUE_ghp_...>
kubectl label -n argocd secret repo-kubequest argocd.argoproj.io/secret-type=repository
```

> **Point clé** : générer un token **classique** (`ghp_...`), scope `repo`, puis
> **Configure SSO → Authorize** pour `EpitechMscProPromo2026`. Sans cette autorisation, GitHub renvoie 403.

---

## 5. Découverte importante : le dépôt GitOps ≠ le cluster réel

En configurant ArgoCD, on a constaté que le dossier `kubequest-cluster/gitops/` décrit un état
**idéal** qui ne correspond pas au cluster (bootstrappé à la main avec d'autres versions/namespaces).

| Composant | Déclaré dans le repo | Réellement déployé |
|---|---|---|
| nginx-ingress | 4.11.0 | **4.15.1** |
| kube-prometheus-stack | 55.0.0, release `prometheus` | **82.16.1**, release `kube-prometheus` |
| loki-stack | ns `logging`, 2.10.2 | ns **`monitoring`**, 2.10.3 |
| laravel | image `your-registry/laravel-app:1.0.0`, host `larapp...` | image **`kubequest-app:latest`**, host `app.kubequest.local`, ns `laravel` |
| kubernetes-dashboard | chart Helm v7.0.0 | **repo du chart mort (404)** ; déployé en manifests bruts |
| cert-manager, opa/security | déclarés | **non déployés** |

**Conséquence** : mettre l'infrastructure en auto-sync serait risqué (conflits de
versions/release-names/CRDs sur un cluster vivant). Décision : **auto-sync uniquement pour
l'application Laravel** ; l'infrastructure reste en **sync manuel**.

Autres contraintes du cluster relevées :
- Nœuds en architecture **ARM (aarch64)** → le chart `kubequest-cluster/laravel-app`
  (nodeSelector `amd64`) ne planifierait pas.
- **Aucune StorageClass** → tout chart avec PVC (le chart PostgreSQL) resterait *Pending*.
- L'image `kubequest-app:latest` n'existe que sur le nœud worker `190` (image locale, pas de registry).

---

## 6. Corrections apportées (branche `feature/argocd-gitops`, mergée sur `main`)

### 6.1 Application Laravel (le vrai livrable GitOps)

Le chart `kubequest-cluster/laravel-app` (base PostgreSQL, port 9000, PVC, EKS IAM) ne correspond
**ni à l'app ni au cluster**. On a utilisé le **chart réel `helm/`** (celui de la release déployée) :

- **Restauration de `helm/templates/deployment.yaml`** (il avait été renommé en `.save`, le chart
  n'avait donc plus de template de déploiement actif).
- Alignement des valeurs sur le réel : image `kubequest-app:latest`, `pullPolicy: Never`,
  port 80, sondes sur `/`, host `larapp.kubequest.local` (distinct pour éviter tout conflit).
- **Scheduling épinglé** sur le nœud `190` (nodeSelector `kubernetes.io/hostname`) car l'image y est présente.
- **Réutilisation du MySQL existant** en cross-namespace :
  `laravel-mysql.laravel.svc.cluster.local`, avec les identifiants du secret existant.

### 6.2 Infrastructure (rendable, sync manuel)

- **kubernetes-dashboard** : retrait du `helmChart` (le repo `https://kubernetes.github.io/dashboard/`
  renvoie 404 « Site not found »). On garde les manifestes bruts.
- **monitoring** : `prometheusSpec/alertmanagerSpec/grafana.podAntiAffinity` déplacés sous
  `affinity:` (le chart attend `podAntiAffinity` en string `soft`/`hard`, pas un bloc complet).
- **kustomization parent** : retrait du `namespace: kube-system` global, qui écrasait le namespace de
  chaque composant et provoquait `namespace transformation produces ID conflict`.

### 6.3 Manifestes ArgoCD (nouveau dossier `kubequest-cluster/gitops/argocd/`)

- `project.yaml` — AppProject `kubequest`.
- `application-laravel.yaml` — Application Helm native (`path: helm`), **auto-sync**
  (prune + selfHeal), namespace `laravel-app-prod`.
- `application-infrastructure.yaml` — Application Kustomize, **sync manuel** volontaire.

### 6.4 Réglage ArgoCD

- Health-check custom pour les `Ingress` dans `argocd-cm` : le contrôleur nginx du cluster ne publie
  pas d'adresse de LoadBalancer, ce qui laissait les Ingress (et donc l'app) en `Progressing`.

---

## 7. État final

| Application | Sync | Health | Mode |
|---|---|---|---|
| **laravel-app** | `Synced` | `Healthy` | auto-sync (prune + selfHeal) |
| **kubequest-infrastructure** | `OutOfSync` | — | sync manuel (rend sans erreur) |

- **2 pods `laravel-app` Running** dans `laravel-app-prod`, réponse **HTTP 200** (page compteur, DB OK).
- Tout est commité et mergé sur `main` (merge `8005788`).

---

## 8. Accès à l'interface ArgoCD

Le service `argocd-server` est en `ClusterIP` (non exposé). Accès par tunnel SSH :

```bash
ssh -i ~/.ssh/kubequest.pem -L 8080:localhost:8080 ec2-user@35.156.165.130
# puis dans la session SSH :
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

→ **https://localhost:8080** — utilisateur `admin`.
Mot de passe initial :
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## 9. Fonctionnement GitOps

- Tout push sur `main` modifiant `helm/` → **ArgoCD redéploie `laravel-app` automatiquement**.
- L'infrastructure se synchronise **manuellement** (bouton *Sync* dans l'UI), volontairement, pour
  ne pas perturber le monitoring/ingress en place.

---

## 10. Points restants / améliorations possibles

- **Sécurité** : supprimer l'ancien token fine-grained (inutilisé) ; roter le token classique stocké
  dans le secret `repo-kubequest` si besoin.
- **URL permanente** : créer un Ingress `argocd.kubequest.local` (au lieu du port-forward).
- **applicationset-controller** en CrashLoopBackOff (CRD `ApplicationSet` absente de l'install) —
  cosmétique, non bloquant ; à corriger en appliquant la CRD ou en désactivant le controller.
- **Réconciliation infra** : à terme, aligner le dépôt GitOps sur les versions réellement déployées
  pour pouvoir passer l'infrastructure en auto-sync (chantier de migration à part entière).
