# NeuralLog Tenant Isolation Specification

## Overview

This specification defines the tenant isolation architecture for NeuralLog, ensuring complete separation between tenants while allowing organization-level separation within each tenant. The architecture is designed for both cloud-hosted and self-hosted deployments.

## Key Principles

1. **Complete Tenant Isolation**: Each tenant's resources, data, and processing are completely isolated from other tenants
2. **Kubernetes-Level Separation**: Tenant isolation is implemented at the Kubernetes level
3. **Organization Namespaces**: Within a tenant, organizations are separated using Kubernetes namespaces
4. **Consistent Architecture**: Free tier uses the same architecture as paid tiers

## Tenant Isolation Architecture

### Kubernetes-Level Tenant Isolation

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
│  │  ┌───────────────┐      ┌───────────────┐  │           │
│  │  │ Namespace:    │      │ Namespace:    │  │           │
│  │  │ Org2          │      │ Org2-MCP      │  │           │
│  │  └───────────────┘      └───────────────┘  │           │
│  └─────────────────────────────────────────────┘           │
│                                                             │
│  ┌─────────────────────────────────────────────┐           │
│  │                  Tenant B                   │           │
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
│  └─────────────────────────────────────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Implementation Details

#### 1. Tenant Resources

Each tenant receives dedicated:
- Kubernetes namespace(s)
- Compute resources (pods, services)
- Storage resources (PVCs)
- Network resources (ingress, services)
- MCP server instances

#### 2. Namespace Naming Convention

```
tenant-{tenant-id}                  # Tenant root namespace
tenant-{tenant-id}-org-{org-id}     # Organization namespace
tenant-{tenant-id}-org-{org-id}-mcp # Organization MCP namespace
```

#### 3. Resource Allocation

- **CPU and Memory**: Dedicated resource quotas per tenant
- **Storage**: Dedicated persistent volumes per tenant
- **Network**: Dedicated ingress controllers or configurations

## Tenant Isolation Components

### 1. Network Isolation

- **Ingress Separation**:
  - Tenant-specific hostnames (tenant1.neurallog.com)
  - Separate TLS certificates per tenant
  - Network policies preventing cross-tenant traffic

- **Service Isolation**:
  - Services only accessible within tenant namespaces
  - No cross-tenant service discovery

### 2. Data Isolation

- **Storage Isolation**:
  - Separate persistent volumes per tenant
  - No shared storage between tenants
  - Tenant-specific backup and restore processes

- **Database Isolation**:
  - Dedicated database instances or schemas per tenant
  - Separate database credentials per tenant
  - No cross-tenant data access

### 3. Compute Isolation

- **Pod Isolation**:
  - Pods run in tenant-specific namespaces
  - Resource quotas prevent resource starvation
  - Pod security policies enforce isolation

- **MCP Server Isolation**:
  - Dedicated MCP server instances per tenant
  - Tenant-specific MCP configurations
  - No shared MCP resources between tenants

### 4. Authentication & Authorization

- **Identity Management**:
  - Tenant-specific identity providers or configurations
  - JWT tokens include tenant information
  - Token validation at service boundaries

- **RBAC Policies**:
  - Tenant-specific RBAC roles and bindings
  - Organization-level permissions within tenants
  - No cross-tenant permission grants

## Organization Separation

Within each tenant, organizations are separated using Kubernetes namespaces:

### 1. Organization Resources

Each organization within a tenant receives:
- Dedicated namespace(s)
- RBAC policies for access control
- Resource quotas (subset of tenant quota)
- Logical separation of logs and configurations

### 2. Cross-Organization Access

- Organizations within the same tenant can share data if explicitly configured
- Default policy is no cross-organization access
- Tenant administrators can configure cross-organization permissions

## Free Tier Implementation

The free tier uses the same architecture as paid tiers:

- **Identical Architecture**: Same isolation model as paid tiers
- **Resource Limits**: Stricter resource quotas and limits
- **Retention Policies**: Shorter data retention periods
- **Feature Limitations**: Some advanced features disabled

### Tenant Lifecycle Management

- **Creation**: Automated tenant provisioning on sign-up
- **Monitoring**: Usage tracking and activity monitoring
- **Conversion**: Seamless upgrade to paid tier without migration
- **Cleanup**: Automated cleanup of inactive free tier tenants

## Tenant Management API

```typescript
// Tenant management API endpoints
interface TenantManagementAPI {
  // Create a new tenant
  createTenant(params: CreateTenantParams): Promise<Tenant>;
  
  // Get tenant details
  getTenant(tenantId: string): Promise<Tenant>;
  
  // Update tenant configuration
  updateTenant(tenantId: string, params: UpdateTenantParams): Promise<Tenant>;
  
  // Delete a tenant and all its resources
  deleteTenant(tenantId: string): Promise<void>;
  
  // Suspend a tenant (temporarily disable)
  suspendTenant(tenantId: string): Promise<Tenant>;
  
  // Resume a suspended tenant
  resumeTenant(tenantId: string): Promise<Tenant>;
  
  // Convert a tenant from free to paid tier
  convertTenant(tenantId: string, plan: string): Promise<Tenant>;
}

// Tenant data structure
interface Tenant {
  id: string;
  name: string;
  status: 'active' | 'suspended' | 'deleted';
  plan: 'free' | 'basic' | 'pro' | 'enterprise';
  createdAt: Date;
  updatedAt: Date;
  expiresAt?: Date; // For free tier
  organizations: Organization[];
  resources: TenantResources;
}
```

## Deployment Scenarios

### 1. Cloud-Hosted Deployment

- **Tenant Provisioning**: Automated through web interface or API
- **Resource Allocation**: Dynamic based on tenant plan
- **Scaling**: Automatic based on usage patterns
- **Monitoring**: Centralized monitoring of all tenants

### 2. Self-Hosted Deployment

- **Tenant Provisioning**: Manual or through provided tools
- **Resource Allocation**: Configured by administrator
- **Scaling**: Manual or through custom automation
- **Monitoring**: Self-managed monitoring solution

## Security Considerations

- **Namespace Security**: Enforce namespace isolation with network policies
- **Pod Security**: Apply pod security policies to prevent privilege escalation
- **Secret Management**: Use Kubernetes secrets with proper RBAC
- **Network Security**: Implement network policies for micro-segmentation
- **Audit Logging**: Enable Kubernetes audit logging for tenant operations

## Implementation Guidelines

### 1. Kubernetes Resources

```yaml
# Example tenant namespace
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-123
  labels:
    tenant: "123"
    type: "tenant-root"

# Example organization namespace
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-123-org-456
  labels:
    tenant: "123"
    organization: "456"
    type: "organization"

# Example network policy
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
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: "123"
```

### 2. Tenant Provisioning Process

1. Create tenant namespace
2. Apply resource quotas
3. Deploy tenant-specific services
4. Configure networking and ingress
5. Initialize databases and storage
6. Create initial organization namespace(s)
7. Deploy MCP server instances
8. Configure authentication and authorization

### 3. Tenant Cleanup Process

1. Notify tenant of impending deletion
2. Export tenant data (if requested)
3. Delete organization namespaces
4. Delete tenant-specific services
5. Delete persistent volumes and claims
6. Delete tenant namespace
7. Remove DNS entries and ingress rules
8. Clean up any external resources
