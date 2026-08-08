# Structure du Projet KubeQuest

Vue d'ensemble complète de l'arborescence du projet.

## 📁 Arborescence Complète

```
kubequest-cluster/
│
├── 📄 README.md                      # Documentation principale
├── 📄 DEPLOYMENT.md                  # Guide de déploiement pour la défense
├── 📄 STRUCTURE.md                   # Ce fichier
├── 📄 .gitignore                     # Fichiers à ignorer par Git
│
├── 📁 laravel-app/                   # Chart Helm Application Laravel
│   ├── 📄 Chart.yaml                 # Définition du chart + dépendances
│   ├── 📄 values.yaml                # Configuration complète
│   └── 📁 templates/
│       ├── 📄 configmap.yaml         # Configuration Laravel (.env)
│       ├── 📄 secret.yaml            # Secrets sensibles
│       ├── 📄 pvc.yaml               # PVC pour storage Laravel
│       ├── 📄 backup-cronjob.yaml    # Backups automatiques PostgreSQL
│       ├── 📄 servicemonitor.yaml    # ServiceMonitor Prometheus
│       ├── 📄 pdb.yaml               # PodDisruptionBudget
│       ├── 📄 deployment.yaml        # Déploiement Laravel
│       ├── 📄 service.yaml           # Service ClusterIP
│       ├── 📄 ingress.yaml           # Ingress nginx
│       ├── 📄 hpa.yaml               # Horizontal Pod Autoscaler
│       ├── 📄 serviceaccount.yaml    # ServiceAccount
│       ├── 📄 httproute.yaml         # HTTPRoute Gateway API
│       └── 📁 tests/
│           └── 📄 test-connection.yaml
│
├── 📁 gitops/                        # Répertoire GitOps
│   └── 📁 infrastructure/            # Manifests infrastructure
│       └── 📁 base/
│           ├── 📄 kustomization.yaml # Kustomisation racine
│           │
│           ├── 📁 nginx-ingress/     # Load Balancer
│           │   ├── 📄 kustomization.yaml
│           │   ├── 📄 namespace.yaml
│           │   └── 📄 values.yaml
│           │
│           ├── 📁 cert-manager/      # Certificats SSL
│           │   ├── 📄 kustomization.yaml
│           │   ├── 📄 namespace.yaml
│           │   ├── 📄 values.yaml
│           │   └── 📄 cluster-issuer.yaml
│           │
│           ├── 📁 kubernetes-dashboard/  # Dashboard
│           │   ├── 📄 kustomization.yaml
│           │   ├── 📄 namespace.yaml
│           │   ├── 📄 values.yaml
│           │   ├── 📄 admin-user.yaml
│           │   └── 📄 ingress.yaml
│           │
│           ├── 📁 monitoring/        # Prometheus + Grafana
│           │   ├── 📄 kustomization.yaml
│           │   ├── 📄 namespace.yaml
│           │   ├── 📄 values.yaml
│           │   ├── 📄 ingress-grafana.yaml
│           │   └── 📄 ingress-prometheus.yaml
│           │
│           ├── 📁 logging/           # Loki + Promtail
│           │   ├── 📄 kustomization.yaml
│           │   ├── 📄 namespace.yaml
│           │   ├── 📄 values.yaml
│           │   ├── 📄 ingress-loki.yaml
│           │   └── 📄 ingress-grafana.yaml
│           │
│           └── 📁 security/          # OPA Validating Webhook
│               ├── 📄 kustomization.yaml
│               ├── 📄 namespace.yaml
│               ├── 📄 deployment.yaml
│               ├── 📄 service.yaml
│               ├── 📄 configmap.yaml    # Politiques OPA
│               ├── 📄 webhook-configuration.yaml
│               └── 📄 rbac.yaml
│
│   └── 📁 apps/                      # Manifests applications
│       └── 📁 laravel-app/
│           ├── 📁 base/               # Configuration de base
│           │   ├── 📄 kustomization.yaml
│           │   ├── 📄 namespace.yaml
│           │   └── 📄 values.yaml
│           │
│           └── 📁 overlays/           # Variations d'environnement
│               └── 📁 production/
│                   ├── 📄 kustomization.yaml
│                   └── 📄 production-patch.yaml
│
├── 📁 scripts/                       # Scripts d'automatisation
│   ├── 🔧 deploy-infrastructure.sh   # Déploiement infrastructure
│   ├── 🔧 deploy-app.sh              # Déploiement application
│   ├── 🔧 health-check.sh            # Vérification santé
│   ├── 🧪 load-test.sh               # Test de charge (autoscaling)
│   ├── 🧪 rollback-demo.sh           # Démonstration rollback
│   └── 🧹 cleanup.sh                 # Nettoyage infrastructure
│
└── 📁 kind.yaml                      # Configuration Kind (optionnel)
```

