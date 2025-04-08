# Admin Dashboard Implementation

## Overview

This specification outlines the implementation of the admin dashboard for NeuralLog, providing tenant management, user administration, and system monitoring capabilities.

## Components

1. **Tenant Management**
2. **User Administration**
3. **System Monitoring**
4. **Configuration Management**

## Implementation Steps

### 1. Tenant Management

- Implement tenant CRUD operations
- Create tenant provisioning workflow
- Add tenant configuration management

```typescript
// Tenant management service
import { Redis } from 'ioredis';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);
const redis = new Redis(process.env.REDIS_URL);

// Create a new tenant
async function createTenant(tenantData: {
  name: string;
  adminEmail: string;
  plan?: string;
}): Promise<string> {
  const { name, adminEmail, plan = 'free' } = tenantData;
  
  // Generate tenant ID
  const tenantId = generateId();
  
  // Create tenant object
  const tenant = {
    id: tenantId,
    name,
    adminEmail,
    plan,
    createdAt: new Date(),
    updatedAt: new Date(),
    features: {
      namespaceSupport: false
    }
  };
  
  // Store tenant in Redis
  await redis.set(`tenants:${tenantId}`, JSON.stringify(tenant));
  
  // Create Kubernetes namespace for tenant
  await provisionTenantInfrastructure(tenantId, name);
  
  // Create admin user for tenant
  const adminPassword = generateRandomPassword();
  await registerUser({
    email: adminEmail,
    password: adminPassword,
    name: 'Admin',
    tenantId,
    role: 'admin'
  });
  
  return tenantId;
}

// Provision tenant infrastructure
async function provisionTenantInfrastructure(tenantId: string, tenantName: string): Promise<void> {
  // Create Kubernetes namespace
  const namespaceYaml = `
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-${tenantId}
  labels:
    tenant: "${tenantId}"
    tenant-name: "${tenantName}"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: tenant-${tenantId}
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
  namespace: tenant-${tenantId}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: "${tenantId}"
    - namespaceSelector:
        matchLabels:
          system: "true"
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: "${tenantId}"
    - namespaceSelector:
        matchLabels:
          system: "true"
  `;
  
  // Write YAML to temp file
  const fs = require('fs');
  const tempFile = `/tmp/tenant-${tenantId}.yaml`;
  fs.writeFileSync(tempFile, namespaceYaml);
  
  // Apply YAML with kubectl
  await execAsync(`kubectl apply -f ${tempFile}`);
  
  // Deploy Redis instance
  const redisYaml = `
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: tenant-${tenantId}
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
  namespace: tenant-${tenantId}
data:
  redis.conf: |
    appendonly yes
    appendfsync everysec
    maxmemory 1gb
    maxmemory-policy allkeys-lru
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: tenant-${tenantId}
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
  `;
  
  // Write YAML to temp file
  const redisFile = `/tmp/tenant-${tenantId}-redis.yaml`;
  fs.writeFileSync(redisFile, redisYaml);
  
  // Apply YAML with kubectl
  await execAsync(`kubectl apply -f ${redisFile}`);
}

// Get tenant by ID
async function getTenant(tenantId: string): Promise<any | null> {
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (!tenantJson) return null;
  
  return JSON.parse(tenantJson);
}

// List all tenants
async function listTenants(): Promise<any[]> {
  const tenantKeys = await redis.keys('tenants:*');
  if (tenantKeys.length === 0) return [];
  
  const pipeline = redis.pipeline();
  for (const key of tenantKeys) {
    if (!key.includes(':users') && !key.includes(':config')) {
      pipeline.get(key);
    }
  }
  
  const results = await pipeline.exec();
  return results
    .filter(result => result[1])
    .map(result => JSON.parse(result[1] as string));
}

// Update tenant
async function updateTenant(tenantId: string, updates: any): Promise<void> {
  const tenant = await getTenant(tenantId);
  if (!tenant) {
    throw new Error('Tenant not found');
  }
  
  const updatedTenant = {
    ...tenant,
    ...updates,
    updatedAt: new Date()
  };
  
  await redis.set(`tenants:${tenantId}`, JSON.stringify(updatedTenant));
}

// Delete tenant
async function deleteTenant(tenantId: string): Promise<void> {
  // Get tenant
  const tenant = await getTenant(tenantId);
  if (!tenant) {
    throw new Error('Tenant not found');
  }
  
  // Delete tenant from Redis
  const keys = await redis.keys(`*${tenantId}*`);
  if (keys.length > 0) {
    await redis.del(...keys);
  }
  
  // Delete Kubernetes namespace
  await execAsync(`kubectl delete namespace tenant-${tenantId}`);
}
```

