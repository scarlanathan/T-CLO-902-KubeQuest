# Vérification des installations — KubeQuest Groupe 50

Guide pour vérifier que chaque nœud est correctement installé et configuré.
Pour chaque commande : ce qu'elle vérifie + le **résultat attendu** (✅ = bon signe).

> Toutes les vérifications « cluster » se lancent depuis **node-1** (le control plane, seul à avoir `kubectl` configuré).
> Les vérifications « système » se lancent sur chaque nœud via SSH.

---

## 0. Se connecter aux nœuds (depuis PowerShell)

```powershell
ssh -i "$env:USERPROFILE\.ssh\kubequest.pem" ec2-user@35.156.165.130   # node-1 control plane
ssh -i "$env:USERPROFILE\.ssh\kubequest.pem" ec2-user@3.72.17.106      # node-2 worker
ssh -i "$env:USERPROFILE\.ssh\kubequest.pem" ec2-user@3.123.1.25       # node-3 ingress
ssh -i "$env:USERPROFILE\.ssh\kubequest.pem" ec2-user@3.120.183.206    # node-4 monitoring
```

> ⚠️ Les IP publiques changent au redémarrage des VM. Si un `ssh` fait `Connection timed out`, récupère la nouvelle IP dans la console EC2.

---

## 1. Vérification GLOBALE du cluster (depuis node-1)

C'est le test le plus important : si tout est vert ici, l'essentiel fonctionne.

```bash
# Les 4 nœuds doivent être Ready, version v1.31.14
kubectl get nodes -o wide
```
✅ **Attendu** : 4 lignes, toutes `STATUS = Ready`, avec les rôles `control-plane`, `worker`, `ingress`, `monitoring`.

```bash
# Aucun pod système en erreur
kubectl get pods -A
```
✅ **Attendu** : tous les pods en `Running` (ou `Completed`). ❌ À investiguer si `CrashLoopBackOff`, `Error`, `Pending`, `ImagePullBackOff`.

```bash
# Santé des composants du control plane
kubectl get componentstatuses        # (ou: kubectl get cs)
```
✅ **Attendu** : `scheduler`, `controller-manager`, `etcd-0` → `Healthy`.

```bash
# Vérifier que l'API répond
kubectl cluster-info
```
✅ **Attendu** : `Kubernetes control plane is running at https://10.2.50.23:6443`.

---

## 2. Vérifications SYSTÈME (à faire sur CHAQUE nœud via SSH)

Ces 6 points doivent être identiques sur les 4 nœuds (ce sont les prérequis kubeadm).

```bash
# a) Swap désactivé (OBLIGATOIRE pour Kubernetes)
swapon --show
```
✅ **Attendu** : aucune sortie (vide) = pas de swap actif.

```bash
# b) Modules kernel chargés
lsmod | grep -E "overlay|br_netfilter"
```
✅ **Attendu** : les lignes `overlay` et `br_netfilter` apparaissent.

```bash
# c) Paramètres réseau kernel
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
```
✅ **Attendu** : les deux valent `= 1`.

```bash
# d) kubelet actif et lancé au démarrage
systemctl is-active kubelet && systemctl is-enabled kubelet
```
✅ **Attendu** : `active` puis `enabled`.

```bash
# e) containerd actif + cgroup systemd activé
systemctl is-active containerd
sudo grep SystemdCgroup /etc/containerd/config.toml
```
✅ **Attendu** : `active` et `SystemdCgroup = true`.

```bash
# f) Versions cohérentes (toutes en v1.31.x)
kubelet --version
kubeadm version -o short
```
✅ **Attendu** : `v1.31.14` (la même partout).

---

## 3. node-1 — Control plane

Sur node-1, en plus des vérifications système ci-dessus :

```bash
# Les 6 pods du control plane doivent tourner sur node-1
kubectl get pods -n kube-system -o wide --field-selector spec.nodeName=node-1
```
✅ **Attendu** : `etcd-node-1`, `kube-apiserver-node-1`, `kube-controller-manager-node-1`, `kube-scheduler-node-1`, `kube-proxy-xxxxx`, `calico-node-xxxxx` → tous `1/1 Running`.

