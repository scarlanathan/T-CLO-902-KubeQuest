# Audit de sécurité — Application PHP (Laravel) + chaîne de déploiement

**Projet :** KubeQuest (Epitech T-CLO-902) — Groupe 50
**Périmètre :** application Laravel `app-master/` (code, configuration, Dockerfile, docker-compose) et les manifestes de déploiement associés (`helm/`, `kubequest-cluster/`).
**Méthodologie :** revue multi-axes (secrets, divulgation/debug, injection, contrôle d'accès/CSRF/CORS, XSS, durcissement conteneur, CVE des dépendances) avec **vérification contradictoire** de chaque constat. **Tous les CVE cités ont été vérifiés en ligne sur des sources autoritatives (NVD / GitHub Security Advisory / PHP) — les liens figurent au §2.**

> ⚠️ Ce document décrit les emplacements des secrets sans recopier leurs valeurs réelles. Les valeurs concernées sont présentes dans le dépôt et doivent être **purgées puis renouvelées** (voir §A et §B).

---

## 1. Synthèse

**37 constats candidats → 23 confirmés → 18 problèmes distincts (après dédoublonnage)** ; 14 pistes écartées (faux positifs ou déjà mitigées).

| Sévérité (ajustée) | Nombre |
|--------------------|--------|
| **High** | 1 |
| **Medium** | 6 |
| **Low** | 9 |
| **Info** | 2 |

**Constat global :** l'application elle-même (un simple compteur, sans authentification ni entrée utilisateur) a une surface d'attaque applicative très faible. Les risques se concentrent sur **l'hygiène des secrets** (identifiants en clair dans le dépôt) et **l'obsolescence** (framework en fin de vie).

---

## 2. CVE — vérifiés en ligne (avec liens)

| CVE | Composant | Version en place | Statut projet | CVSS | Sources autoritatives |
|-----|-----------|------------------|---------------|------|-----------------------|
| **CVE-2024-52301** | `laravel/framework` | v8.83.27 | **Vulnérable** (< 8.83.28) → **mitigé** (voir §6) | 8.7 (v4) / 7.5 (v3.1) HIGH | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2024-52301) · [GHSA-gv7v-rgg6-548h](https://github.com/laravel/framework/security/advisories/GHSA-gv7v-rgg6-548h) |
| CVE-2023-3824 | PHP (image `php:8.2.8`) | 8.2.8 | **NON applicable** — corrigé **en 8.2.8** (affecté : 8.2.0–8.2.7) | 9.8 CRIT | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2023-3824) |
| CVE-2023-3823 | PHP (image `php:8.2.8`) | 8.2.8 | **NON applicable** — corrigé **en 8.2.8** (affecté : 8.2.0–8.2.7) | 7.5 HIGH | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2023-3823) · [GHSA-3qrf-m4j2-pcrr](https://github.com/php/php-src/security/advisories/GHSA-3qrf-m4j2-pcrr) |
| CVE-2021-3129 | `facade/ignition` | 2.17.7 | **NON applicable** — corrigé en 2.5.2 | 9.8 CRIT | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2021-3129) · [GHSA-4qwp-7c67-jmcc](https://github.com/advisories/GHSA-4qwp-7c67-jmcc) |
| CVE-2018-15133 | Laravel (`APP_KEY`) | 8.x | **NON applicable** — corrigé en 5.6.30 (cookies JSON) | 8.1 HIGH | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2018-15133) |

> 🔎 **Correction importante par rapport à la première passe :** la vérification en ligne montre que `php:8.2.8` **n'est PAS** vulnérable à CVE-2023-3824 / CVE-2023-3823 (la version corrigée sur la branche 8.2 est précisément **8.2.8**). Le seul CVE confirmé applicable est **CVE-2024-52301**.

> ⛔ **Branche Laravel 8.x sans version « propre » :** même la dernière version 8.x (**8.83.28**) reste signalée par l'outil d'audit Composer comme affectée par d'autres avis non corrigés sur 8.x : [GHSA-78fx-h6xr-vch4](https://github.com/advisories/GHSA-78fx-h6xr-vch4) (CVE-2025-27515), GHSA-crmm-hgp2-wgrp, GHSA-5vg9-5847-vvmq. Seule une **migration majeure** (Laravel 10/11/12) supprime durablement ces risques (voir §F).

---

## 3. Vulnérabilités confirmées

### High

#### A — Identifiants base de données **et mot de passe root MySQL** en clair, committés
- **CWE :** CWE-798 — **Emplacement :** `app-master/docker-compose.yaml:32-33` (compte applicatif), `:45-47` (compte MySQL + **root**)
- **Impact :** quiconque accède au dépôt ou à l'image obtient le compte applicatif **et** le mot de passe root MySQL ; si le port BDD est joignable, contrôle total de l'instance.
- **Remédiation :** retirer les identifiants ; les fournir via `.env` git/docker-ignoré ou Secrets K8s ; mots de passe forts/uniques ; pas de compte root pour l'app ; **roter** les valeurs exposées.