### 2. User Administration

- Implement user management for tenants
- Create role assignment functionality
- Add user invitation workflow

```typescript
// User administration service
import { Redis } from 'ioredis';
import bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';

const redis = new Redis(process.env.REDIS_URL);
const SALT_ROUNDS = 10;

// List users for a tenant
async function listTenantUsers(tenantId: string): Promise<any[]> {
  const userIds = await redis.smembers(`tenants:${tenantId}:users`);
  if (userIds.length === 0) return [];
  
  const pipeline = redis.pipeline();
  for (const userId of userIds) {
    pipeline.get(`users:${userId}`);
  }
  
  const results = await pipeline.exec();
  return results
    .filter(result => result[1])
    .map(result => {
      const user = JSON.parse(result[1] as string);
      // Don't return password hash
      const { passwordHash, ...userWithoutPassword } = user;
      return userWithoutPassword;
    });
}

// Create user invitation
async function createUserInvitation(inviteData: {
  email: string;
  tenantId: string;
  role?: string;
  invitedBy: string;
}): Promise<string> {
  const { email, tenantId, role = 'user', invitedBy } = inviteData;
  
  // Check if user already exists
  const existingUser = await getUserByEmail(email);
  if (existingUser) {
    throw new Error('User already exists');
  }
  
  // Generate invitation token
  const token = uuidv4();
  
  // Create invitation object
  const invitation = {
    token,
    email,
    tenantId,
    role,
    invitedBy,
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
  };
  
  // Store invitation in Redis
  await redis.set(`invitations:${token}`, JSON.stringify(invitation));
  
  // Set expiration
  await redis.expire(`invitations:${token}`, 7 * 24 * 60 * 60); // 7 days
  
  return token;
}

// Accept user invitation
async function acceptInvitation(token: string, userData: {
  name: string;
  password: string;
}): Promise<string> {
  const { name, password } = userData;
  
  // Get invitation
  const invitationJson = await redis.get(`invitations:${token}`);
  if (!invitationJson) {
    throw new Error('Invalid or expired invitation');
  }
  
  const invitation = JSON.parse(invitationJson);
  
  // Check if invitation has expired
  if (new Date(invitation.expiresAt) < new Date()) {
    throw new Error('Invitation has expired');
  }
  
  // Register user
  const userId = await registerUser({
    email: invitation.email,
    password,
    name,
    tenantId: invitation.tenantId,
    role: invitation.role
  });
  
  // Delete invitation
  await redis.del(`invitations:${token}`);
  
  return userId;
}

// Update user role
async function updateUserRole(userId: string, role: string): Promise<void> {
  const userJson = await redis.get(`users:${userId}`);
  if (!userJson) {
    throw new Error('User not found');
  }
  
  const user = JSON.parse(userJson);
  user.role = role;
  user.updatedAt = new Date();
  
  await redis.set(`users:${userId}`, JSON.stringify(user));
}

// Delete user
async function deleteUser(userId: string): Promise<void> {
  const userJson = await redis.get(`users:${userId}`);
  if (!userJson) {
    throw new Error('User not found');
  }
  
  const user = JSON.parse(userJson);
  
  // Delete user from Redis
  await redis.del(`users:${userId}`);
  await redis.del(`users:email:${user.email}`);
  
  // Remove user from tenant
  await redis.srem(`tenants:${user.tenantId}:users`, userId);
  
  // Revoke all user tokens
  await revokeAllUserTokens(userId);
}
```

### 3. System Monitoring

- Implement system health checks
- Create usage statistics dashboard
- Add tenant activity monitoring

