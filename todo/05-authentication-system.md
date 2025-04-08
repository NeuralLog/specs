# Authentication System Implementation

## Overview

This specification outlines the implementation of the authentication system for NeuralLog, providing secure access control for users across different tenants.

## Components

1. **User Authentication**
2. **JWT Token Management**
3. **Role-Based Access Control**
4. **Multi-Tenant Support**

## Implementation Steps

### 1. User Authentication

- Implement user registration and login
- Create password hashing and verification
- Support multiple authentication methods

```typescript
// User authentication service
import bcrypt from 'bcrypt';
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);
const SALT_ROUNDS = 10;

// Register a new user
async function registerUser(userData: {
  email: string;
  password: string;
  name: string;
  tenantId: string;
  role?: string;
}): Promise<string> {
  const { email, password, name, tenantId, role = 'user' } = userData;
  
  // Check if user already exists
  const existingUser = await getUserByEmail(email);
  if (existingUser) {
    throw new Error('User already exists');
  }
  
  // Hash password
  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  
  // Generate user ID
  const userId = generateId();
  
  // Create user object
  const user = {
    id: userId,
    email,
    passwordHash,
    name,
    tenantId,
    role,
    createdAt: new Date(),
    updatedAt: new Date()
  };
  
  // Store user in Redis
  await redis.set(`users:${userId}`, JSON.stringify(user));
  
  // Create email index
  await redis.set(`users:email:${email}`, userId);
  
  // Add user to tenant
  await redis.sadd(`tenants:${tenantId}:users`, userId);
  
  return userId;
}

// Get user by email
async function getUserByEmail(email: string): Promise<any | null> {
  const userId = await redis.get(`users:email:${email}`);
  if (!userId) return null;
  
  const userJson = await redis.get(`users:${userId}`);
  if (!userJson) return null;
  
  return JSON.parse(userJson);
}

// Authenticate user
async function authenticateUser(email: string, password: string): Promise<any | null> {
  const user = await getUserByEmail(email);
  if (!user) return null;
  
  const passwordMatch = await bcrypt.compare(password, user.passwordHash);
  if (!passwordMatch) return null;
  
  // Don't return the password hash
  const { passwordHash, ...userWithoutPassword } = user;
  
  return userWithoutPassword;
}
```

### 2. JWT Token Management

- Implement JWT token generation and validation
- Create refresh token mechanism
- Handle token expiration and revocation

```typescript
// JWT token service
import jwt from 'jsonwebtoken';
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = '1h';
const REFRESH_TOKEN_EXPIRES_IN = 30 * 24 * 60 * 60; // 30 days in seconds

// Generate tokens for a user
async function generateTokens(user: any): Promise<{ accessToken: string; refreshToken: string }> {
  // Create JWT payload
  const payload = {
    sub: user.id,
    email: user.email,
    name: user.name,
    tenantId: user.tenantId,
    role: user.role
  };
  
  // Generate access token
  const accessToken = jwt.sign(payload, JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN
  });
  
  // Generate refresh token
  const refreshToken = generateId();
  
  // Store refresh token in Redis
  await redis.set(`refresh_tokens:${refreshToken}`, user.id);
  await redis.expire(`refresh_tokens:${refreshToken}`, REFRESH_TOKEN_EXPIRES_IN);
  
  return {
    accessToken,
    refreshToken
  };
}

// Verify access token
function verifyAccessToken(token: string): any {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
}

// Refresh access token
async function refreshAccessToken(refreshToken: string): Promise<string | null> {
  // Check if refresh token exists
  const userId = await redis.get(`refresh_tokens:${refreshToken}`);
  if (!userId) return null;
  
  // Get user
  const userJson = await redis.get(`users:${userId}`);
  if (!userJson) return null;
  
  const user = JSON.parse(userJson);
  
  // Generate new access token
  const payload = {
    sub: user.id,
    email: user.email,
    name: user.name,
    tenantId: user.tenantId,
    role: user.role
  };
  
  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN
  });
}

// Revoke refresh token
async function revokeRefreshToken(refreshToken: string): Promise<void> {
  await redis.del(`refresh_tokens:${refreshToken}`);
}

// Revoke all refresh tokens for a user
async function revokeAllUserTokens(userId: string): Promise<void> {
  // This would require a different token storage strategy
  // For MVP, we'll implement this later
}
```

### 3. Role-Based Access Control

- Define user roles and permissions
- Implement permission checking
- Create role management functions

