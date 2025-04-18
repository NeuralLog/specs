# NeuralLog Redis Storage Specification

## Overview

This specification defines the Redis key-value storage approach for NeuralLog, providing a high-performance, scalable solution for storing JSON log data and related information.

## Storage Architecture

NeuralLog uses Redis as the primary data store, with tenant isolation implemented at the Kubernetes namespace level. Each tenant has its own Redis instance within their dedicated namespace. The key structure is designed to be simple and efficient, without encoding tenant information in the keys since isolation is handled at the infrastructure level.

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                     Tenant A Namespace                  ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  ││
│  │  │ Redis       │  │ Log Service │  │ MCP Service     │  ││
│  │  │ Instance    │  │             │  │                 │  ││
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  ││
│  │                                                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                     Tenant B Namespace                  ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  ││
│  │  │ Redis       │  │ Log Service │  │ MCP Service     │  ││
│  │  │ Instance    │  │             │  │                 │  ││
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  ││
│  │                                                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Key Structure

### Log Storage

```
logs:{log_id} → JSON log object
```

Optionally, when namespace support is enabled:

```
logs:{namespace}:{log_id} → JSON log object
```

Example log object:
```json
{
  "id": "log_abc123",
  "timestamp": 1680969600000,
  "level": "ERROR",
  "message": "Database connection failed",
  "source": "api-service",
  "metadata": {
    "errorCode": "DB_CONN_FAILED",
    "host": "db-1.example.com"
  },
  "tags": ["database", "connection"]
}
```

### Log Indexes

```
idx:logs:time → Sorted set by timestamp
idx:logs:level:{level} → Set of log IDs by level
idx:logs:source:{source} → Set of log IDs by source
idx:logs:tag:{tag} → Set of log IDs by tag
```

Optionally, when namespace support is enabled:

```
idx:logs:{namespace}:time → Sorted set by timestamp
idx:logs:{namespace}:level:{level} → Set of log IDs by level
idx:logs:{namespace}:source:{source} → Set of log IDs by source
idx:logs:{namespace}:tag:{tag} → Set of log IDs by tag
```

### User and Organization Data

```
users:{user_id} → JSON user object
orgs:{org_id} → JSON organization configuration
org:users:{org_id} → Set of user IDs in organization
```

### Rule and Action Data

```
rules:{rule_id} → JSON rule configuration
actions:{action_id} → JSON action configuration
rule:actions:{rule_id} → Set of action IDs associated with rule
```

### Session and Authentication Data

```
sessions:{session_id} → JSON session data
auth:tokens:{token_id} → JSON token data
user:sessions:{user_id} → Set of session IDs for user
```

### Billing and Usage Data

```
billing:subscription → JSON subscription details
billing:invoices:{invoice_id} → JSON invoice data
billing:usage:{year}-{month} → Usage counters
```

## Redis Configuration

### Persistence Configuration

```
# Redis persistence configuration
appendonly yes
appendfsync everysec
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
```

### Memory Configuration

```
# Redis memory configuration
maxmemory 2gb
maxmemory-policy allkeys-lru
```

### Connection Configuration

```
# Redis connection configuration
timeout 0
tcp-keepalive 300
```

## Redis Deployment

### Kubernetes StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: tenant-123
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
          mountPath: /etc/redis
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2
            memory: 4Gi
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
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
          storage: 20Gi
```

### Redis ConfigMap

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
    auto-aof-rewrite-percentage 100
    auto-aof-rewrite-min-size 64mb
    maxmemory 2gb
    maxmemory-policy allkeys-lru
    timeout 0
    tcp-keepalive 300
```

## Data Operations

### Log Storage Operations

```typescript
// Store a log
async function storeLog(log: LogEntry, namespace?: string): Promise<string> {
  const logId = generateId();

  // Handle optional namespace support
  const namespacePrefix = namespace ? `${namespace}:` : '';
  const key = `logs:${namespacePrefix}${logId}`;

  // Store the log
  await redis.set(key, JSON.stringify(log));

  // Update indexes
  const timeIndex = namespace ? `idx:logs:${namespace}:time` : 'idx:logs:time';
  await redis.zadd(timeIndex, log.timestamp, logId);

  const levelIndex = namespace ? `idx:logs:${namespace}:level:${log.level}` : `idx:logs:level:${log.level}`;
  await redis.sadd(levelIndex, logId);

  if (log.source) {
    const sourceIndex = namespace ? `idx:logs:${namespace}:source:${log.source}` : `idx:logs:source:${log.source}`;
    await redis.sadd(sourceIndex, logId);
  }

  // Add tags to indexes
  if (log.tags && log.tags.length > 0) {
    const pipeline = redis.pipeline();
    for (const tag of log.tags) {
      const tagIndex = namespace ? `idx:logs:${namespace}:tag:${tag}` : `idx:logs:tag:${tag}`;
      pipeline.sadd(tagIndex, logId);
    }
    await pipeline.exec();
  }

  return logId;
}
```

