#!/bin/bash
# Bootstrap local Kubernetes cluster with Kind, Helm and ArgoCD.

# deps
# - kind - https://kind.sigs.k8s.io/
# - kubectl - https://kubernetes.io/docs/tasks/tools/
# - helm (client) - https://helm.sh/docs/intro/install/

set -euo pipefail

readonly CLUSTER_NAME="kind-cluster-local"

# make sure these match with the ingress manifest
readonly ARGOCD_HOST="argocd-server.local"
readonly HOST_ENTRY="127.0.0.1 ${ARGOCD_HOST}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

setup_hosts_entry() {
    if grep -q "$ARGOCD_HOST" /etc/hosts; then
        log "hosts entry already exists"
        return 0
    fi

    read -p "Add '$HOST_ENTRY' to /etc/hosts? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$HOST_ENTRY" | sudo tee -a /etc/hosts > /dev/null
        log "added hosts entry"
    else
        log "skipped hosts entry"
    fi
}

setup_cluster() {
    log "setting up kind cluster"
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    kind create cluster --config=local/clusters/cluster-kind.yaml
}

setup_argocd() {
    log "installing argocd"
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    log "applying bootstrap configuration"
    kubectl apply -f local/bootstrap/bootstrap-config.yaml

    log "applying root app"
    kubectl apply -f local/bootstrap/app-root.yaml

    log "waiting for argocd server"
    kubectl wait \
        --for=condition=available \
        --timeout=300s \
        --selector=app.kubernetes.io/name=argocd-server \
        --namespace=argocd \
        deployment

}

show_credentials() {
    local password
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    echo "==============================================="
    echo "ArgoCD ready at: http://$ARGOCD_HOST"
    echo "Username: admin"
    echo "Password: $password"
    echo "==============================================="
}

main() {
    setup_hosts_entry
    setup_cluster
    setup_argocd

    show_credentials
    log "bootstrap complete"
}

main "$@"