```typescript
// System monitoring service
import { Redis } from 'ioredis';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);
const redis = new Redis(process.env.REDIS_URL);

// Get system health
async function getSystemHealth(): Promise<any> {
  // Check Redis connection
  const redisHealth = await checkRedisHealth();
  
  // Check Kubernetes connection
  const kubernetesHealth = await checkKubernetesHealth();
  
  // Get node status
  const nodeStatus = await getNodeStatus();
  
  return {
    status: redisHealth.status === 'healthy' && kubernetesHealth.status === 'healthy' 
      ? 'healthy' 
      : 'unhealthy',
    components: {
      redis: redisHealth,
      kubernetes: kubernetesHealth
    },
    nodes: nodeStatus
  };
}

// Check Redis health
async function checkRedisHealth(): Promise<any> {
  try {
    const startTime = Date.now();
    await redis.ping();
    const responseTime = Date.now() - startTime;
    
    return {
      status: 'healthy',
      responseTime
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error.message
    };
  }
}

// Check Kubernetes health
async function checkKubernetesHealth(): Promise<any> {
  try {
    const startTime = Date.now();
    const { stdout } = await execAsync('kubectl get --raw /healthz');
    const responseTime = Date.now() - startTime;
    
    return {
      status: stdout.trim() === 'ok' ? 'healthy' : 'unhealthy',
      responseTime
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error.message
    };
  }
}

// Get node status
async function getNodeStatus(): Promise<any[]> {
  try {
    const { stdout } = await execAsync('kubectl get nodes -o json');
    const nodes = JSON.parse(stdout).items;
    
    return nodes.map(node => {
      const conditions = node.status.conditions.reduce((acc, condition) => {
        acc[condition.type] = condition.status === 'True';
        return acc;
      }, {});
      
      return {
        name: node.metadata.name,
        status: conditions.Ready ? 'ready' : 'not-ready',
        conditions,
        capacity: node.status.capacity,
        allocatable: node.status.allocatable
      };
    });
  } catch (error) {
    return [];
  }
}

// Get tenant usage statistics
async function getTenantUsageStatistics(tenantId: string): Promise<any> {
  const today = new Date().toISOString().split('T')[0];
  const month = today.substring(0, 7); // YYYY-MM
  
  // Get log count
  const logCount = parseInt(await redis.get(`billing:usage:logs:${month}`) || '0');
  
  // Get storage usage
  const storageUsage = parseInt(await redis.get(`billing:usage:storage:${month}`) || '0');
  
  // Get API call count
  const apiCalls = parseInt(await redis.get(`billing:usage:api:${month}`) || '0');
  
  // Get user count
  const userCount = await redis.scard(`tenants:${tenantId}:users`);
  
  // Get namespace count if namespace support is enabled
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  const tenant = tenantJson ? JSON.parse(tenantJson) : null;
  
  let namespaceCount = 0;
  if (tenant?.features?.namespaceSupport) {
    namespaceCount = await redis.scard('namespaces');
  }
  
  return {
    tenantId,
    logCount,
    storageUsage,
    apiCalls,
    userCount,
    namespaceCount
  };
}

// Get all tenants usage statistics
async function getAllTenantsUsageStatistics(): Promise<any[]> {
  const tenants = await listTenants();
  
  const usageStats = [];
  for (const tenant of tenants) {
    const stats = await getTenantUsageStatistics(tenant.id);
    usageStats.push({
      ...stats,
      tenantName: tenant.name
    });
  }
  
  return usageStats;
}
```

### 4. Configuration Management

- Implement system configuration settings
- Create tenant configuration options
- Add feature flag management

```typescript
// Configuration management service
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

// System configuration defaults
const DEFAULT_SYSTEM_CONFIG = {
  logRetentionDays: 30,
  maxLogsPerRequest: 1000,
  enableNamespaceSupport: true,
  defaultPlan: 'free'
};

// Get system configuration
async function getSystemConfig(): Promise<any> {
  const configJson = await redis.get('system:config');
  if (!configJson) {
    // Initialize with defaults if not exists
    await setSystemConfig(DEFAULT_SYSTEM_CONFIG);
    return DEFAULT_SYSTEM_CONFIG;
  }
  
  return JSON.parse(configJson);
}

// Update system configuration
async function setSystemConfig(config: any): Promise<void> {
  await redis.set('system:config', JSON.stringify(config));
}

// Get tenant configuration
async function getTenantConfig(tenantId: string): Promise<any> {
  const configJson = await redis.get(`tenants:${tenantId}:config`);
  if (!configJson) {
    // Get system config for defaults
    const systemConfig = await getSystemConfig();
    
    // Create tenant config with system defaults
    const tenantConfig = {
      logRetentionDays: systemConfig.logRetentionDays,
      maxLogsPerRequest: systemConfig.maxLogsPerRequest,
      enableNamespaceSupport: systemConfig.enableNamespaceSupport
    };
    
    await setTenantConfig(tenantId, tenantConfig);
    return tenantConfig;
  }
  
  return JSON.parse(configJson);
}

// Update tenant configuration
async function setTenantConfig(tenantId: string, config: any): Promise<void> {
  await redis.set(`tenants:${tenantId}:config`, JSON.stringify(config));
  
  // Update tenant features based on config
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (tenantJson) {
    const tenant = JSON.parse(tenantJson);
    tenant.features = tenant.features || {};
    tenant.features.namespaceSupport = config.enableNamespaceSupport;
    tenant.updatedAt = new Date();
    
    await redis.set(`tenants:${tenantId}`, JSON.stringify(tenant));
  }
}

// Get feature flags
async function getFeatureFlags(): Promise<any> {
  const flagsJson = await redis.get('system:feature-flags');
  if (!flagsJson) {
    // Initialize with defaults
    const defaultFlags = {
      enableBilling: true,
      enableAdvancedSearch: false,
      enableRuleEngine: false,
      enableAnalytics: false
    };
    
    await setFeatureFlags(defaultFlags);
    return defaultFlags;
  }
  
  return JSON.parse(flagsJson);
}

// Update feature flags
async function setFeatureFlags(flags: any): Promise<void> {
  await redis.set('system:feature-flags', JSON.stringify(flags));
}
```

