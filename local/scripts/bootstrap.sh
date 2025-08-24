#!/bin/bash
set -euo pipefail

# Bootstrap local Kubernetes cluster with ArgoCD
readonly CLUSTER_NAME="kind-cluster-local"
readonly ARGOCD_HOST="argocd-server.local"
readonly HOST_ENTRY="127.0.0.1 ${ARGOCD_HOST}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

check_hosts_entry() {
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

setup_ingress() {
    log "installing nginx ingress controller"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    log "waiting for ingress controller deployment to be created"
    kubectl wait \
        --namespace ingress-nginx \
        --for=condition=available \
        --timeout=300s \
        deployment/ingress-nginx-controller

    log "waiting for ingress controller pods to be ready"
    kubectl wait \
        --namespace ingress-nginx \
        --for=condition=ready \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s \
        pod
}

setup_argocd() {
    log "installing argocd"
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    log "applying argocd ingress"
    kubectl apply -f local/bootstrap/ingress-argocd-server.yaml

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
    check_hosts_entry
    setup_cluster
    setup_ingress
    setup_argocd
    show_credentials
    log "bootstrap complete"
}

main "$@"