### Medium

#### B — Clé applicative `APP_KEY` valide committée en clair
- **CWE :** CWE-798 — **CVE-2018-15133 : revue, non applicable** (Laravel 8 sérialise les cookies en JSON).
- **Emplacement :** `app-master/docker-compose.yaml:27` (lue par `config/app.php:122`, chiffre AES-256-CBC `:124`).
- **Nuance :** Critical → Medium (la prod K8s utilise une autre clé ; app sans authentification ni chiffrement).
- **Remédiation :** `php artisan key:generate` + rotation ; Secret K8s ; purge de l'historique git ; `.dockerignore`.

#### C — Secrets faibles/placeholders committés dans les `values` Helm/Kustomize
- **CWE :** CWE-1188 — **Emplacement :** `kubequest-cluster/laravel-app/values.yaml:218,220,251-254` ; `helm/values.yaml:25,28-29` ; `helm/templates/secret.yaml:8-9` ; `gitops/.../base/values.yaml:45,47`.
- **Remédiation :** valeurs obligatoires (`{{ required ... }}`) ; sealed-secrets/SOPS/External Secrets ; supprimer les défauts en dur.

#### D — Secrets applicatifs rendus dans un **ConfigMap** (`.env`) au lieu d'un Secret
- **CWE :** CWE-312 — **Emplacement :** `kubequest-cluster/laravel-app/templates/configmap.yaml:11,24,34,41` (monté en `.env` via `values.yaml:176-178`).
- **Remédiation :** ne garder que la config non sensible dans le ConfigMap ; injecter les secrets via le `Secret` (`envFrom.secretRef`) ; chiffrement-at-rest + RBAC.

