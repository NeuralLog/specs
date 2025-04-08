# NeuralLog Authorization and RBAC Specification

## Overview

This specification defines the Role-Based Access Control (RBAC) system for NeuralLog, providing a structured approach to managing permissions across the platform.

## Authorization Model

NeuralLog uses a multi-layered authorization model:

1. **Tenant-level isolation**: Complete separation between tenants
2. **Organization-level boundaries**: Separation between organizations within a tenant
3. **Role-based permissions**: User permissions based on assigned roles
4. **Resource-level access control**: Fine-grained control over specific resources

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

## Implementation Guidelines

1. **Centralized Authorization Service**: Implement as a separate microservice
2. **Caching**: Cache permission checks for performance
3. **Audit Logging**: Log all permission checks and changes
4. **UI Integration**: Show/hide UI elements based on permissions
5. **API Integration**: Validate permissions for all API calls
