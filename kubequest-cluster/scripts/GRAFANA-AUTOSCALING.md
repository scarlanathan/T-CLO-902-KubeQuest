# 📊 Voir l'autoscaling dans Grafana

Comment rendre le test HPA (`hpa-load.sh`) **visible en direct dans Grafana** pendant la soutenance.

---

## 1. Le déroulé de la démo (2 terminaux + Grafana)

| Terminal 1 (charge) | Terminal 2 (observation) | Grafana |
|---|---|---|
| `./hpa-load.sh start` | `./hpa-watch.sh` | dashboard ouvert (ci-dessous) |
| … laisser tourner 1-2 min … | on voit `2 → … → 10` | la courbe de pods grimpe |
| `./hpa-load.sh stop` | on voit redescendre | scale-down après ~3-5 min |

> Les deux scripts sont dans `kubequest-cluster/scripts/`, à lancer sur **node-1**.

---

## 2. Option A — Dashboards déjà présents (kube-prometheus-stack)

La stack embarque des dashboards prêts. Les plus parlants :

- **Kubernetes / Compute Resources / Namespace (Pods)**
  → variable `namespace = laravel-app-prod`.
  On voit la **conso CPU par pod** grimper, et **de nouveaux pods apparaître** dans la légende.

- **Kubernetes / Compute Resources / Workload**
  → `namespace = laravel-app-prod`, `workload = laravel-app`, `type = deployment`.
  Vue agrégée par workload : CPU, mémoire, réseau.

C'est suffisant pour la démo, mais le nombre de replicas n'y est pas mis en avant. Pour un
visuel « autoscaling » net, crée le panneau dédié ci-dessous.

---

## 3. Option B — Un panneau dédié « Autoscaling » (recommandé)

Dans Grafana : **+ → New dashboard → Add visualization → source Prometheus**, puis crée
2 panneaux avec ces requêtes (PromQL).

### Panneau 1 — « Pods : courant vs souhaité vs max » (type *Time series*)

```promql
# replicas actuellement actifs
kube_horizontalpodautoscaler_status_current_replicas{namespace="laravel-app-prod", horizontalpodautoscaler="laravel-app"}
```
```promql
# replicas souhaités par le HPA
kube_horizontalpodautoscaler_status_desired_replicas{namespace="laravel-app-prod", horizontalpodautoscaler="laravel-app"}
```
```promql
# plafond (maxReplicas = 10) — ligne de référence
kube_horizontalpodautoscaler_spec_max_replicas{namespace="laravel-app-prod", horizontalpodautoscaler="laravel-app"}
```
```promql
# pods réellement prêts
kube_deployment_status_replicas_ready{namespace="laravel-app-prod", deployment="laravel-app"}
```
Légendes suggérées : `courant`, `souhaité`, `max`, `prêts`. Axe Y min = 0.

### Panneau 2 — « CPU de l'app vs seuil 70% » (type *Time series*, unité `percent`)

```promql
# utilisation CPU moyenne des pods de l'app, en % des requests (ce que regarde le HPA)
100 *
  sum(rate(container_cpu_usage_seconds_total{namespace="laravel-app-prod", pod=~"laravel-app-.*", container!=""}[1m]))
  /
  sum(kube_pod_container_resource_requests{namespace="laravel-app-prod", pod=~"laravel-app-.*", resource="cpu"})
```
```promql
# la cible du HPA (70) — ligne horizontale de référence
70
```
Quand la 1re courbe dépasse **70**, le HPA ajoute des pods → visible dans le panneau 1.

> 💡 Ajoute la variable de dashboard `namespace` si tu veux réutiliser le panneau ailleurs,
> mais en soutenance le plus simple est de figer `laravel-app-prod`.

---

## 4. Le récit à tenir devant le jury

1. « Voici l'app au repos : **2 pods**, CPU sous les 70 %. »
2. `./hpa-load.sh start` → « on injecte ~36 flux de requêtes en continu, **depuis le cluster**. »
3. Grafana : « le CPU franchit **70 %** (panneau 2) → le HPA passe la consigne à plus de pods
   (panneau 1) → Kubernetes crée les pods, le scheduler les répartit sur les nœuds. »
4. « On plafonne à **10 pods** (le `maxReplicas`) : la protection joue, ça ne scale pas à l'infini. »
5. `./hpa-load.sh stop` → « la charge tombe, et après la fenêtre de stabilisation le cluster
   **revient à 2 pods** — on ne gaspille pas de ressources. »

---

## 5. Pré-requis (déjà vérifiés sur le cluster)

- ✅ `metrics-server` en marche (le HPA lit le CPU via lui — `kubectl top` fonctionne).
- ✅ HPA `laravel-app` : cible **CPU 70 %**, **min 2 / max 10**.
- ✅ Service joignable en interne : `http://laravel-app.laravel-app-prod.svc.cluster.local/`.
- ✅ Générateur conforme à **OPA/Gatekeeper** (label `app.kubernetes.io/name`, resources, non-root).
- ✅ `kube-state-metrics` (fournit les métriques `kube_horizontalpodautoscaler_*`) : inclus dans kube-prometheus-stack.
