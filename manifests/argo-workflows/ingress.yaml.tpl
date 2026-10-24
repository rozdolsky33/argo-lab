apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argo-server
  namespace: ${ARGO_WORKFLOWS_NS}
spec:
  ingressClassName: nginx
  rules:
  - host: workflows.${BASE_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argo-server
            port:
              number: 2746
