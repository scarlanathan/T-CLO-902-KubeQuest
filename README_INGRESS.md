# Déploiement Ingress - Kubernetes AWS

## Qu'est-ce que vous devez faire ?

Votre ticket demande de configurer un contrôleur Ingress pour exposer vos applications Kubernetes. **Bonne nouvelle : tout est déjà configuré !** Vous avez juste à déployer.

## Configuration déjà prête

✅ nginx-ingress controller configuré pour AWS
✅ Application Laravel avec Ingress template
✅ Cert-manager pour HTTPS (SSL/TLS)
✅ LoadBalancer AWS Network Load Balancer
✅ Auto-scaling et monitoring

## Comment réaliser le déploiement

### Option 1 : Script automatisé (RECOMMANDÉ)

```bash
# 1. Se connecter au cluster EKS
aws eks update-kubeconfig --name <nom-cluster> --region eu-central-1

# 2. Exécuter le script de déploiement
./deploy-ingress.sh
```

Le script va :
- ✅ Vérifier les prérequis (kubectl, helm, kustomize)
- ✅ Déployer nginx-ingress controller
- ✅ Déployer cert-manager
- ✅ Déployer l'application Laravel
- ✅ Configurer le hosts local
- ✅ Tester l'accès HTTP/HTTPS

### Option 2 : Déploiement manuel

Suivez le guide détaillé : `GUIDE_INGRESS_DEPLOYMENT.md`

## Vos accès AWS

```
Console AWS : https://649966626926.signin.aws.amazon.com/console
Account ID : 649966626926
Username   : student-frankfurt-group-50
Password   : JioPoulet98/
Région     : eu-central-1 (Francfurt)

EC2 Instances : https://eu-central-1.console.aws.amazon.com/ec2/home?region=eu-central-1#Instances:search=:group-50
```

## Architecture du déploiement

```
Internet
   ↓
AWS Network Load Balancer (NLB)
   ↓
nginx-ingress-controller (2-5 replicas)
   ↓
Laravel Application (3 replicas)
```

## Tests à réaliser après déploiement

### 1. Test HTTP
```bash
curl http://larapp.kubequest.local
```

### 2. Test HTTPS
```bash
curl -k https://larapp.kubequest.local
```

### 3. Test via navigateur
```bash
open http://larapp.kubequest.local
```

## Documentation à créer

Après le déploiement, documentez :

1. **Configuration réseau** :
   - Nom du cluster EKS
   - Adresse du LoadBalancer AWS
   - Configuration Ingress
   - Certificats SSL

2. **Tests réalisés** :
   - Capture d'écran des tests HTTP/HTTPS
   - Résultats des commandes curl
   - Logs des pods

3. **Architecture** :
   - Schéma réseau
   - Configuration des services

Utilisez le template dans `GUIDE_INGRESS_DEPLOYMENT.md` - Section "Étape 6"

## Commandes utiles

```bash
# Vérifier l'état de l'Ingress
kubectl get ingress -A
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 -f

# Vérifier le LoadBalancer
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## Temps de déploiement estimé

- nginx-ingress : 3-5 minutes (création du LoadBalancer AWS)
- cert-manager : 2-3 minutes
- Laravel app : 2-3 minutes
- Certificat SSL : 5-10 minutes (si Let's Encrypt)

**Total : ~15-20 minutes**

## Dépannage

### Le LoadBalancer n'a pas d'adresse externe
- Normal ! AWS prend 2-5 minutes pour créer le NLB
- Attendez et vérifiez avec : `kubectl get svc -n ingress-nginx -w`

### 502 Bad Gateway
- Vérifiez que les pods Laravel sont ready
- `kubectl get pods -n laravel-app`

### Certificat SSL non prêt
- `kubectl get certificate -A`
- `kubectl describe certificate laravel-app-tls -n laravel-app`

## Ressources

- **Guide détaillé** : `GUIDE_INGRESS_DEPLOYMENT.md`
- **Script de déploiement** : `deploy-ingress.sh`
- **Configuration nginx-ingress** : `kubequest-cluster/gitops/infrastructure/base/nginx-ingress/`
- **Configuration Laravel** : `kubequest-cluster/laravel-app/`

## Checklist de validation

- [ ] kubectl connecté au cluster EKS
- [ ] Script exécuté avec succès
- [ ] LoadBalancer AWS créé (EXTERNAL-IP visible)
- [ ] nginx-ingress pods ready
- [ ] Laravel pods ready
- [ ] Test HTTP fonctionnel
- [ ] Test HTTPS fonctionnel
- [ ] Documentation complétée
- [ ] Captures d'écran réalisées

---

**Besoin d'aide ?**

Consultez le fichier `GUIDE_INGRESS_DEPLOYMENT.md` pour plus de détails sur chaque étape.
