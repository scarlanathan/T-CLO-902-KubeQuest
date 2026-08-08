#!/bin/bash
# Récupère le token d'accès au Kubernetes Dashboard
kubectl -n kubernetes-dashboard get secret admin-user-token \
  -o jsonpath='{.data.token}' | base64 -d
echo
