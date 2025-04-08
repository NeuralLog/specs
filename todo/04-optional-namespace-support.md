# Optional Namespace Support Implementation

## Overview

This specification outlines the implementation of optional namespace support within NeuralLog's tenant isolation model, allowing for further organization of logs within each tenant's Redis instance.

## Components

1. **Namespace Configuration**
2. **Namespace-Aware APIs**
3. **Namespace Management**
4. **UI Integration**

## Implementation Steps

### 1. Namespace Configuration

- Implement tenant-level namespace support flag
- Create namespace management functions
- Set up namespace-specific Redis key patterns

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

// Check if namespace support is enabled
async function isNamespaceSupportEnabled(tenantId: string): Promise<boolean> {
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (!tenantJson) {
    return false;
  }
  
  const tenant = JSON.parse(tenantJson);
  return tenant.features?.namespaceSupport === true;
}
```

### 2. Namespace-Aware APIs

- Update log storage functions to support namespaces
- Modify log retrieval functions for namespace filtering
- Add namespace parameters to API endpoints

```typescript
// Store a log with optional namespace
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
  
  return logId;
}

// API endpoint with namespace support
app.post('/logs', async (req, res) => {
  const log = req.body;
  const namespace = req.query.namespace as string;
  
  // Validate log
  if (!log.level || !log.message) {
    return res.status(400).json({ error: 'Invalid log format' });
  }
  
  // Check if namespace is valid if provided
  if (namespace) {
    const isEnabled = await isNamespaceSupportEnabled(req.user.tenantId);
    if (!isEnabled) {
      return res.status(400).json({ error: 'Namespace support not enabled for this tenant' });
    }
    
    const namespaces = await listNamespaces();
    if (!namespaces.includes(namespace)) {
      return res.status(400).json({ error: 'Invalid namespace' });
    }
  }
  
  // Store log
  const logId = await storeLog(log, namespace);
  
  res.status(200).json({ id: logId });
});
```

### 3. Namespace Management

- Create namespace CRUD operations
- Implement namespace validation
- Add namespace listing functionality

```typescript
// Create a namespace
async function createNamespace(namespace: string): Promise<void> {
  // Validate namespace name (alphanumeric, dashes, underscores only)
  if (!/^[a-zA-Z0-9-_]+$/.test(namespace)) {
    throw new Error('Invalid namespace name. Use only letters, numbers, dashes, and underscores.');
  }
  
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
  // Get all keys with this namespace
  const keys = await redis.keys(`*:${namespace}:*`);
  if (keys.length > 0) {
    await redis.del(...keys);
  }
}
```

### 4. UI Integration

- Add namespace selector to log viewer
- Create namespace management UI
- Implement namespace filtering in search

```jsx
// NamespaceSelector.jsx
"use client";

import { useState, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function NamespaceSelector() {
  const [namespaces, setNamespaces] = useState([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const searchParams = useSearchParams();
  
  const currentNamespace = searchParams.get("namespace") || "";
  
  useEffect(() => {
    async function fetchNamespaces() {
      setLoading(true);
      const res = await fetch("/api/namespaces");
      const data = await res.json();
      setNamespaces(data.namespaces);
      setLoading(false);
    }
    
    fetchNamespaces();
  }, []);
  
  function handleNamespaceChange(e) {
    const namespace = e.target.value;
    
    // Update URL with new namespace
    const params = new URLSearchParams(searchParams);
    if (namespace) {
      params.set("namespace", namespace);
    } else {
      params.delete("namespace");
    }
    
    router.push(`?${params.toString()}`);
  }
  
  if (loading) {
    return <div>Loading namespaces...</div>;
  }
  
  return (
    <div className="mb-4">
      <label className="block text-sm font-medium text-gray-700 mb-1">
        Namespace
      </label>
      <select
        value={currentNamespace}
        onChange={handleNamespaceChange}
        className="w-full border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500"
      >
        <option value="">All Namespaces</option>
        {namespaces.map((namespace) => (
          <option key={namespace} value={namespace}>
            {namespace}
          </option>
        ))}
      </select>
    </div>
  );
}
```

## Namespace Management UI

```jsx
// NamespaceManagement.jsx
"use client";

import { useState, useEffect } from "react";

export default function NamespaceManagement() {
  const [namespaces, setNamespaces] = useState([]);
  const [loading, setLoading] = useState(true);
  const [newNamespace, setNewNamespace] = useState("");
  const [error, setError] = useState("");
  
  useEffect(() => {
    fetchNamespaces();
  }, []);
  
  async function fetchNamespaces() {
    setLoading(true);
    const res = await fetch("/api/namespaces");
    const data = await res.json();
    setNamespaces(data.namespaces);
    setLoading(false);
  }
  
  async function handleCreateNamespace(e) {
    e.preventDefault();
    setError("");
    
    if (!newNamespace) {
      setError("Namespace name is required");
      return;
    }
    
    try {
      const res = await fetch("/api/namespaces", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: newNamespace })
      });
      
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to create namespace");
      }
      
      setNewNamespace("");
      fetchNamespaces();
    } catch (err) {
      setError(err.message);
    }
  }
  
  async function handleDeleteNamespace(namespace) {
    if (!confirm(`Are you sure you want to delete the namespace "${namespace}"? This will delete all logs in this namespace.`)) {
      return;
    }
    
    try {
      const res = await fetch(`/api/namespaces/${namespace}`, {
        method: "DELETE"
      });
      
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to delete namespace");
      }
      
      fetchNamespaces();
    } catch (err) {
      setError(err.message);
    }
  }
  
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Namespace Management</h1>
      
      <div className="bg-white p-4 rounded shadow">
        <h2 className="text-xl font-semibold mb-4">Create Namespace</h2>
        <form onSubmit={handleCreateNamespace} className="space-y-4">
          <div>
            <label className="block mb-1">Namespace Name</label>
            <input 
              type="text" 
              value={newNamespace}
              onChange={(e) => setNewNamespace(e.target.value)}
              className="w-full border rounded px-3 py-2" 
              placeholder="e.g., production, development, team1"
            />
            {error && <p className="text-red-500 text-sm mt-1">{error}</p>}
          </div>
          <button 
            type="submit" 
            className="bg-blue-500 text-white px-4 py-2 rounded"
          >
            Create Namespace
          </button>
        </form>
      </div>
      
      <div className="bg-white p-4 rounded shadow">
        <h2 className="text-xl font-semibold mb-4">Namespaces</h2>
        {loading ? (
          <div>Loading...</div>
        ) : namespaces.length === 0 ? (
          <p className="text-gray-500">No namespaces created yet.</p>
        ) : (
          <ul className="divide-y">
            {namespaces.map((namespace) => (
              <li key={namespace} className="py-3 flex justify-between items-center">
                <span>{namespace}</span>
                <button 
                  onClick={() => handleDeleteNamespace(namespace)}
                  className="text-red-500 hover:text-red-700"
                >
                  Delete
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
```

## Testing Plan

1. **Unit Tests**:
   - Test namespace validation
   - Test namespace-aware log storage and retrieval
   - Test namespace management functions

2. **Integration Tests**:
   - Test namespace API endpoints
   - Test namespace UI components

3. **E2E Tests**:
   - Test complete namespace management workflow
   - Test log filtering by namespace

## Deliverables

1. Namespace configuration implementation
2. Namespace-aware API endpoints
3. Namespace management functions
4. Namespace UI components

## Success Criteria

1. Tenants can enable/disable namespace support
2. Logs can be stored and retrieved with namespace context
3. Namespaces can be created, listed, and deleted
4. UI properly supports namespace selection and filtering
