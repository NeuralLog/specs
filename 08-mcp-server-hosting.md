# NeuralLog MCP Server Hosting Specification

## Overview

This specification details how MCP servers are hosted within the NeuralLog ecosystem. It covers deployment architecture, scaling, resource management, and operational aspects of running MCP servers as part of the NeuralLog platform.

## Hosting Architecture

### Deployment Model

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                      │
│                                                             │
│  ┌─────────────────────────────────────────────┐           │
│  │                  Tenant A                   │           │
│  │                                             │           │
│  │  ┌───────────────┐      ┌───────────────┐  │           │
│  │  │ NeuralLog     │      │ MCP Server    │  │           │
│  │  │ Services      │◄────►│ Instances     │  │           │
│  │  └───────────────┘      └───────────────┘  │           │
│  │                                             │           │
│  │  ┌───────────────┐      ┌───────────────┐  │           │
│  │  │ Namespace:    │      │ Namespace:    │  │           │
│  │  │ Org1          │      │ Org1-MCP      │  │           │
│  │  └───────────────┘      └───────────────┘  │           │
│  │                                             │           │
│  └─────────────────────────────────────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### MCP Server Deployment

Each tenant receives dedicated MCP server instances:

- **Tenant-Level Deployment**: MCP servers deployed at the tenant level
- **Organization-Level Deployment**: Optional dedicated MCP servers per organization
- **Kubernetes Resources**: Deployed as StatefulSets for stable networking
- **Service Mesh**: Integrated with service mesh for secure communication
- **Load Balancing**: Internal load balancing for high availability

## Container Configuration

### 1. Container Image

```dockerfile
FROM node:18-alpine

# Install dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY dist/ ./dist/
COPY config/ ./config/

# Set environment variables
ENV NODE_ENV=production
ENV MCP_SERVER_PORT=8080

# Expose ports
EXPOSE 8080

# Start the MCP server
CMD ["node", "dist/mcp-server.js"]
```

### 2. Resource Requirements

Resource allocation per MCP server instance:

- **CPU**: 
  - Request: 0.5 CPU cores
  - Limit: 2 CPU cores
- **Memory**:
  - Request: 512 MB
  - Limit: 2 GB
- **Storage**:
  - Ephemeral: 1 GB
  - Persistent: None (stateless)
- **Network**:
  - Ingress: 100 Mbps
  - Egress: 100 Mbps

### 3. Environment Configuration

```yaml
# Environment variables for MCP server
MCP_SERVER_PORT: 8080
MCP_SERVER_HOST: "0.0.0.0"
MCP_LOG_LEVEL: "info"
MCP_MAX_CONNECTIONS: 1000
MCP_CONNECTION_TIMEOUT: 300000
MCP_REQUEST_TIMEOUT: 30000
MCP_MAX_REQUEST_SIZE: 5242880
NEURALLOG_API_URL: "http://neurallog-api.tenant-123.svc.cluster.local"
TENANT_ID: "tenant-123"
ORGANIZATION_ID: "org-456"
```

## Kubernetes Resources

### 1. StatefulSet Definition

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mcp-server
  namespace: tenant-123
  labels:
    app: mcp-server
    tenant: tenant-123
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mcp-server
      tenant: tenant-123
  serviceName: mcp-server
  template:
    metadata:
      labels:
        app: mcp-server
        tenant: tenant-123
    spec:
      containers:
      - name: mcp-server
        image: neurallog/mcp-server:latest
        ports:
        - containerPort: 8080
          name: websocket
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 2
            memory: 2Gi
        env:
        - name: MCP_SERVER_PORT
          value: "8080"
        - name: TENANT_ID
          value: "tenant-123"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
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
```

### 2. Service Definition

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mcp-server
  namespace: tenant-123
  labels:
    app: mcp-server
    tenant: tenant-123
spec:
  ports:
  - port: 8080
    targetPort: 8080
    name: websocket
  selector:
    app: mcp-server
    tenant: tenant-123
  type: ClusterIP
```

### 3. Ingress Definition

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mcp-server
  namespace: tenant-123
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/websocket-services: "mcp-server"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - mcp.tenant-123.neurallog.com
    secretName: mcp-server-tls
  rules:
  - host: mcp.tenant-123.neurallog.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mcp-server
            port:
              number: 8080
```

## Scaling Strategy

### 1. Horizontal Scaling

MCP servers scale horizontally based on connection load:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mcp-server
  namespace: tenant-123
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: mcp-server
  minReplicas: 2
  maxReplicas: 10
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
  - type: Pods
    pods:
      metric:
        name: mcp_connections
      target:
        type: AverageValue
        averageValue: 800
```

### 2. Connection Distribution

- **Sticky Sessions**: WebSocket connections maintain affinity to pods
- **Connection Balancing**: New connections distributed evenly
- **Connection Draining**: Graceful handling during scale-down
- **Connection Limits**: Per-pod connection limits

### 3. Resource Scaling