## 📊 Statistiques du Projet

### Fichiers par catégorie

| Catégorie | Nombre de fichiers |
|-----------|-------------------|
| Helm Charts | 1 principal + 10 templates |
| GitOps Infrastructure | 30+ manifests |
| GitOps Applications | 5+ manifests |
| Scripts | 6 scripts |
| Documentation | 4 fichiers |
| **Total** | **56+ fichiers** |

### Composants déployés

1. **Infrastructure (6 composants)**
   - nginx-ingress
   - cert-manager
   - kubernetes-dashboard
   - kube-prometheus (Prometheus, Grafana, Alertmanager)
   - Loki (Loki, Promtail, Grafana)
   - OPA (Validating Webhook)

2. **Application (1 composant)**
   - Laravel App (avec PostgreSQL)

### Bonnes pratiques implémentées

- ✅ Resources limits et requests
- ✅ Secrets pour données sensibles
- ✅ Labels Kubernetes standards
- ✅ Redondance (replicas + anti-affinity)
- ✅ Stockage persistant
- ✅ Liveness/Readiness probes
- ✅ Auto-scaling (HPA)
- ✅ Sécurité (OPA, Security Contexts)
- ✅ Backups automatiques
- ✅ Monitoring (Prometheus, Grafana)
- ✅ Logging (Loki)
- ✅ Certificats SSL automatiques
- ✅ GitOps (Kustomize)
- ✅ Zero-downtime deployments

## 🎯 Points clés du projet

### Architecture

- **GitOps** : Tout est géré via Git et Kustomize
- **Helm** : Pour les applications complexes (Laravel, PostgreSQL)
- **Kustomize** : Pour l'infrastructure et les variations d'environnement
- **Ingress** : nginx-ingress comme load balancer unique
- **Namespaces** : Séparation claire des préoccupations

### Sécurité

- **OPA** : Validation des ressources Kubernetes
- **RBAC** : Contrôle d'accès basé sur les rôles
- **Security Contexts** : Non-root, read-only filesystem
- **Secrets** : Jamais stockés en clair dans Git
- **TLS** : Certificats automatiques avec Let's Encrypt

### Observabilité

- **Prometheus** : Métriques système et applicatives
- **Grafana** : Dashboards de visualisation (2 instances)
- **Loki** : Logs centralisés
- **Alertmanager** : Gestion des alertes

### Scalabilité

- **HPA** : Auto-scaling horizontal automatique
- **Anti-affinity** : Distribution des pods
- **PDB** : Protection contre les disruptions
- **Resources** : Limits et requests configurés

### Résilience

- **Replicas** : Minimum 2-3 pour tous les composants
- **Probes** : Liveness et readiness
- **Rollback** : Rollback automatique en cas de problème
- **Backups** : Backups automatiques quotidiens

## 📝 Notes importantes

### Configuration requise pour la défense

1. **Cluster Kubernetes** : 2 nodes minimum
2. **Outils** : kubectl, helm, kustomize
3. **Temps de déploiement** : ~20-30 minutes
4. **Espace disque** : ~100GB pour tous les PVCs

### Modifications avant la défense

1. ✅ Mettre à jour les URLs des ingress avec votre domaine
2. ✅ Configurer les credentials AWS pour le Load Balancer
3. ✅ Mettre à jour l'image Docker de l'application Laravel
4. ✅ Configurer les credentials Let's Encrypt
5. ✅ Ajuster les valeurs de resources selon votre cluster

### Commandes essentielles

```bash
# Déploiement complet
./scripts/deploy-infrastructure.sh && ./scripts/deploy-app.sh

# Vérification
./scripts/health-check.sh

# Tests
./scripts/load-test.sh
./scripts/rollback-demo.sh

# Nettoyage
./scripts/cleanup.sh
```

## 🏆 Points forts du projet

1. **Complétude** : Tous les composants demandés dans le sujet
2. **Bonne pratique** : Respect des standards Kubernetes
3. **Automatisation** : Scripts de déploiement et de tests
4. **Documentation** : README et guide de déploiement détaillés
5. **Démo-ready** : Scripts pour démontrer l'autoscaling et le rollback
6. **GitOps** : Approche moderne de gestion de l'infrastructure
7. **Sécurité** : OPA, RBAC, Secrets, TLS
8. **Observabilité** : Monitoring complet avec Prometheus et Grafana
9. **Logging** : Centralisation des logs avec Loki
10. **Scalabilité** : HPA, anti-affinity, resources bien configurées

## 📚 Références

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)

---

**Projet** : KubeQuest
**Auteur** : Équipe KubeQuest
**Version** : 1.0.0
**Date** : 2026
