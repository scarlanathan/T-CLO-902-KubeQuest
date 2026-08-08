# Journal Technique — KubeQuest Groupe 50

## Résumé

Ce document retrace toutes les étapes réalisées pour déployer le cluster Kubernetes du projet KubeQuest (Epitech).

---

## Environnement

- **Région AWS** : `eu-central-1`
- **OS** : Amazon Linux 2023 (aarch64)
- **Kubernetes** : v1.31.14
- **Container runtime** : containerd 2.2.1
- **Plugin réseau** : Calico

---

## Infrastructure — Nœuds AWS EC2

| Nœud | Rôle K8s | IP Privée | IP Publique |
|------|----------|-----------|-------------|
| `node-1` (`ec2-group-50-node-1`) | Control Plane | 10.2.50.23 | 35.156.165.130 |
| `node-2` (`ec2-group-50-node-2`) | Worker | 10.2.50.190 | 3.79.247.101 |
| `node-3` (`ec2-group-50-node-3`) | Ingress | 10.2.50.90 | 3.77.235.74 |
| `node-4` (`ec2-group-50-node-4`) | Monitoring | 10.2.50.113 | 3.120.183.206 |

> **Important** : Les IP publiques peuvent changer à chaque redémarrage des instances. Toujours vérifier dans la console AWS avant de travailler.

---

## Structure du dépôt

```
.
├── app-master/               # Application Laravel (source originale docker-compose)
├── docs/
│   ├── infrastructure.md     # Informations des nœuds AWS
│   └── journal-technique.md  # Ce fichier
└── scripts/
    ├── dashboard/            # Accès au Kubernetes Dashboard
    │   ├── kubeconfig-dashboard.template.yaml
    │   ├── generate-kubeconfig.sh
    │   └── get-dashboard-token.sh
    ├── windows/              # Scripts PowerShell (Win11)
    │   ├── fix-ssh-config.ps1
    │   ├── install-k8s.ps1
    │   ├── init-cluster.ps1
    │   ├── join-nodes.ps1
    │   ├── install-calico.ps1
    │   └── check-cluster.ps1
    └── linux/                # Scripts Bash (Linux/Mac)
        ├── install-k8s.sh
        ├── init-cluster.sh
        ├── join-nodes.sh
        ├── install-calico.sh
        └── check-cluster.sh
```

---

## Étape 1 — Récupération de la clé SSH

La clé privée SSH est stockée dans AWS Systems Manager Parameter Store.

**Chemin SSM** : `/kubequest/group-50/ssh-private-key`

### Depuis AWS CloudShell (recommandé)

```bash
aws ssm get-parameter \
  --name "/kubequest/group-50/ssh-private-key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > ~/.ssh/kubequest.pem
chmod 400 ~/.ssh/kubequest.pem
```

### Depuis Windows (PowerShell)

```powershell
# Ouvrir le fichier dans le bloc-notes et coller le contenu de la clé
notepad $env:USERPROFILE\.ssh\kubequest.pem

# Appliquer les permissions correctes
icacls "$env:USERPROFILE\.ssh\kubequest.pem" /inheritance:r /grant:r "${env:USERNAME}:R"
```

### Connexion SSH

```bash
# Utilisateur : ec2-user (Amazon Linux 2023)
ssh -i ~/.ssh/kubequest.pem ec2-user@<IP_PUBLIQUE>
```

---

## Étape 2 — Installation des prérequis (tous les nœuds)

Scripts : `scripts/windows/install-k8s.ps1` / `scripts/linux/install-k8s.sh`

Ces scripts se connectent via SSH aux 4 nœuds et installent :

| Package | Rôle |
|---------|------|
| `socat` | Communication réseau pour kubeadm |
| `conntrack` + `iproute-tc` | Suivi des connexions réseau |
| `containerd` | Container runtime (remplace Docker) |
| `kubeadm` | Outil d'initialisation du cluster |
| `kubectl` | CLI pour interagir avec le cluster |
| `kubelet` | Agent Kubernetes sur chaque nœud |

### Configuration de containerd

```bash
sudo dnf install -y containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
# Activer le cgroup systemd (obligatoire pour Kubernetes)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl enable --now containerd
```

