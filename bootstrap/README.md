# KubeQuest - Bootstrap

Livrables du sujet Bootstrap : manifestes Kubernetes, chart Helm, Kustomize,
configuration PostgreSQL et Terraform Azure.

## Arborescence

```
bootstrap/
├── manifests/             # Manifestes Kubernetes bruts (pod, deployment, service, ingress)
├── postgresql/            # Values override pour le chart PostgreSQL de Bitnami
├── helm-chart/hello-world # Chart Helm générique pour hello-world
├── kustomize/             # Base + overlays staging/production
└── terraform/             # VM Azure DevTestLab via Terraform
```

## 1. Docker

Prérequis — Docker doit être installé et fonctionnel :

```bash
docker --version
docker run hello-world
```

## 2. Minikube (sandbox local)

```bash
# Démarrer le cluster local
minikube start --vm-driver=virtualbox
minikube status

# Contexte kubectl
kubectl config current-context
kubectl config use-context minikube

# Activer l'ingress-controller (nécessaire pour ingress.yaml)
minikube addons enable ingress

# Supprimer le cluster
minikube delete
```

## 3. Microsoft Azure (DevTestLab)

Déploiement d'une VM de laboratoire avec Terraform :

```bash
cd terraform/
terraform init
terraform plan -var="lab_name=<LAB_NAME>" -var="resource_group=<RG>"
terraform apply
```

Voir `terraform/main.tf` pour les variables.

## 4. Kubernetes basics

### Pod

```bash
kubectl apply -f manifests/pod.yaml
kubectl get pods
kubectl get pod hello-world -o yaml
kubectl logs --tail=50 hello-world
kubectl exec -it hello-world -- /bin/sh
kubectl delete -f manifests/pod.yaml
```

### Deployment + Service + Ingress

```bash
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/ingress.yaml

# Scale up/down
kubectl scale deployment/hello-world --replicas=3

# Rolling restart
kubectl rollout restart deployment/hello-world

# Edit
kubectl edit deployment hello-world
```

## 5. Helm — PostgreSQL

```bash
# Installer Helm + autocomplétion
helm version
source <(helm completion bash)

# Repo Bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Déploiement avec override
helm install my-postgres bitnami/postgresql -f postgresql/values.yaml

# Lister
kubectl get pods -l app.kubernetes.io/instance=my-postgres

# Connexion SQL
kubectl run psql-client --rm -it --restart=Never \
  --image=bitnami/postgresql:latest \
  --env="PGPASSWORD=kubequestpass" \
  -- psql -h my-postgres-postgresql -U kubequest -d kubequestdb

# Upgrade / rollback / history / uninstall
helm upgrade my-postgres bitnami/postgresql -f postgresql/values.yaml
helm history my-postgres
helm rollback my-postgres 1
helm uninstall my-postgres
```

Endpoints DNS internes :

- Primary : `my-postgres-postgresql.default.svc.cluster.local`
- Read (replicas) : `my-postgres-postgresql-read.default.svc.cluster.local`

## 6. Helm — Chart hello-world

```bash
# Lint + render
helm lint helm-chart/hello-world
helm template hello helm-chart/hello-world

# Install
helm install hello helm-chart/hello-world

# Override
helm install hello helm-chart/hello-world \
  --set replicaCount=5 \
  --set image.tag=1.4 \
  --set service.port=80
```

## 7. Bonus — Kustomize (dev / staging / production)

```bash
# Render
kubectl kustomize kustomize/base
kubectl kustomize kustomize/overlays/staging
kubectl kustomize kustomize/overlays/production

# Apply
kubectl apply -k kustomize/overlays/staging
kubectl apply -k kustomize/overlays/production
```

## One more thing — Niveau d'abstraction Helm

Pour une infra avec des dizaines de micro-services, on évite 1 chart par
service. Recommandation pragmatique :

- **1 chart générique par *type d'application*** (`web-api`, `worker`,
  `cron-job`, `static-front`) — les micro-services qui partagent une même
  forme (Deployment + Service + Ingress + HPA + ConfigMap) réutilisent tous
  le même chart, avec un `values.yaml` par service.
- Un chart par langage est trop fin : deux services Go peuvent avoir des
  topologies très différentes (API HTTP vs worker Kafka).
- Un chart par application est trop coûteux à maintenir.

Helm pour le moule, Kustomize (ou values par environnement) pour les
variations dev/staging/prod.
