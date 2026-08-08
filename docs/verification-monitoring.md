# Vérification de bout en bout — Stack de monitoring

> **But :** prouver, commande par commande, que l'observabilité fonctionne
> réellement (et pas seulement que les manifestes existent) — indispensable
> avant la keynote où l'infra sera « mise à rude épreuve ».
>
> Composants (cf. `kubequest-cluster/gitops/infrastructure/base/`) :
> - **monitoring** (ns `monitoring`) : `kube-prometheus-stack` v55, release `prometheus`
>   → Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics
> - **logging** (ns `logging`) : `loki-stack`, release `loki` → Loki + Promtail

---

## 0. Pré-requis

```bash
kubectl get ns monitoring logging
kubectl -n monitoring get pods
kubectl -n logging     get pods
```
✅ *Attendu :* tous les pods `Running`/`Completed`, aucun `CrashLoopBackOff`.

---

## 1. Prometheus est up et scrape ses cibles

```bash
# Port-forward de l'UI Prometheus
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
```
Puis dans le navigateur → <http://localhost:9090/targets> :

- ✅ Les cibles `node-exporter`, `kube-state-metrics`, `kubelet`, `apiserver` sont **UP**.
- ✅ Requête test dans <http://localhost:9090/graph> : `up` renvoie une série par cible.
- ✅ `count(kube_node_info)` doit renvoyer **4** (les 4 nœuds).

Sans navigateur (API) :
```bash
curl -s localhost:9090/api/v1/query?query=up | grep -o '"value"' | wc -l   # nb de cibles
```

---

## 2. L'application est bien scrapée

L'app est annotée pour le scrape (`prometheus.io/scrape=true`, port `9000`, `/metrics`)
et un `ServiceMonitor` est fourni (`kubequest-cluster/laravel-app/templates/servicemonitor.yaml`).

```bash
kubectl get servicemonitor -A | grep -i laravel
```
Dans Prometheus → *Status ▸ Targets* : chercher la cible `laravel-app`.

> ⚠️ **Point d'attention :** l'app Laravel (compteur) n'expose pas nativement
> `/metrics`. Si la cible est `DOWN` avec 404, il faut ajouter un exporter
> (ex. `laravel-prometheus`, ou un sidecar `apache-exporter` / `php-fpm-exporter`).
> À trancher avant la keynote si l'on veut des métriques applicatives.

---

## 3. Grafana : accès + dashboards + datasources

```bash
kubectl -n monitoring port-forward svc/prometheus-grafana 3000:80
```
→ <http://localhost:3000> (admin / mot de passe :) :
```bash
kubectl -n monitoring get secret prometheus-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

- ✅ *Configuration ▸ Data sources* : **Prometheus** et **Loki** présents et « Test » OK.
- ✅ *Dashboards* : les dashboards kube-prometheus-stack (Node Exporter / Full,
  Kubernetes / Compute Resources / Cluster) affichent des courbes non vides.
- ✅ Le dashboard « Nodes » montre bien **4 nœuds**.

---

## 4. Alertmanager : les alertes fonctionnent

```bash
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093
# Règles chargées :
kubectl -n monitoring get prometheusrule
```
- ✅ <http://localhost:9093> est accessible.
- ✅ Les règles de `production-ready/04-alerting-rules.yaml` apparaissent dans
  Prometheus → *Alerts*.
- ✅ **Test réel** : déclencher une alerte en tuant/chargeant un composant
  (voir `keynote-chaos-demo.sh`) et vérifier qu'elle passe `Pending` → `Firing`.

---

## 5. Loki : les logs remontent

```bash
kubectl -n logging get ds        # promtail = 1 pod par nœud (DaemonSet -> 4)
kubectl -n logging port-forward svc/loki 3100:3100
```
Dans Grafana → *Explore* ▸ datasource **Loki** :
- ✅ Requête `{namespace="default"}` renvoie des lignes de logs de l'app.
- ✅ `{namespace="monitoring"}` renvoie des logs → agrégation multi-namespace OK.

---

## 6. Accès via Ingress (si DNS/hosts configurés)

Hosts définis dans les ingress : ajouter au `/etc/hosts` (cf. `production-ready/etchosts-addition.txt`) :
```
grafana.kubequest.local  prometheus.kubequest.local  logs.kubequest.local  loki.kubequest.local
```
- ✅ `https://grafana.kubequest.local` répond (TLS via cert-manager).

---

## Checklist keynote (résumé à cocher)

- [ ] 4 nœuds visibles dans Grafana (dashboard Nodes)
- [ ] Cibles Prometheus toutes UP (dont l'app, ou exporter en place)
- [ ] Dashboards CPU/mémoire/réseau peuplés
- [ ] Une alerte a été vue passer en `Firing` pendant un scénario de chaos
- [ ] Logs applicatifs visibles dans Loki via Grafana Explore
- [ ] Le scénario `keynote-chaos-demo.sh` se lit en direct sur les dashboards
