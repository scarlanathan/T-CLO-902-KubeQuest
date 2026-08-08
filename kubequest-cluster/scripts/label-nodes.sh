#!/usr/bin/env bash
# Applique les labels de rôle node-role.kubernetes.io/* aux nœuds du cluster.
# À lancer APRÈS `kind create cluster --config kubequest-cluster/kind.yaml`.
#
# Pourquoi un script séparé : les labels node-role.kubernetes.io/* sont
# "restreints" — le kubelet ne peut pas se les auto-attribuer (sécurité).
# On les pose ici via l'apiserver. Ils reflètent l'architecture 4 nœuds
# (cf. docs/schema-architecture.md) et alimentent le nodeAffinity du chart
# (node-role.kubernetes.io/worker="true").
set -euo pipefail

echo "==> Nœuds détectés :"
kubectl get nodes -L kubequest.io/role

# Mappe le label technique kubequest.io/role -> label node-role lisible.
map_role() {
  local role="$1" node_role_key="$2" node_role_val="${3:-}"
  local nodes
  nodes=$(kubectl get nodes -l "kubequest.io/role=${role}" -o name)
  if [ -z "$nodes" ]; then
    echo "  (aucun nœud avec kubequest.io/role=${role})"
    return
  fi
  for n in $nodes; do
    kubectl label "$n" "node-role.kubernetes.io/${node_role_key}=${node_role_val}" --overwrite
    echo "  ${n} -> node-role.kubernetes.io/${node_role_key}=${node_role_val}"
  done
}

echo "==> Application des rôles :"
map_role app        worker      true
map_role ingress    ingress     ""
map_role monitoring monitoring  ""

echo "==> Résultat :"
kubectl get nodes -o wide