### Log Retrieval Operations

```typescript
// Get a log by ID
async function getLog(logId: string, namespace?: string): Promise<LogEntry | null> {
  const namespacePrefix = namespace ? `${namespace}:` : '';
  const logJson = await redis.get(`logs:${namespacePrefix}${logId}`);
  if (!logJson) return null;
  return JSON.parse(logJson);
}

// Search logs
async function searchLogs(query: LogQuery, namespace?: string): Promise<LogEntry[]> {
  let logIds: string[] = [];
  const namespacePrefix = namespace ? `${namespace}:` : '';

  // Filter by level if specified
  if (query.level) {
    const levelIndex = namespace ? `idx:logs:${namespace}:level:${query.level}` : `idx:logs:level:${query.level}`;
    logIds = await redis.smembers(levelIndex);
  }
  // Filter by source if specified
  else if (query.source) {
    const sourceIndex = namespace ? `idx:logs:${namespace}:source:${query.source}` : `idx:logs:source:${query.source}`;
    logIds = await redis.smembers(sourceIndex);
  }
  // Filter by tag if specified
  else if (query.tag) {
    const tagIndex = namespace ? `idx:logs:${namespace}:tag:${query.tag}` : `idx:logs:tag:${query.tag}`;
    logIds = await redis.smembers(tagIndex);
  }
  // Get logs by time range
  else {
    const timeIndex = namespace ? `idx:logs:${namespace}:time` : 'idx:logs:time';
    logIds = await redis.zrangebyscore(
      timeIndex,
      query.startTime || '-inf',
      query.endTime || '+inf',
      'LIMIT', 0, query.limit || 100
    );
  }

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

### Rule and Action Operations

```typescript
// Store a rule
async function storeRule(rule: Rule): Promise<string> {
  const ruleId = rule.id || generateId();
  rule.id = ruleId;

  await redis.set(`rules:${ruleId}`, JSON.stringify(rule));

  // Store action associations
  if (rule.actions && rule.actions.length > 0) {
    await redis.del(`rule:actions:${ruleId}`);
    await redis.sadd(`rule:actions:${ruleId}`, ...rule.actions.map(a => a.actionId));
  }

  return ruleId;
}

// Get actions for a rule
async function getActionsForRule(ruleId: string): Promise<Action[]> {
  const actionIds = await redis.smembers(`rule:actions:${ruleId}`);

  if (actionIds.length === 0) return [];

  const pipeline = redis.pipeline();
  for (const actionId of actionIds) {
    pipeline.get(`actions:${actionId}`);
  }

  const results = await pipeline.exec();
  return results
    .filter(result => result[1])
    .map(result => JSON.parse(result[1] as string));
}
```

## Data Expiration and Retention

### Time-Based Expiration

```typescript
// Set expiration on logs based on retention policy
async function setLogExpiration(logId: string, retentionDays: number): Promise<void> {
  const expirationSeconds = retentionDays * 24 * 60 * 60;
  await redis.expire(`logs:${logId}`, expirationSeconds);
}
```

### Batch Expiration

```typescript
// Expire logs older than a certain date
async function expireOldLogs(olderThan: number, batchSize: number = 1000): Promise<number> {
  let expired = 0;
  let cursor = '0';

  do {
    // Get batch of log IDs older than the specified time
    const [newCursor, logIds] = await redis.zscan(
      'idx:logs:time',
      cursor,
      'MATCH', '*',
      'COUNT', batchSize
    );

    cursor = newCursor;

    // Filter logs older than the specified time
    const oldLogIds = [];
    for (let i = 0; i < logIds.length; i += 2) {
      const logId = logIds[i];
      const timestamp = parseInt(logIds[i + 1]);

      if (timestamp < olderThan) {
        oldLogIds.push(logId);
      }
    }

    if (oldLogIds.length > 0) {
      // Delete logs and remove from indexes
      const pipeline = redis.pipeline();

      for (const logId of oldLogIds) {
        // Get log to extract level, source, and tags
        pipeline.get(`logs:${logId}`);
      }

      const results = await pipeline.exec();
      const deletesPipeline = redis.pipeline();

      for (let i = 0; i < oldLogIds.length; i++) {
        const logId = oldLogIds[i];
        const logJson = results[i][1];

        if (logJson) {
          const log = JSON.parse(logJson as string);

          // Remove from indexes
          deletesPipeline.zrem('idx:logs:time', logId);
          deletesPipeline.srem(`idx:logs:level:${log.level}`, logId);

          if (log.source) {
            deletesPipeline.srem(`idx:logs:source:${log.source}`, logId);
          }

          if (log.tags && log.tags.length > 0) {
            for (const tag of log.tags) {
              deletesPipeline.srem(`idx:logs:tag:${tag}`, logId);
            }
          }

          // Delete the log
          deletesPipeline.del(`logs:${logId}`);
          expired++;
        }
      }

      await deletesPipeline.exec();
    }
  } while (cursor !== '0');

  return expired;
}
```

## Backup and Recovery

### Redis Backup Configuration

```
# Redis backup configuration
save 900 1
save 300 10
save 60 10000
```

### Backup Process

```bash
# Backup script
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="/backups"
REDIS_HOST="redis"
REDIS_PORT="6379"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create Redis backup
redis-cli -h $REDIS_HOST -p $REDIS_PORT --rdb $BACKUP_DIR/redis-$TIMESTAMP.rdb