### Dépôt Kubernetes

```bash
sudo tee /etc/yum.repos.d/kubernetes.repo > /dev/null <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF
sudo dnf install -y kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

### Problèmes rencontrés

| Problème | Cause | Solution |
|---------|-------|---------|
| `tc: command not found` | Le paquet `tc` s'appelle `iproute-tc` sur Amazon Linux 2023 | Remplacer `tc` par `iproute-tc` |
| `containerd.sock: no such file` | containerd non installé | Ajouter l'installation de containerd au script |
| SSH config BOM error | Le fichier `~/.ssh/config` avait un BOM UTF-8 | Script `fix-ssh-config.ps1` pour supprimer le BOM |

---

## Étape 3 — Initialisation du Control Plane (node-1)

Scripts : `scripts/windows/init-cluster.ps1` / `scripts/linux/init-cluster.sh`

```bash
# 1. Désactiver le swap (obligatoire pour Kubernetes)
sudo swapoff -a

# 2. Charger les modules kernel nécessaires
sudo modprobe overlay
sudo modprobe br_netfilter

# 3. Paramètres réseau kernel
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# 4. Initialisation du cluster
sudo kubeadm init \
  --apiserver-advertise-address=10.2.50.23 \
  --pod-network-cidr=192.168.0.0/16 \
  --node-name=node-1

# 5. Configurer kubectl pour l'utilisateur courant
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## Étape 4 — Jonction des nœuds workers (node-2, 3, 4)

Scripts : `scripts/windows/join-nodes.ps1` / `scripts/linux/join-nodes.sh`

La commande `kubeadm join` est générée automatiquement après `kubeadm init` et sauvegardée dans `scripts/logs/join-command.txt` (ignoré par git).

```bash
# Prérequis : activer ip_forward sur chaque worker
sudo modprobe overlay && sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Jonction au cluster
sudo kubeadm join 10.2.50.23:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

### Problème rencontré

| Problème | Cause | Solution |
|---------|-------|---------|
| `ip_forward contents are not set to 1` | `sysctl --system` non exécuté sur les workers | Exécuter `sysctl --system` avant le `kubeadm join` |

---

## Étape 5 — Installation du plugin réseau Calico

Scripts : `scripts/windows/install-calico.ps1` / `scripts/linux/install-calico.sh`

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

Calico est le CNI (Container Network Interface) qui permet la communication entre les pods sur différents nœuds.

---

## Étape 6 — Attribution des rôles aux nœuds (labels)

Les nœuds workers rejoignent le cluster sans rôle défini (`<none>`). On utilise les labels Kubernetes pour indiquer leur rôle.

```bash
kubectl label node ip-10-2-50-190.eu-central-1.compute.internal node-role.kubernetes.io/worker=worker
kubectl label node ip-10-2-50-90.eu-central-1.compute.internal  node-role.kubernetes.io/ingress=ingress
kubectl label node ip-10-2-50-113.eu-central-1.compute.internal node-role.kubernetes.io/monitoring=monitoring
```

Ces labels servent aussi à cibler les nœuds lors des déploiements avec `nodeSelector`.

---

## Étape 7 — Installation de kubernetes-dashboard

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

### Création du compte admin

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF
```

### Patch pour désactiver l'expiration du token

```bash
kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["--auto-generate-certificates","--namespace=kubernetes-dashboard","--token-ttl=0"]}]'
```

### Accès depuis Windows (SSH tunnel)

```powershell
# Ouvrir un tunnel SSH et lancer kubectl proxy sur node-1
ssh -i ~/.ssh/kubequest.pem -L 8001:localhost:8001 ec2-user@35.156.165.130 "kubectl proxy --port=8001 --address=127.0.0.1"
```

Puis ouvrir dans le navigateur :
```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

Récupérer le token d'accès :
```bash
# Sur node-1
kubectl -n kubernetes-dashboard get secret admin-user-token \
  -o jsonpath='{.data.token}' | base64 -d
