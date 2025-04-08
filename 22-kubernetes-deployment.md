# NeuralLog Kubernetes Deployment Specification

## Overview

This specification defines the Kubernetes deployment architecture for NeuralLog, covering both cloud-hosted and self-hosted deployment scenarios.

## Deployment Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                      │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Ingress     │  │ API Gateway │  │ Service Mesh        │  │
│  │ Controller  │──┤             │──┤                     │  │
│  │             │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                     Core Services                       ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  ││
│  │  │ API Service │  │ Log Service │  │ Rule Service    │  ││
│  │  │             │  │             │  │                 │  ││
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  ││
│  │  │ MCP Service │  │ Auth Service│  │ Action Service  │  ││
│  │  │             │  │             │  │                 │  ││
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  ││
│  │                                                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                     Tenant Namespaces                   ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  ││
│  │  │ Tenant A    │  │ Tenant B    │  │ Tenant C        │  ││
│  │  │ Services    │  │ Services    │  │ Services        │  ││
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  ││
│  │                                                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                     Data Services                       ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  ││
│  │  │ PostgreSQL  │  │ Redis       │  │ Elasticsearch   │  ││
│  │  │             │  │             │  │                 │  ││
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  ││
│  │                                                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Kubernetes Resources

### Namespace Structure

```yaml
# System namespaces
- neurallog-system      # System-wide components
- neurallog-monitoring  # Monitoring components
- neurallog-ingress     # Ingress controllers
- neurallog-data        # Shared data services

# Tenant namespaces
- tenant-{tenant-id}                  # Tenant root namespace
- tenant-{tenant-id}-org-{org-id}     # Organization namespace
- tenant-{tenant-id}-org-{org-id}-mcp # Organization MCP namespace
```

### Core Services

#### API Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: neurallog-system
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
    spec:
      containers:
      - name: api-service
        image: neurallog/api-service:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 2
            memory: 2Gi
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: url
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: neurallog-system
spec:
  selector:
    app: api-service
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

#### Log Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-service
  namespace: neurallog-system
spec:
  replicas: 5
  selector:
    matchLabels:
      app: log-service
  template:
    metadata:
      labels:
        app: log-service
    spec:
      containers:
      - name: log-service
        image: neurallog/log-service:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 1
            memory: 1Gi
          limits:
            cpu: 4
            memory: 4Gi
        env:
        - name: ELASTICSEARCH_URL
          valueFrom:
            secretKeyRef:
              name: elasticsearch-credentials
              key: url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: url
```

### Tenant Resources

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-123
  labels:
    tenant: "123"
    type: "tenant-root"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: tenant-123
spec:
  hard:
    pods: "50"
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-123
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: "123"
    - namespaceSelector:
        matchLabels:
          neurallog-system: "true"
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: "123"
    - namespaceSelector:
        matchLabels:
          neurallog-system: "true"
    - namespaceSelector:
        matchLabels:
          neurallog-data: "true"
```

### Ingress Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  namespace: neurallog-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
spec:
  tls:
  - hosts:
    - api.neurallog.com
    - "*.api.neurallog.com"
    secretName: neurallog-tls
  rules:
  - host: api.neurallog.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 80
  - host: "*.api.neurallog.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tenant-router
            port:
              number: 80
```

## Data Services

### Redis

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: neurallog-data
spec:
  serviceName: redis
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7.0-alpine
        ports:
        - containerPort: 6379
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: password
        args:
        - --requirepass
        - $(REDIS_PASSWORD)
        volumeMounts:
        - name: redis-data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 20Gi
```

### Tenant Redis Instance

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: tenant-123 # Each tenant gets their own namespace
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7.0-alpine
        ports:
        - containerPort: 6379
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: password
        args:
        - --requirepass
        - $(REDIS_PASSWORD)
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /usr/local/etc/redis
          readOnly: true
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: tenant-123
data:
  redis.conf: |
    appendonly yes
    appendfsync everysec
    maxmemory 1gb
    maxmemory-policy allkeys-lru
```

## Scaling Configuration

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: log-service-hpa
  namespace: neurallog-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: log-service
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Vertical Pod Autoscaler

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: log-service-vpa
  namespace: neurallog-system
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: log-service
  updatePolicy:
    updateMode: Auto
  resourcePolicy:
    containerPolicies:
    - containerName: log-service
      minAllowed:
        cpu: 500m
        memory: 512Mi
      maxAllowed:
        cpu: 4
        memory: 8Gi
```

## Helm Chart Structure

```
neurallog/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── ingress.yaml
│   ├── namespace.yaml
│   ├── networkpolicy.yaml
│   ├── pvc.yaml
│   ├── secret.yaml
│   ├── service.yaml
│   └── serviceaccount.yaml
└── charts/
    ├── postgresql/
    ├── elasticsearch/
    └── redis/
```

### values.yaml

```yaml
# Global configuration
global:
  environment: production
  imageRegistry: docker.io
  imagePullSecrets: []
  storageClass: standard

# Core services configuration
api:
  image:
    repository: neurallog/api-service
    tag: latest
  replicas: 3
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2
      memory: 2Gi

log:
  image:
    repository: neurallog/log-service
    tag: latest
  replicas: 5
  resources:
    requests:
      cpu: 1
      memory: 1Gi
    limits:
      cpu: 4
      memory: 4Gi

# Tenant configuration
tenant:
  resourceQuota:
    pods: 50
    cpu: 10
    memory: 20Gi
  namespaceSupport:
    enabled: true
    default: false

# Data services configuration
redis:
  enabled: true
  persistence:
    size: 20Gi
  replicaCount: 3
  password: true
  config:
    maxmemory: 2gb
    maxmemoryPolicy: allkeys-lru
    appendonly: "yes"
    appendfsync: everysec
```

## Deployment Scenarios

### Cloud-Hosted Deployment

For cloud-hosted deployments, NeuralLog uses:

1. **Managed Kubernetes**: EKS, GKE, or AKS
2. **Managed Redis**: ElastiCache, Memorystore, or Azure Cache for Redis
3. **Cloud Storage**: S3, GCS, or Azure Blob Storage
4. **CDN**: CloudFront, Cloud CDN, or Azure CDN
5. **Identity Management**: Cognito, Firebase Auth, or Azure AD B2C

### Self-Hosted Deployment

For self-hosted deployments, NeuralLog supports:

1. **On-Premises Kubernetes**: Standard Kubernetes clusters
2. **Self-Managed Redis**: Redis instances deployed in tenant namespaces
3. **Local Storage**: Local persistent volumes
4. **Ingress**: NGINX Ingress Controller
5. **Authentication**: OpenID Connect integration with identity providers

## Implementation Guidelines

1. **Infrastructure as Code**: Use Terraform or similar for infrastructure
2. **GitOps**: Use ArgoCD or Flux for deployment
3. **Secrets Management**: Use Vault or Kubernetes secrets
4. **Monitoring**: Integrate with Prometheus and Grafana
5. **Logging**: Centralized logging with ELK or similar
6. **Backup**: Regular backups of all persistent data
7. **Disaster Recovery**: Cross-region replication for critical data
