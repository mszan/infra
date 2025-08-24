#!/bin/bash
# todo: refactor

echo -e "\n1. Check if ingress-nginx namespace exists:"
kubectl get namespaces | grep ingress

echo -e "\n2. List all resources in ingress-nginx namespace:"
kubectl get all -n ingress-nginx

echo -e "\n3. Check deployment details:"
kubectl describe deployment ingress-nginx-controller -n ingress-nginx

echo -e "\n4. Check pods in ingress-nginx namespace:"
kubectl get pods -n ingress-nginx -o wide

echo -e "\n5. Check pods with the selector we're using:"
kubectl get pods -n ingress-nginx --selector=app.kubernetes.io/component=controller

echo -e "\n6. Check all labels on ingress controller pods:"
kubectl get pods -n ingress-nginx --show-labels

echo -e "\n7. Check replica set status:"
kubectl get replicasets -n ingress-nginx

echo -e "\n8. Check events in ingress-nginx namespace:"
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'