- **CPU-based**: Scale based on CPU utilization
- **Memory-based**: Scale based on memory utilization
- **Connection-based**: Scale based on number of active connections
- **Request Rate**: Scale based on request throughput

## High Availability

### 1. Multi-Zone Deployment

- **Zone Distribution**: Pods distributed across availability zones
- **Anti-Affinity Rules**: Prevent pods from co-locating
- **Topology Spread Constraints**: Ensure even distribution

```yaml
# Pod anti-affinity rules
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - mcp-server
      topologyKey: "kubernetes.io/hostname"
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - mcp-server
        topologyKey: "topology.kubernetes.io/zone"
```

### 2. Connection Resilience

- **Reconnection Logic**: Clients implement reconnection with backoff
- **Session Persistence**: Session state preserved across reconnections
- **Heartbeat Mechanism**: Regular heartbeats to detect connection issues
- **Connection Migration**: Ability to migrate connections between pods

### 3. Failure Recovery

- **Pod Restarts**: Automatic restart of failed pods
- **Health Checks**: Regular health checks to detect issues
- **Circuit Breaking**: Prevent cascading failures
- **Graceful Degradation**: Maintain service with reduced functionality

## Monitoring and Observability

### 1. Metrics

Key metrics collected from MCP servers:

- **Connection Metrics**:
  - Active connections
  - Connection rate
  - Connection duration
  - Connection errors
  
- **Request Metrics**:
  - Request rate
  - Request latency
  - Request errors
  - Request size
  
- **Resource Metrics**:
  - CPU usage
  - Memory usage
  - Network I/O
  - Garbage collection

### 2. Logging

Structured logging for MCP server operations:

```json
{
  "timestamp": "2023-04-08T12:34:56.789Z",
  "level": "info",
  "message": "MCP request processed",
  "tenant": "tenant-123",
  "organization": "org-456",
  "connectionId": "conn-789",
  "tool": "neurallog.log",
  "requestId": "req-abc",
  "duration": 45,
  "status": "success"
}
```

### 3. Tracing

Distributed tracing for request flows:

- **Trace Context**: Propagate trace context through requests
- **Span Creation**: Create spans for key operations
- **Attribute Tagging**: Tag spans with relevant attributes
- **Sampling**: Sample traces based on configuration
- **Visualization**: Visualize traces in observability platform

## Security Measures

### 1. Network Security

- **Network Policies**: Restrict pod-to-pod communication
- **TLS Termination**: Terminate TLS at ingress
- **mTLS**: Mutual TLS for service-to-service communication
- **IP Whitelisting**: Optional IP restrictions for sensitive tenants

```yaml
# Network policy example
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mcp-server-network-policy
  namespace: tenant-123
spec:
  podSelector:
    matchLabels:
      app: mcp-server
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: tenant-123
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: tenant-123
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

### 2. Authentication

- **JWT Validation**: Validate JWT tokens for all connections
- **Token Refresh**: Support for token refresh
- **Certificate Authentication**: Optional client certificate authentication
- **API Key Authentication**: Alternative authentication for non-browser clients

### 3. Rate Limiting

- **Connection Rate Limiting**: Limit new connections per client
- **Request Rate Limiting**: Limit requests per connection
- **Tenant-Level Quotas**: Overall limits per tenant
- **Graduated Response**: Increasing backoff for repeated violations

## Operational Procedures

### 1. Deployment

- **Blue/Green Deployment**: Zero-downtime deployments
- **Canary Releases**: Gradual rollout of new versions
- **Rollback Plan**: Quick rollback procedure
- **Version Management**: Clear versioning strategy

### 2. Upgrades

- **Compatibility**: Maintain backward compatibility
- **Migration Path**: Clear migration path for breaking changes
- **Upgrade Documentation**: Detailed upgrade instructions
- **Upgrade Testing**: Comprehensive testing of upgrades

### 3. Backup and Recovery

- **Configuration Backup**: Regular backup of configurations
- **State Recovery**: Procedures for recovering state
- **Disaster Recovery**: Cross-region recovery capabilities
- **Recovery Testing**: Regular testing of recovery procedures

## Implementation Guidelines

### 1. MCP Server Implementation

- **Node.js Runtime**: Use Node.js for MCP server implementation
- **TypeScript**: Implement in TypeScript for type safety
- **Modular Design**: Use modular architecture for maintainability
- **Configuration Management**: Externalize configuration
- **Error Handling**: Implement comprehensive error handling

### 2. Deployment Automation

- **Helm Charts**: Use Helm for deployment
- **CI/CD Pipeline**: Automate deployment process
- **Infrastructure as Code**: Define infrastructure as code
- **Environment Parity**: Maintain parity across environments
- **Deployment Validation**: Validate deployments automatically

### 3. Operational Readiness

- **Runbooks**: Create operational runbooks
- **Alerting**: Set up appropriate alerting
- **Escalation Procedures**: Define clear escalation paths
- **SLOs/SLAs**: Define and monitor service level objectives
- **Capacity Planning**: Regular capacity planning exercises
