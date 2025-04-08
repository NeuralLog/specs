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

### PostgreSQL

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: neurallog-data
spec:
  serviceName: postgresql
  replicas: 3
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:14
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-credentials
              key: password
        volumeMounts:
        - name: postgresql-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgresql-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 100Gi
```

### Elasticsearch

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: neurallog-data
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: elasticsearch:8.6.0
        ports:
        - containerPort: 9200
        - containerPort: 9300
        env:
        - name: ES_JAVA_OPTS
          value: "-Xms2g -Xmx2g"
        - name: discovery.type
          value: "single-node"
        volumeMounts:
        - name: elasticsearch-data
          mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
  - metadata:
      name: elasticsearch-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 200Gi
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

# Data services configuration
postgresql:
  enabled: true
  persistence:
    size: 100Gi
  replicaCount: 3

elasticsearch:
  enabled: true
  persistence:
    size: 200Gi
  replicaCount: 3

redis:
  enabled: true
  persistence:
    size: 20Gi
  replicaCount: 3
```

## Deployment Scenarios

### Cloud-Hosted Deployment

For cloud-hosted deployments, NeuralLog uses:

1. **Managed Kubernetes**: EKS, GKE, or AKS
2. **Managed Databases**: RDS, Cloud SQL, or Azure Database
3. **Managed Elasticsearch**: Elasticsearch Service
4. **Managed Redis**: ElastiCache, Memorystore, or Azure Cache
5. **Cloud Storage**: S3, GCS, or Azure Blob Storage
6. **CDN**: CloudFront, Cloud CDN, or Azure CDN

### Self-Hosted Deployment

For self-hosted deployments, NeuralLog supports:

1. **On-Premises Kubernetes**: Standard Kubernetes clusters
2. **Local Databases**: Self-managed PostgreSQL
3. **Local Elasticsearch**: Self-managed Elasticsearch
4. **Local Redis**: Self-managed Redis
5. **Local Storage**: Local persistent volumes
6. **Ingress**: NGINX Ingress Controller

## Implementation Guidelines

1. **Infrastructure as Code**: Use Terraform or similar for infrastructure
2. **GitOps**: Use ArgoCD or Flux for deployment
3. **Secrets Management**: Use Vault or Kubernetes secrets
4. **Monitoring**: Integrate with Prometheus and Grafana
5. **Logging**: Centralized logging with ELK or similar
6. **Backup**: Regular backups of all persistent data
7. **Disaster Recovery**: Cross-region replication for critical data
