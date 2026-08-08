# Schéma d'architecture — KubeQuest Groupe 50

> **Objectif :** un schéma clair que **chaque membre** doit savoir expliquer et présenter.
> Il décrit le cluster Kubernetes déployé sur 4 nœuds AWS EC2 (`eu-central-1`), le chemin
> d'une requête HTTP depuis Internet et le chemin d'une métrique/log jusqu'à Grafana.

---

## 1. Vue d'ensemble du cluster

```mermaid
flowchart TB
    User([🌐 Internet / Utilisateurs])
    Admin([👩‍💻 Équipe Groupe 50<br/>SSH + kubectl])

    subgraph AWS["☁️ AWS eu-central-1 · VPC Groupe 50 · 10.2.50.0/24"]
        direction TB

        subgraph N1["🧠 node-1 — Control Plane · 10.2.50.23"]
            API[kube-apiserver]
            ETCD[(etcd<br/>état du cluster)]
            SCHED[scheduler]
            CM[controller-manager]
            DASH[kubernetes-dashboard]
            HELM[Helm]
        end

        subgraph N3["🚪 node-3 — Ingress · 10.2.50.90"]
            INGRESS[nginx-ingress<br/>controller]
        end

        subgraph N2["⚙️ node-2 — Worker · 10.2.50.190"]
            APP[Pod Laravel<br/>app web]
            DB[(Pod mysql-0<br/>+ Persistent Volume)]
        end

        subgraph N4["📊 node-4 — Monitoring · 10.2.50.113"]
            PROM[Prometheus<br/>métriques]
            GRAF[Grafana<br/>dashboards]
            ALERT[Alertmanager]
            LOKI[Loki<br/>logs]
        end

        PT[Promtail · DaemonSet sur les 4 nœuds]
    end

    %% Flux du trafic applicatif
    User -->|HTTP / HTTPS| INGRESS
    INGRESS -->|route vers le Service| APP
    APP -->|requêtes SQL| DB

    %% Flux d'observabilité
    APP -. métriques .-> PROM
    PT  -. logs .-> LOKI
    PROM --> GRAF
    LOKI --> GRAF
    PROM --> ALERT

    %% Administration
    Admin -->|SSH ec2-user| N1
    Admin -->|kubectl / dashboard| API

    %% Le control plane orchestre tous les workers
    API -. orchestre .-> N2
    API -. orchestre .-> N3
    API -. orchestre .-> N4

    classDef cp fill:#326ce5,stroke:#fff,color:#fff
    classDef mon fill:#e6522c,stroke:#fff,color:#fff
    classDef app fill:#2e7d32,stroke:#fff,color:#fff
    class API,ETCD,SCHED,CM,DASH,HELM cp
    class PROM,GRAF,ALERT,LOKI,PT mon
    class APP,DB,INGRESS app
```

> Bleu = control plane (le « cerveau ») · Vert = trafic applicatif · Orange = observabilité.

---

## 2. Le réseau (CNI Calico)

- **CNI : Calico** — gère le réseau des pods (`--pod-network-cidr 192.168.0.0/16`) et permet
  la communication inter-pods **entre les 4 nœuds**.
- Les nœuds communiquent en interne via leurs **IP privées** (`10.2.50.x`, **stables**).
- Les **IP publiques** ne servent qu'à l'accès **SSH / admin** et **changent au redémarrage**.
- L'API server écoute sur `10.2.50.23:6443` ; les workers l'ont rejoint via `kubeadm join`.

```mermaid
flowchart LR
    subgraph cluster["Réseau du cluster"]
        direction LR
        n1["node-1<br/>10.2.50.23"]
        n2["node-2<br/>10.2.50.190"]
        n3["node-3<br/>10.2.50.90"]
        n4["node-4<br/>10.2.50.113"]
    end
    n1 <-->|Calico · 192.168.0.0/16| n2
    n1 <--> n3
    n1 <--> n4
    n2 <--> n3
    n2 <--> n4
    n3 <--> n4
```

---

## 3. Les deux flux à savoir raconter

### 🔵 Flux d'une requête HTTP (de l'utilisateur au pod)
```
Internet → nginx-ingress (node-3) → Service Kubernetes → Pod Laravel (node-2) → MySQL (node-2)
```

### 🟠 Flux d'observabilité (métrique / log jusqu'à Grafana)
```
Pods           → Prometheus (scrape des métriques, node-4) ┐
Promtail (DS)  → Loki (agrégation des logs, node-4)        ┴→ Grafana (visualisation, node-4)
                                                            Prometheus → Alertmanager (alertes)
```

---

## 4. Rôle de chaque nœud (à expliquer en soutenance)

| Nœud | Rôle | Composants | À pouvoir dire |
|------|------|------------|----------------|
| **node-1** | Control Plane | apiserver, etcd, scheduler, controller-manager, dashboard, Helm | Le « cerveau » : décide où tournent les pods et stocke l'état du cluster dans etcd |
| **node-2** | Worker | Pod Laravel + Pod MySQL (PV) | Exécute l'application ; MySQL a un volume persistant pour garder les données |
| **node-3** | Ingress | nginx-ingress controller | Point d'entrée **unique** du trafic externe → route vers les services internes |
| **node-4** | Monitoring | Prometheus, Grafana, Alertmanager, Loki | Observabilité : métriques, dashboards, alertes, logs |
| **tous** | — | Promtail (DaemonSet), Calico, kubelet | Promtail envoie les logs ; Calico relie les pods ; kubelet pilote les conteneurs |

### Notions transverses
| Élément | À pouvoir expliquer |
|---------|---------------------|
| **Labels / nodeSelector** | Comment on cible un nœud précis pour un déploiement (`node-role.kubernetes.io/...`) |
| **Helm** | Gestionnaire de paquets K8s — Laravel, ingress, monitoring installés via charts |
| **Namespaces** | `kube-system`, `ingress-nginx`, `monitoring`, `kubernetes-dashboard`, app |
| **Secrets / PV** | Credentials (DB_PASSWORD, APP_KEY) et stockage persistant de MySQL |

> **Conseil de soutenance :** chaque membre doit pouvoir **redessiner ce schéma au tableau de
> mémoire** et décrire (1) le chemin d'une requête HTTP depuis Internet jusqu'au pod Laravel,
> et (2) le chemin d'une métrique/log jusqu'à Grafana.

---

## 5. Export pour la présentation

Le diagramme est en **Mermaid** (rendu automatiquement sur GitHub/GitLab et VS Code avec
l'extension Mermaid). Pour l'exporter en image (PNG/PDF) :

- **En ligne :** copier le bloc ```mermaid``` dans <https://mermaid.live> → *Export PNG/SVG*.
- **VS Code :** extension *Markdown Preview Mermaid Support* → clic droit sur l'aperçu → exporter.
- **CLI :** `npx @mermaid-js/mermaid-cli -i docs/schema-architecture.md -o schema.png`