## Admin Dashboard UI

```jsx
// AdminDashboard.jsx
"use client";

import { useState, useEffect } from "react";
import { Tabs, TabList, Tab, TabPanel } from "./Tabs";

export default function AdminDashboard() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6">Admin Dashboard</h1>
      
      <Tabs>
        <TabList>
          <Tab>Overview</Tab>
          <Tab>Tenants</Tab>
          <Tab>Users</Tab>
          <Tab>System</Tab>
          <Tab>Configuration</Tab>
        </TabList>
        
        <TabPanel>
          <DashboardOverview />
        </TabPanel>
        
        <TabPanel>
          <TenantManagement />
        </TabPanel>
        
        <TabPanel>
          <UserManagement />
        </TabPanel>
        
        <TabPanel>
          <SystemMonitoring />
        </TabPanel>
        
        <TabPanel>
          <ConfigurationManagement />
        </TabPanel>
      </Tabs>
    </div>
  );
}

function DashboardOverview() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    async function fetchStats() {
      setLoading(true);
      const res = await fetch("/api/admin/stats");
      const data = await res.json();
      setStats(data);
      setLoading(false);
    }
    
    fetchStats();
  }, []);
  
  if (loading) {
    return <div>Loading...</div>;
  }
  
  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">System Overview</h2>
      
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded shadow">
          <h3 className="text-gray-500 text-sm">Total Tenants</h3>
          <p className="text-2xl font-bold">{stats.tenantCount}</p>
        </div>
        
        <div className="bg-white p-4 rounded shadow">
          <h3 className="text-gray-500 text-sm">Total Users</h3>
          <p className="text-2xl font-bold">{stats.userCount}</p>
        </div>
        
        <div className="bg-white p-4 rounded shadow">
          <h3 className="text-gray-500 text-sm">Total Logs</h3>
          <p className="text-2xl font-bold">{stats.logCount.toLocaleString()}</p>
        </div>
        
        <div className="bg-white p-4 rounded shadow">
          <h3 className="text-gray-500 text-sm">System Status</h3>
          <p className={`text-2xl font-bold ${stats.systemHealth.status === 'healthy' ? 'text-green-500' : 'text-red-500'}`}>
            {stats.systemHealth.status === 'healthy' ? 'Healthy' : 'Unhealthy'}
          </p>
        </div>
      </div>
      
      <div className="bg-white p-4 rounded shadow">
        <h3 className="text-lg font-semibold mb-4">Tenant Usage</h3>
        <table className="w-full">
          <thead>
            <tr className="border-b">
              <th className="text-left py-2">Tenant</th>
              <th className="text-left py-2">Logs</th>
              <th className="text-left py-2">Storage</th>
              <th className="text-left py-2">Users</th>
            </tr>
          </thead>
          <tbody>
            {stats.tenantStats.map((tenant) => (
              <tr key={tenant.tenantId} className="border-b">
                <td className="py-2">{tenant.tenantName}</td>
                <td className="py-2">{tenant.logCount.toLocaleString()}</td>
                <td className="py-2">{formatBytes(tenant.storageUsage)}</td>
                <td className="py-2">{tenant.userCount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return '0 Bytes';
  
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}
```

## Testing Plan

1. **Unit Tests**:
   - Test tenant management functions
   - Test user administration functions
   - Test system monitoring functions

2. **Integration Tests**:
   - Test admin API endpoints
   - Test configuration management

3. **E2E Tests**:
   - Test tenant creation and provisioning
   - Test user invitation workflow
   - Test admin dashboard UI

## Deliverables

1. Tenant management implementation
2. User administration system
3. System monitoring dashboard
4. Configuration management
5. Admin dashboard UI

## Success Criteria

1. Administrators can create and manage tenants
2. User administration works correctly
3. System health and usage statistics are available
4. Configuration options can be managed
5. Admin dashboard provides a comprehensive view of the system