# Compress backup
gzip $BACKUP_DIR/redis-$TIMESTAMP.rdb

# Clean up old backups (keep last 7 days)
find $BACKUP_DIR -name "redis-*.rdb.gz" -mtime +7 -delete
```

### Recovery Process

```bash
# Recovery script
#!/bin/bash
BACKUP_FILE=$1
REDIS_HOST="redis"
REDIS_PORT="6379"

# Stop Redis
kubectl scale statefulset redis --replicas=0

# Wait for Redis to stop
sleep 10

# Copy backup file to Redis data directory
kubectl cp $BACKUP_FILE redis-0:/data/dump.rdb

# Start Redis
kubectl scale statefulset redis --replicas=1

# Wait for Redis to start
sleep 10

# Verify Redis is running
redis-cli -h $REDIS_HOST -p $REDIS_PORT ping
```

## Optional Namespace Support

NeuralLog provides optional namespace support within each tenant's Redis instance. This feature allows for further organization of logs within a tenant, such as by application, environment, or team.

### Enabling Namespace Support

Namespace support can be enabled at the tenant level:

```typescript
// Enable namespace support for a tenant
async function enableNamespaceSupport(tenantId: string): Promise<void> {
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (!tenantJson) {
    throw new Error('Tenant not found');
  }

  const tenant = JSON.parse(tenantJson);
  tenant.features = tenant.features || {};
  tenant.features.namespaceSupport = true;

  await redis.set(`tenants:${tenantId}`, JSON.stringify(tenant));
}
```

### Namespace Management

```typescript
// Create a namespace
async function createNamespace(namespace: string): Promise<void> {
  await redis.sadd('namespaces', namespace);
}

// List namespaces
async function listNamespaces(): Promise<string[]> {
  return redis.smembers('namespaces');
}

// Delete a namespace and its data
async function deleteNamespace(namespace: string): Promise<void> {
  // Remove namespace from list
  await redis.srem('namespaces', namespace);

  // Delete all data for this namespace
  // Note: This is a simplified example. In production, you would need
  // to implement a more robust cleanup process.
  const keys = await redis.keys(`*:${namespace}:*`);
  if (keys.length > 0) {
    await redis.del(...keys);
  }
}
```

## Implementation Guidelines

1. **Connection Pooling**: Use connection pooling for Redis clients
2. **Pipelining**: Use pipelining for batch operations
3. **Error Handling**: Implement proper error handling and retries
4. **Monitoring**: Set up monitoring for Redis metrics
5. **Scaling**: Plan for Redis Cluster when scaling beyond single instance
6. **Security**: Secure Redis with authentication and network policies
7. **Backup**: Implement regular backups and test recovery procedures
8. **Tenant Isolation**: Maintain strict tenant isolation at the Kubernetes namespace level
9. **Optional Namespaces**: Support optional namespaces for organization within tenants