# Ou utiliser le script : scripts/dashboard/get-dashboard-token.sh
```

Pour générer le kubeconfig complet depuis Windows :
```powershell
bash scripts/dashboard/generate-kubeconfig.sh ~/.ssh/kubequest.pem
```
Cela génère `scripts/dashboard/kubeconfig-dashboard.yaml` (ignoré par git) à uploader dans le dashboard.

---

## Étape 9 — Installation de nginx-ingress (node-3)

nginx-ingress est le contrôleur qui reçoit le trafic externe et le redirige vers les services internes du cluster.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.nodeSelector."node-role\.kubernetes\.io/ingress"=ingress
```

Vérification :
```bash
kubectl get pods -n ingress-nginx -o wide
# ingress-nginx-controller   1/1   Running   ip-10-2-50-90 (node-3)
```

---

## Étape 10 — Installation de kube-prometheus stack (node-4)

kube-prometheus-stack installe Prometheus (collecte des métriques), Grafana (visualisation) et Alertmanager (alertes).

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
  --set grafana.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
  --set alertmanager.alertmanagerSpec.nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring
```

Récupérer le mot de passe Grafana :
```bash
kubectl --namespace monitoring get secrets kube-prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

---

## Étape 11 — Installation de Loki (node-4)

Loki collecte et indexe les logs de tous les pods du cluster. Promtail (agent) tourne sur chaque nœud pour envoyer les logs à Loki.

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set nodeSelector."node-role\.kubernetes\.io/monitoring"=monitoring \
  --set promtail.enabled=true
```

> Note : `loki-stack` est déprécié mais fonctionnel. Pour une installation en production, utiliser `loki` avec un `values.yaml` personnalisé.

---

## Résultat — État du cluster

```
NAME                                           STATUS   ROLES           VERSION    INTERNAL-IP
node-1                                         Ready    control-plane   v1.31.14   10.2.50.23
ip-10-2-50-190.eu-central-1.compute.internal   Ready    worker          v1.31.14   10.2.50.190
ip-10-2-50-90.eu-central-1.compute.internal    Ready    ingress         v1.31.14   10.2.50.90
ip-10-2-50-113.eu-central-1.compute.internal   Ready    monitoring      v1.31.14   10.2.50.113
```

### Pods en cours d'exécution

| Namespace | Composant | Nœud |
|-----------|-----------|------|
| `kube-system` | CoreDNS, etcd, kube-apiserver, kube-scheduler, Calico | node-1 |
| `kubernetes-dashboard` | kubernetes-dashboard, dashboard-metrics-scraper | node-2 / node-3 |
| `ingress-nginx` | ingress-nginx-controller | node-3 |
| `monitoring` | Prometheus, Grafana, Alertmanager | node-4 |
| `monitoring` | Loki, Promtail (sur chaque nœud) | node-4 / tous |

---

## Checklist d'avancement

### Infrastructure de base
- [x] Nœuds AWS démarrés et accessibles en SSH
- [x] containerd + kubeadm + kubectl installés sur les 4 nœuds
- [x] Cluster Kubernetes initialisé (node-1 control plane)
- [x] node-2, node-3, node-4 joints au cluster
- [x] Plugin réseau Calico — tous les nœuds `Ready`
- [x] Labels des nœuds (worker / ingress / monitoring)
- [x] nginx-ingress controller (node-3)
- [x] kube-prometheus stack — Prometheus + Grafana (node-4)
- [x] Loki + Promtail (node-4)

### Composants à installer
- [x] kubernetes-dashboard
- [x] Helm (node-1)

### Application
- [ ] Build image Docker Laravel + push registry
- [ ] Helm Chart pour l'application Laravel
- [ ] Chart MySQL officiel avec Persistent Volume
- [ ] Secrets Kubernetes pour les credentials (DB_PASSWORD, APP_KEY...)
- [ ] Resource limits/requests sur tous les pods
- [ ] Multi-réplicas + règles d'affinité
- [ ] GitOps avec Kustomize

### Sécurité & Bonus
- [ ] Validating Webhook (OPA)
- [ ] Authentification (dex + oauth-proxy)
- [ ] HTTPS avec cert-manager + Let's Encrypt
- [ ] Network Policies
- [ ] ArgoCD (bonus GitOps)
