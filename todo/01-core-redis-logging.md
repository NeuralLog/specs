# Core Redis-Based Logging Infrastructure

## Overview

This specification outlines the implementation of the core Redis-based logging infrastructure with Kubernetes namespace isolation, which is the highest priority change to reach MVP.

## Components

1. **Kubernetes Namespace Setup**
2. **Redis Instance Deployment**
3. **Log Service Implementation**
4. **MCP Server Integration**

## Implementation Steps

### 1. Kubernetes Namespace Setup

- Create namespace template for tenants
- Implement network policies for isolation
- Set up resource quotas

```yaml
# tenant-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-{id}
  labels:
    tenant: "{id}"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: tenant-{id}
spec:
  hard:
    pods: "20"
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-{id}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: "{id}"
    - namespaceSelector:
        matchLabels:
          system: "true"
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: "{id}"
    - namespaceSelector:
        matchLabels:
          system: "true"
```

### 2. Redis Instance Deployment

- Deploy Redis in tenant namespace
- Configure persistence and security
- Set up monitoring

```yaml
# redis-deployment.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: tenant-{id}
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
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: tenant-{id}
data:
  redis.conf: |
    appendonly yes
    appendfsync everysec
    maxmemory 1gb
    maxmemory-policy allkeys-lru
```

### 3. Log Service Implementation

- Create Node.js/TypeScript service
- Implement log ingestion API
- Implement log retrieval API
- Add optional namespace support

```typescript
// Key functions to implement
async function storeLog(log: LogEntry, namespace?: string): Promise<string> {
  const logId = generateId();
  const namespacePrefix = namespace ? `${namespace}:` : '';
  const key = `logs:${namespacePrefix}${logId}`;
  
  await redis.set(key, JSON.stringify(log));
  
  // Update indexes
  const timeIndex = namespace ? `idx:logs:${namespace}:time` : 'idx:logs:time';
  await redis.zadd(timeIndex, log.timestamp, logId);
  
  return logId;
}

async function searchLogs(query: LogQuery, namespace?: string): Promise<LogEntry[]> {
  const namespacePrefix = namespace ? `${namespace}:` : '';
  const timeIndex = namespace ? `idx:logs:${namespace}:time` : 'idx:logs:time';
  
  const logIds = await redis.zrangebyscore(
    timeIndex,
    query.startTime || '-inf',
    query.endTime || '+inf',
    'LIMIT', 0, query.limit || 100
  );
  
  // Fetch log entries
  const pipeline = redis.pipeline();
  for (const logId of logIds) {
    pipeline.get(`logs:${namespacePrefix}${logId}`);
  }
  
  const results = await pipeline.exec();
  return results
    .filter(result => result[1])
    .map(result => JSON.parse(result[1] as string));
}
```

### 4. MCP Server Integration

- Implement MCP server with stdio transport
- Create log and search tools
- Add namespace support to tools

```typescript
// MCP server implementation
import { MCPServer } from '@mcp/server';
import { StdioTransport } from '@mcp/transport-stdio';
import { z } from 'zod';

const server = new MCPServer();

// Register log tool
server.tool("neurallog.log", {
  level: z.enum(['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']),
  message: z.string(),
  metadata: z.record(z.any()).optional(),
  source: z.string().optional(),
  tags: z.array(z.string()).optional(),
  namespace: z.string().optional()
}, async ({ level, message, metadata, source, tags, namespace }) => {
  const log = {
    level,
    message,
    metadata,
    source,
    tags,
    timestamp: Date.now()
  };
  
  const logId = await storeLog(log, namespace);
  return { success: true, logId };
});

// Connect to stdio transport
const transport = new StdioTransport();
server.connect(transport);
```

## Testing Plan

1. **Unit Tests**:
   - Test Redis key structure
   - Test log storage and retrieval
   - Test namespace support

2. **Integration Tests**:
   - Test Kubernetes namespace isolation
   - Test MCP server with Unity client

3. **Load Tests**:
   - Test with high volume of logs
   - Measure performance metrics

## Deliverables

1. Kubernetes configuration files
2. Redis deployment templates
3. Log service implementation
4. MCP server implementation
5. Basic CLI testing tool

## Success Criteria

1. Can create isolated tenant environments
2. Can store and retrieve logs with Redis
3. MCP server works with stdio transport
4. Optional namespace support functions correctly
5. Performance meets minimum requirements