```typescript
// Role-based access control
const ROLES = {
  ADMIN: 'admin',
  USER: 'user',
  VIEWER: 'viewer'
};

const PERMISSIONS = {
  // Log permissions
  CREATE_LOGS: 'create:logs',
  READ_LOGS: 'read:logs',
  DELETE_LOGS: 'delete:logs',
  
  // User permissions
  CREATE_USERS: 'create:users',
  READ_USERS: 'read:users',
  UPDATE_USERS: 'update:users',
  DELETE_USERS: 'delete:users',
  
  // Namespace permissions
  MANAGE_NAMESPACES: 'manage:namespaces',
  
  // Tenant permissions
  MANAGE_TENANT: 'manage:tenant'
};

// Role to permissions mapping
const ROLE_PERMISSIONS = {
  [ROLES.ADMIN]: [
    PERMISSIONS.CREATE_LOGS,
    PERMISSIONS.READ_LOGS,
    PERMISSIONS.DELETE_LOGS,
    PERMISSIONS.CREATE_USERS,
    PERMISSIONS.READ_USERS,
    PERMISSIONS.UPDATE_USERS,
    PERMISSIONS.DELETE_USERS,
    PERMISSIONS.MANAGE_NAMESPACES,
    PERMISSIONS.MANAGE_TENANT
  ],
  [ROLES.USER]: [
    PERMISSIONS.CREATE_LOGS,
    PERMISSIONS.READ_LOGS
  ],
  [ROLES.VIEWER]: [
    PERMISSIONS.READ_LOGS
  ]
};

// Check if user has permission
function hasPermission(userRole: string, permission: string): boolean {
  const permissions = ROLE_PERMISSIONS[userRole] || [];
  return permissions.includes(permission);
}

// Authorization middleware
function authorize(permission: string) {
  return (req, res, next) => {
    // User should be set by authentication middleware
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    if (!hasPermission(req.user.role, permission)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    next();
  };
}
```

### 4. Multi-Tenant Support

- Implement tenant-specific authentication
- Create tenant user management
- Handle cross-tenant access control

```typescript
// Multi-tenant authentication
import express from 'express';

const app = express();

// Authentication middleware
async function authenticate(req, res, next) {
  // Get token from Authorization header
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const token = authHeader.split(' ')[1];
  
  // Verify token
  const payload = verifyAccessToken(token);
  if (!payload) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  // Set user in request
  req.user = {
    id: payload.sub,
    email: payload.email,
    name: payload.name,
    tenantId: payload.tenantId,
    role: payload.role
  };
  
  next();
}

// Tenant access middleware
function requireTenantAccess(tenantId) {
  return (req, res, next) => {
    // User should be set by authentication middleware
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    // Check if user belongs to the tenant
    if (req.user.tenantId !== tenantId) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    next();
  };
}

// Login endpoint
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  
  // Authenticate user
  const user = await authenticateUser(email, password);
  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  // Generate tokens
  const tokens = await generateTokens(user);
  
  res.json({
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      tenantId: user.tenantId,
      role: user.role
    },
    ...tokens
  });
});

// Refresh token endpoint
app.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  
  // Refresh access token
  const accessToken = await refreshAccessToken(refreshToken);
  if (!accessToken) {
    return res.status(401).json({ error: 'Invalid refresh token' });
  }
  
  res.json({ accessToken });
});

// Logout endpoint
app.post('/auth/logout', async (req, res) => {
  const { refreshToken } = req.body;
  
  // Revoke refresh token
  await revokeRefreshToken(refreshToken);
  
  res.json({ success: true });
});

// Protected endpoint example
app.get('/logs', authenticate, authorize(PERMISSIONS.READ_LOGS), async (req, res) => {
  // User is authenticated and has permission to read logs
  // req.user contains user information
  
  // Only return logs for the user's tenant
  const logs = await getLogs({ tenantId: req.user.tenantId });
  
  res.json({ logs });
});
```

## Authentication UI

```jsx
// LoginForm.jsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function LoginForm() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  
  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setLoading(true);
    
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password })
      });
      
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Login failed");
      }
      
      const data = await res.json();
      
      // Store tokens in localStorage
      localStorage.setItem("accessToken", data.accessToken);
      localStorage.setItem("refreshToken", data.refreshToken);
      
      // Redirect to dashboard
      router.push("/dashboard");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }
  
  return (
    <div className="max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-6">Login to NeuralLog</h1>
      
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block mb-1">Email</label>
          <input 
            type="email" 
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full border rounded px-3 py-2" 
            required 
          />
        </div>
        <div>
          <label className="block mb-1">Password</label>
          <input 
            type="password" 
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full border rounded px-3 py-2" 
            required 
          />
        </div>
        
        {error && (
          <div className="bg-red-100 text-red-700 p-3 rounded">
            {error}
          </div>
        )}
        
        <button 
          type="submit" 
          className="w-full bg-blue-500 text-white py-2 rounded"
          disabled={loading}
        >
          {loading ? "Logging in..." : "Login"}
        </button>
      </form>
    </div>
  );
}
```

## Testing Plan

1. **Unit Tests**:
   - Test user registration and authentication
   - Test JWT token generation and validation
   - Test permission checking

2. **Integration Tests**:
   - Test authentication API endpoints
   - Test role-based access control

3. **E2E Tests**:
   - Test login and logout flows
   - Test protected routes

## Deliverables

1. User authentication implementation
2. JWT token management
3. Role-based access control system
4. Multi-tenant authentication support
5. Authentication UI components

## Success Criteria

1. Users can register and login securely
2. JWT tokens are properly generated and validated
3. Role-based permissions work correctly
4. Multi-tenant isolation is maintained
5. Authentication UI provides good user experience
