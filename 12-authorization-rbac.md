# NeuralLog: Zero-Knowledge Authorization and RBAC

## Overview

NeuralLog implements a zero-knowledge Role-Based Access Control (RBAC) system that provides powerful access control capabilities while maintaining complete data privacy. This specification details the authorization model and implementation.

## Authorization Model

NeuralLog uses a multi-layered authorization model:

1. **Tenant-level isolation**: Complete separation between tenants
2. **Organization-level boundaries**: Separation between organizations within a tenant
3. **Role-based permissions**: User permissions based on assigned roles
4. **Resource-level access control**: Fine-grained control over specific resources

## Tenant Isolation Architecture

NeuralLog implements a hybrid isolation model with both shared global components and dedicated tenant-specific components:

### Global Shared Components (Multi-Tenant Aware)

1. **Auth Service**: A single global auth service instance serving all tenants
2. **OpenFGA**: A single global OpenFGA instance for authorization across all tenants
3. **Auth0**: A single global Auth0 tenant for user authentication
4. **PostgreSQL**: A single global database for OpenFGA and Auth Service data

### Tenant-Specific Dedicated Components (Single-Tenant)

1. **Web Server**: Dedicated web application instance per tenant
2. **Logs Server**: Dedicated logs server instance per tenant
3. **Redis**: One Redis instance per tenant, shared between auth and logs services

### Isolation Mechanisms

1. **Infrastructure Isolation**: Each tenant gets dedicated web, logs, and Redis instances
2. **Namespace Isolation**: In Kubernetes, each tenant's components run in isolated namespaces
3. **Network Isolation**: Network policies restrict communication between tenant namespaces
4. **Logical Isolation**: OpenFGA enforces tenant boundaries through its authorization model
5. **Data Namespacing**: Even in shared components, data is properly namespaced by tenant ID

## Role Definitions

### System Roles

| Role | Description | Scope |
|------|-------------|-------|
| System Administrator | Full access to all system functions | System-wide |
| Tenant Administrator | Full access to tenant resources | Tenant |
| Organization Administrator | Full access to organization resources | Organization |
| Developer | Access to development resources | Organization |
| Analyst | Access to logs and analytics | Organization |
| Viewer | Read-only access | Organization |

### Custom Roles

Administrators can create custom roles with specific permission sets:

```json
{
  "id": "custom-role-123",
  "name": "Log Manager",
  "description": "Manages logs and log configurations",
  "permissions": [
    "logs:read",
    "logs:write",
    "logs:delete",
    "rules:read"
  ],
  "scope": "organization",
  "createdBy": "user-456",
  "createdAt": "2023-04-08T12:34:56.789Z"
}
```

## Permission Structure

Permissions follow the format: `resource:action`

### Core Resources

| Resource | Actions | Description |
|----------|---------|-------------|
| logs | read, write, delete | Log management |
| rules | read, write, delete, execute | Rule management |
| actions | read, write, delete, execute | Action management |
| users | read, write, delete, invite | User management |
| organizations | read, write, delete | Organization management |
| settings | read, write | Settings management |
| api-keys | read, write, delete | API key management |

### Permission Examples

- `logs:read` - View logs
- `rules:write` - Create and update rules
- `actions:execute` - Execute actions
- `users:invite` - Invite new users
- `*:*` - All permissions (admin)

## Role Assignment

Users are assigned roles at the tenant or organization level:

```json
{
  "userId": "user-123",
  "assignments": [
    {
      "tenantId": "tenant-456",
      "roles": ["tenant_admin"]
    },
    {
      "tenantId": "tenant-456",
      "organizationId": "org-789",
      "roles": ["developer", "log_manager"]
    }
  ]
}
```

## Permission Evaluation

The authorization system evaluates permissions using this flow:

1. Identify the user's tenant and organization context
2. Retrieve all roles assigned to the user in that context
3. Aggregate permissions from all assigned roles
4. Check if the required permission exists in the aggregated set
5. Apply additional context-based rules (time, location, etc.)

