#!/usr/bin/env bash

cluster=$1
ns=$2

if [[ -z ${ns} ]]; then ns='--all-namespaces'; fi

if [[ -n ${cluster} ]]; then export KUBECONFIG="${HOME}/.kube/${cluster}.kubeconfig"; fi

kubectl get "$(kubectl api-resources --verbs=list -o name | awk '{printf "%s%s",sep,$0;sep=","}')" \
  --ignore-not-found "${ns}" -o=yaml --sort-by='metadata.namespace' > "./backup-${cluster}-${ns}-$(date -Is|tr ':' '-').yaml"