#### E — CVE-2024-52301 : manipulation de l'environnement via la query string ✅ *mitigé*
- **CWE :** CWE-915 / CWE-88 — **CVE-2024-52301** ([NVD](https://nvd.nist.gov/vuln/detail/CVE-2024-52301), [GHSA-gv7v-rgg6-548h](https://github.com/laravel/framework/security/advisories/GHSA-gv7v-rgg6-548h)) — CVSS 8.7 (v4) HIGH.
- **Emplacement :** `app-master/composer.lock` (`laravel/framework` v8.83.27) ; `composer.json:11` (`^8.75`).
- **Description :** avec `register_argc_argv=On` (défaut de l'image `php:8.2.8-apache`, aucun `php.ini` custom), une query string permet de surcharger l'`APP_ENV` détecté sur un SAPI non-CLI. Corrigé côté framework en 8.83.28.
- **Correctif appliqué (voir §6) :** `register_argc_argv = Off` dans l'image PHP → la condition d'exploitation est supprimée. *(Le passage à 8.83.28 n'est pas retenu seul : la branche 8.x est EOL et 8.83.28 reste affectée par d'autres avis — la migration majeure est la cible durable.)*

#### F — `laravel/framework` 8.x (8.83.27) en fin de vie, sans support sécurité
- **CWE :** CWE-1104 — OWASP A06:2021 — **Emplacement :** `app-master/composer.json:11` ; `composer.lock`.
- **Description :** Laravel 8 ne reçoit plus de correctifs depuis janvier 2023. **Vérifié :** même la dernière 8.x (8.83.28) reste signalée affectée par [GHSA-78fx-h6xr-vch4](https://github.com/advisories/GHSA-78fx-h6xr-vch4) (CVE-2025-27515), GHSA-crmm-hgp2-wgrp et GHSA-5vg9-5847-vvmq.
- **Remédiation :** **migrer vers Laravel 10/11/12** sur PHP supporté ; `composer audit` / Dependabot en CI.

#### G — Dépendances de **dev** embarquées dans l'image de production
- **CWE :** CWE-489 — **CVE-2021-3129 : revue, non exploitable** (`facade/ignition` 2.17.7 ≥ 2.5.2 — [NVD](https://nvd.nist.gov/vuln/detail/CVE-2021-3129)).
- **Emplacement :** `app-master/Dockerfile:16` (`RUN composer install` sans `--no-dev`).
- **Remédiation :** `composer install --no-dev --optimize-autoloader` (build multi-étapes) ; `APP_DEBUG=false` partout.

### Low

| ID | Problème | CWE | Emplacement | Remédiation (résumé) |
|----|----------|-----|-------------|----------------------|
| H | Apache exécuté **en root** (aucun `USER`) | CWE-250 | `app-master/Dockerfile` | `USER 1000`, port non privilégié, aligner sur `runAsUser:1000` |
| I | Absence de `.dockerignore` (COPY . embarque compose/secrets/sources) | CWE-538 | `app-master/Dockerfile:13` | Ajouter `.dockerignore` |
| J | Dépendances `facade/*` (Ignition/Flare) abandonnées | CWE-1104 | `app-master/composer.lock` | Migrer vers `spatie/laravel-ignition` (dev only) |
| K | Endpoint **GET non authentifié mutant l'état** `/api/counter/add` (+ CSRF) | CWE-306 / CWE-352 | `app-master/routes/api.php:19` | `POST`, idempotent, `Cache-Control: no-store` |
| L | `securityContext` Helm **incompatible** avec l'image (CrashLoop probable) | CWE-693 | `kubequest-cluster/laravel-app/values.yaml:46-59` | Aligner image ↔ chart (port, user, tmpfs) |
| M | Rate limiter keyé sur une IP non fiable (`TrustProxies` non configuré) | CWE-770 / CWE-348 | `app-master/app/Http/Middleware/TrustProxies.php:15` | `$proxies` = CIDR ingress (jamais `*`) |
| N | Incohérence de port : image **80** vs Deployment/probes **9000** | CWE-440 | `kubequest-cluster/laravel-app/values.yaml:65` | Faire coïncider port d'écoute et `targetPort` |
| O | Build mono-étage conservant `git`/`unzip`/`p7zip`/`composer` dans l'image | CWE-1104 | `app-master/Dockerfile:7-10` | Build multi-étapes, image runtime minimale |
| P | Image PHP figée sur un patch ancien (`php:8.2.8`, juin 2023) sans cadence de reconstruction | CWE-1104 | `app-master/Dockerfile:2` | Suivre les patchs 8.2.x récents ; scan d'images (Trivy/Grype). *(Aucun CVE confirmé applicable à 8.2.8 — cf. §2.)* |

### Info

| ID | Problème | CWE | Emplacement | Remédiation (résumé) |
|----|----------|-----|-------------|----------------------|
| Q | CORS permissif (`origins`/`methods`/`headers` en wildcard) | CWE-942 | `app-master/config/cors.php:20-26` | Liste blanche d'origines ; `supports_credentials` reste `false` (impact actuel nul) |
| R | `welcome.blade.php` sans DOCTYPE/charset/CSP (défense en profondeur) | CWE-1021 | `app-master/resources/views/welcome.blade.php:1-2` | Ajouter DOCTYPE, charset, en-tête CSP |

---

## 4. Pistes vérifiées puis **écartées** (faux positifs / non applicables)

| Piste | Verdict (vérifié) |
|-------|-------------------|
| **CVE-2023-3824** (PHP Phar, RCE) | **Non applicable** : corrigé en 8.2.8, or l'image est en 8.2.8. |
| **CVE-2023-3823** (PHP XXE) | **Non applicable** : corrigé en 8.2.8. |
| **CVE-2021-3129** (RCE Ignition) | **Non exploitable** : `facade/ignition` 2.17.7 ≥ 2.5.2. |
| **CVE-2018-15133** (RCE via `APP_KEY`) | **Non applicable** : corrigé en Laravel 5.6.30 (cookies JSON). |
| `APP_DEBUG=true` en prod | **Écarté** côté production (K8s force `APP_DEBUG=false`) ; concerne seulement `docker-compose` (dev local). |
| XSS dans `welcome.blade.php` (`{{ $value }}`) | **Pas de XSS** : entier serveur auto-échappé ; `jQuery.text()` sûr ; CDN jQuery avec SRI. |
| Injection SQL / mass-assignment | **Aucune** : pas d'entrée utilisateur atteignant un sink ; `User` model correct. |
| `guzzle ^7.0.1`, `minimum-stability: dev`, Host header | Écartés (pas de surface d'attaque réelle démontrée). |

---

## 5. Priorisation des corrections

- **P0 — Immédiat (secrets) :** purger `docker-compose.yaml` + **roter** ; `.dockerignore` ; secrets via **Secrets K8s**. *(A, B, C, D, I)*
- **P1 — Court terme :** `composer install --no-dev` (build multi-étapes) ; **migrer Laravel** vers une version supportée. *(E, F, G, O, P)*
- **P2 — Durcissement runtime :** `USER 1000` ; cohérence port 80/9000 ; `TrustProxies` ; `POST` + auth pour `/counter/add` ; restreindre le CORS. *(H, K, L, M, N, Q)*
- **P3 — Défense en profondeur :** en-têtes / CSP ; nettoyage de l'outillage de build. *(J, R)*

---

## 6. Correctifs appliqués dans ce dépôt

| Date | CVE | Fichier modifié | Correctif |
|------|-----|-----------------|-----------|
| 2026-06-30 | **CVE-2024-52301** | `app-master/Dockerfile` | Ajout de `register_argc_argv = Off` (`$PHP_INI_DIR/conf.d/zz-hardening.ini`) → supprime la condition d'exploitation du CVE. |

> Recommandation de suivi : planifier la **migration Laravel** (la branche 8.x restant affectée par d'autres avis) et la purge/rotation des secrets (P0).