```typescript
function hasPermission(
  user: User,
  requiredPermission: string,
  context: AuthContext
): boolean {
  // Get all roles for the user in this context
  const roles = getRolesForUser(user.id, context.tenantId, context.organizationId);

  // Get all permissions from these roles
  const permissions = getAllPermissionsForRoles(roles);

  // Check for wildcard permission
  if (permissions.includes('*:*')) {
    return true;
  }

  // Check for resource wildcard
  const [resource, action] = requiredPermission.split(':');
  if (permissions.includes(`${resource}:*`)) {
    return true;
  }

  // Check for specific permission
  return permissions.includes(requiredPermission);
}
```

## Role Hierarchy

Roles can inherit permissions from parent roles:

## OpenFGA Authorization Model

The following is the enhanced OpenFGA authorization model that supports the RBAC system and tenant isolation:

```json
{
  "type_definitions": [
    {
      "type": "tenant",
      "relations": {
        "admin": { "this": {} },
        "member": { "this": {} },
        "exists": { "this": {} }
      }
    },

    {
      "type": "organization",
      "relations": {
        "admin": { "this": {} },
        "member": { "this": {} },
        "parent": {
          "type": "tenant"
        }
      },
      "metadata": {
        "relations": {
          "parent": { "directly_related_user_types": [{ "type": "tenant" }] }
        }
      }
    },

    {
      "type": "user",
      "relations": {
        "self": { "this": {} }
      }
    },

    {
      "type": "role",
      "relations": {
        "assignee": { "this": {} },
        "parent": {
          "type": "role"
        }
      },
      "metadata": {
        "relations": {
          "parent": { "directly_related_user_types": [{ "type": "role" }] }
        }
      }
    },

    {
      "type": "log",
      "relations": {
        "owner": { "this": {} },
        "reader": {
          "union": {
            "child": [
              { "this": {} },
              {
                "computedUserset": {
                  "object": "",
                  "relation": "admin"
                }
              }
            ]
          }
        },
        "writer": {
          "union": {
            "child": [
              { "this": {} },
              {
                "computedUserset": {
                  "object": "",
                  "relation": "admin"
                }
              }
            ]
          }
        },
        "parent": {
          "type": "organization"
        }
      },
      "metadata": {
        "relations": {
          "parent": { "directly_related_user_types": [{ "type": "organization" }] }
        }
      }
    },

    {
      "type": "apikey",
      "relations": {
        "owner": { "this": {} },
        "manager": {
          "union": {
            "child": [
              { "this": {} },
              {
                "computedUserset": {
                  "object": "",
                  "relation": "admin"
                }
              }
            ]
          }
        },
        "parent": {
          "type": "user"
        }
      },
      "metadata": {
        "relations": {
          "parent": { "directly_related_user_types": [{ "type": "user" }] }
        }
      }
    }
  ]
}
```

```json
{
  "id": "senior-developer",
  "name": "Senior Developer",
  "inherits": ["developer"],
  "permissions": [
    "rules:approve",
    "actions:approve"
  ]
}
```

## Zero-Knowledge RBAC Principles

1. **Metadata-Level RBAC**: Access control implemented purely through metadata
2. **No Server Knowledge**: Server never possesses encryption keys or plaintext
3. **Deterministic Key Hierarchy**: Keys derived from master secret using deterministic paths
4. **Immediate Revocation**: Access can be revoked instantly through metadata updates
5. **Comprehensive Audit**: Complete audit trail of all RBAC changes

## Implementation Guidelines

1. **Zero Knowledge First**: Maintain zero-knowledge principles in all RBAC operations
2. **Performance Focus**: Optimize RBAC checks for minimal latency
3. **Scalability**: Design for horizontal scaling of RBAC components
4. **Auditability**: Maintain comprehensive audit trails for all RBAC changes
5. **Developer Experience**: Provide intuitive APIs for RBAC management
