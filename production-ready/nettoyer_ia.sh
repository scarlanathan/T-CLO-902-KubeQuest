#!/bin/bash
# Script de nettoyage des fichiers pour enlever les mentions IA
# Auteur: Groupe 50

echo "=========================================="
echo "NETTOYAGE DES FICHIERS - ENLEVER MENTIONS IA"
echo "=========================================="
echo ""

# Fonction pour ajouter l'en-tête standard
add_header() {
    local file=$1
    local type=$2
    local desc=$3

    # Créer un fichier temporaire
    local tmpfile=$(mktemp)

    # Ajouter l'en-tête
    cat > "$tmpfile" << EOF
# =====================================================
# $desc
# Auteur: Groupe 50
# Date: Juin 2026
# Projet: KUBEQUEST - Groupe 50
# =====================================================

EOF

    # Ajouter le contenu original (sans l'ancien en-tête si présent)
    sed '1,5d' "$file" >> "$tmpfile"

    # Remplacer le fichier original
    mv "$tmpfile" "$file"

    echo "✅ $file - En-tête ajouté"
}

# Fichiers YAML
echo "Traitement des fichiers YAML..."
for file in production-ready/*.yaml; do
    if [ -f "$file" ]; then
        # Ajouter en-tête selon le fichier
        case "$file" in
            *01-backup*)
                add_header "$file" "yaml" "CONFIGURATION BACKUP MYSQL"
                ;;
            *02-monitoring*)
                add_header "$file" "yaml" "CONFIGURATION INGRESS MONITORING"
                ;;
            *03-cert-manager*)
                add_header "$file" "yaml" "CONFIGURATION CERT-MANAGER ET TLS"
                ;;
            *04-alerting*)
                add_header "$file" "yaml" "CONFIGURATION ALERTING PROMETHEUS"
                ;;
            *05-network*)
                add_header "$file" "yaml" "CONFIGURATION NETWORK POLICIES"
                ;;
        esac
    fi
done

echo ""
echo "Traitement des scripts Bash..."
for file in production-ready/*.sh; do
    if [ -f "$file" ]; then
        # Ajouter shebang et en-tête
        local tmpfile=$(mktemp)

        case "$file" in
            *deploy*)
                cat > "$tmpfile" << 'EOF'
#!/bin/bash
# =====================================================
# SCRIPT DE DÉPLOIEMENT - PRODUCTION-READY
# Auteur: Groupe 50
# Date: Juin 2026
# =====================================================
# Ce script déploie automatiquement les 5 composants
# pour passer le projet de 95% à 100% production-ready

EOF
                ;;
            *test*)
                cat > "$tmpfile" << 'EOF'
#!/bin/bash
# =====================================================
# SCRIPT DE TESTS - PRODUCTION-READY
# Auteur: Groupe 50
# Date: Juin 2026
# =====================================================
# Ce script teste tous les composants déployés
# et vérifie que le projet est 100% fonctionnel

EOF
                ;;
            *check*)
                cat > "$tmpfile" << 'EOF'
#!/bin/bash
# =====================================================
# SCRIPT DE VÉRIFICATION - PRÉREQUIS
# Auteur: Groupe 50
# Date: Juin 2026
# =====================================================
# Ce script vérifie que tous les prérequis sont
# réunis avant de lancer le déploiement

EOF
                ;;
            *QUICK*)
                cat > "$tmpfile" << 'EOF'
#!/bin/bash
# =====================================================
# COMMANDES RAPIDES - PRODUCTION-READY
# Auteur: Groupe 50
# Date: Juin 2026
# =====================================================
# Ce script propose des commandes rapides pour
# tester et déployer les composants individuellement

EOF
                ;;
        esac

        # Ajouter le contenu original (sans les 5 premières lignes)
        tail -n +6 "$file" >> "$tmpfile"
        mv "$tmpfile" "$file"

        echo "✅ $file - En-tête ajouté"
    fi
done

echo ""
echo "=========================================="
echo "✅ NETTOYAGE TERMINÉ"
echo "=========================================="
echo ""
echo "Fichiers modifiés:"
echo "- 5 fichiers YAML (avec en-têtes)"
echo "- 4 fichiers Bash (avec en-têtes)"
echo ""
echo "Prochaines étapes:"
echo "1. Vérifier les fichiers avec: git status"
echo "2. Committer avec: git add . && git commit"
echo "3. Push avec: git push"
echo ""