```bash
# kubectl bien configuré pour l'utilisateur
ls -l $HOME/.kube/config
```
✅ **Attendu** : le fichier existe (c'est lui qui permet à `kubectl` de marcher).

---

## 4. node-2 — Worker

```bash
# Depuis node-1 : santé détaillée du worker
kubectl describe node ip-10-2-50-190.eu-central-1.compute.internal | grep -A6 "Conditions:"
```
✅ **Attendu** : `Ready = True`, `NetworkUnavailable = False` (CalicoIsUp), et `MemoryPressure / DiskPressure / PIDPressure = False`.

```bash
# Depuis node-1 : rôle correct
kubectl get node ip-10-2-50-190.eu-central-1.compute.internal --show-labels | grep worker
```
✅ **Attendu** : le label `node-role.kubernetes.io/worker=worker` est présent.

```bash
# Depuis node-1 : les pods applicatifs tournent bien sur le worker
kubectl get pods -A -o wide --field-selector spec.nodeName=ip-10-2-50-190.eu-central-1.compute.internal
```
✅ **Attendu** : `calico-node`, `kube-proxy`, `coredns`, et l'application (`laravel-...`, `mysql-0`) → `Running`.

---

## 5. node-3 — Ingress

```bash
# Le contrôleur nginx-ingress doit tourner (sur node-3)
kubectl get pods -n ingress-nginx -o wide
```
✅ **Attendu** : `ingress-nginx-controller-...` → `1/1 Running`, colonne NODE = le nœud ingress (`ip-10-2-50-90...`).

```bash
# Le service expose bien des ports
kubectl get svc -n ingress-nginx
```
✅ **Attendu** : un service `ingress-nginx-controller` avec des ports `80` et `443`.

```bash
# Le label de rôle ingress est posé
kubectl get node ip-10-2-50-90.eu-central-1.compute.internal --show-labels | grep ingress
```
✅ **Attendu** : `node-role.kubernetes.io/ingress=ingress`.

---

## 6. node-4 — Monitoring

```bash
# Toute la stack d'observabilité doit tourner dans le namespace monitoring
kubectl get pods -n monitoring -o wide
```
✅ **Attendu** : `prometheus-...`, `kube-prometheus-grafana-...`, `alertmanager-...`, `loki-...` → `Running`, et `promtail-...` sur **chaque** nœud (DaemonSet).

```bash
# Services exposés
kubectl get svc -n monitoring
```
✅ **Attendu** : services `kube-prometheus-grafana`, `kube-prometheus-prometheus`, `loki`, etc.

```bash
# Vérifier que Promtail tourne sur les 4 nœuds (1 par nœud)
kubectl get pods -n monitoring -o wide | grep promtail
```
✅ **Attendu** : autant de pods `promtail` que de nœuds (4), chacun sur un nœud différent.

```bash
# Le label de rôle monitoring est posé
kubectl get node ip-10-2-50-113.eu-central-1.compute.internal --show-labels | grep monitoring
```
✅ **Attendu** : `node-role.kubernetes.io/monitoring=monitoring`.

---

## 7. (Bonus) Dashboard Kubernetes

```bash
kubectl get pods -n kubernetes-dashboard
```
✅ **Attendu** : `kubernetes-dashboard-...` et `dashboard-metrics-scraper-...` → `Running`.

---

## Récapitulatif — checklist par nœud

| Vérification | node-1 | node-2 | node-3 | node-4 |
|---|:---:|:---:|:---:|:---:|
| Swap off / modules / sysctl | ☐ | ☐ | ☐ | ☐ |
| kubelet `active` + `enabled` | ☐ | ☐ | ☐ | ☐ |
| containerd + SystemdCgroup | ☐ | ☐ | ☐ | ☐ |
| Statut nœud `Ready` | ☐ | ☐ | ☐ | ☐ |
| Rôle / label correct | control-plane ☐ | worker ☐ | ingress ☐ | monitoring ☐ |
| Pods spécifiques `Running` | control-plane ☐ | app ☐ | nginx-ingress ☐ | prometheus/grafana/loki ☐ |

> **Diagnostic d'un pod en erreur** :
> ```bash
> kubectl describe pod <nom-du-pod> -n <namespace>   # voir les Events en bas
> kubectl logs <nom-du-pod> -n <namespace>           # voir les logs du conteneur
> ```
