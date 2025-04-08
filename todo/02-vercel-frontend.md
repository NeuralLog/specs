# Vercel Frontend Implementation

## Overview

This specification outlines the implementation of the Vercel-deployed Next.js frontend for NeuralLog, which is the second highest priority after the core Redis logging infrastructure.

## Components

1. **Next.js Application Setup**
2. **Authentication Implementation**
3. **Log Viewer Interface**
4. **Admin Dashboard**

## Implementation Steps

### 1. Next.js Application Setup

- Create Next.js app with App Router
- Set up project structure
- Configure Vercel deployment

```
app/
├── (auth)/
│   ├── login/
│   │   └── page.tsx
│   └── layout.tsx
├── (user)/
│   ├── logs/
│   │   └── page.tsx
│   └── layout.tsx
├── (admin)/
│   ├── tenants/
│   │   └── page.tsx
│   └── layout.tsx
├── api/
│   ├── logs/
│   │   └── route.ts
│   └── auth/
│       └── route.ts
└── layout.tsx
```

### 2. Authentication Implementation

- Implement NextAuth.js integration
- Set up JWT authentication
- Create login/logout flows

```typescript
// auth.ts
import NextAuth from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

export const authOptions = {
  providers: [
    CredentialsProvider({
      name: "Credentials",
      credentials: {
        username: { label: "Username", type: "text" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        // Call authentication API
        const res = await fetch(`${process.env.API_URL}/auth/login`, {
          method: "POST",
          body: JSON.stringify(credentials),
          headers: { "Content-Type": "application/json" }
        });
        
        const user = await res.json();
        
        if (res.ok && user) {
          return user;
        }
        return null;
      }
    })
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id;
        token.role = user.role;
        token.tenantId = user.tenantId;
      }
      return token;
    },
    async session({ session, token }) {
      session.user.id = token.id;
      session.user.role = token.role;
      session.user.tenantId = token.tenantId;
      return session;
    }
  },
  pages: {
    signIn: "/login"
  }
};

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };
```

### 3. Log Viewer Interface

- Create log viewer component
- Implement log search functionality
- Add real-time log streaming

```typescript
// LogViewer.tsx
"use client";

import { useState, useEffect } from "react";
import { useSearchParams } from "next/navigation";

export default function LogViewer() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const searchParams = useSearchParams();
  
  const level = searchParams.get("level");
  const source = searchParams.get("source");
  const namespace = searchParams.get("namespace");
  
  useEffect(() => {
    async function fetchLogs() {
      setLoading(true);
      
      const queryParams = new URLSearchParams();
      if (level) queryParams.append("level", level);
      if (source) queryParams.append("source", source);
      if (namespace) queryParams.append("namespace", namespace);
      
      const res = await fetch(`/api/logs?${queryParams.toString()}`);
      const data = await res.json();
      
      setLogs(data.logs);
      setLoading(false);
    }
    
    fetchLogs();
  }, [level, source, namespace]);
  
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Logs</h1>
      
      {loading ? (
        <div>Loading...</div>
      ) : (
        <table className="w-full">
          <thead>
            <tr>
              <th className="text-left">Timestamp</th>
              <th className="text-left">Level</th>
              <th className="text-left">Message</th>
              <th className="text-left">Source</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id}>
                <td>{new Date(log.timestamp).toLocaleString()}</td>
                <td>
                  <span className={`px-2 py-1 rounded text-xs ${getLevelColor(log.level)}`}>
                    {log.level}
                  </span>
                </td>
                <td>{log.message}</td>
                <td>{log.source}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

function getLevelColor(level) {
  switch (level) {
    case "DEBUG": return "bg-gray-200 text-gray-800";
    case "INFO": return "bg-blue-200 text-blue-800";
    case "WARN": return "bg-yellow-200 text-yellow-800";
    case "ERROR": return "bg-red-200 text-red-800";
    case "FATAL": return "bg-purple-200 text-purple-800";
    default: return "bg-gray-200 text-gray-800";
  }
}
```

### 4. Admin Dashboard

- Create tenant management interface
- Implement user management
- Add system monitoring

```typescript
// TenantManagement.tsx
"use client";

import { useState, useEffect } from "react";

export default function TenantManagement() {
  const [tenants, setTenants] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    async function fetchTenants() {
      setLoading(true);
      const res = await fetch("/api/admin/tenants");
      const data = await res.json();
      setTenants(data.tenants);
      setLoading(false);
    }
    
    fetchTenants();
  }, []);
  
  async function createTenant(e) {
    e.preventDefault();
    const formData = new FormData(e.target);
    const name = formData.get("name");
    const adminEmail = formData.get("adminEmail");
    
    const res = await fetch("/api/admin/tenants", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, adminEmail })
    });
    
    if (res.ok) {
      const newTenant = await res.json();
      setTenants([...tenants, newTenant]);
      e.target.reset();
    }
  }
  
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Tenant Management</h1>
      
      <div className="bg-white p-4 rounded shadow">
        <h2 className="text-xl font-semibold mb-4">Create Tenant</h2>
        <form onSubmit={createTenant} className="space-y-4">
          <div>
            <label className="block mb-1">Name</label>
            <input 
              type="text" 
              name="name" 
              className="w-full border rounded px-3 py-2" 
              required 
            />
          </div>
          <div>
            <label className="block mb-1">Admin Email</label>
            <input 
              type="email" 
              name="adminEmail" 
              className="w-full border rounded px-3 py-2" 
              required 
            />
          </div>
          <button 
            type="submit" 
            className="bg-blue-500 text-white px-4 py-2 rounded"
          >
            Create Tenant
          </button>
        </form>
      </div>
      
      <div className="bg-white p-4 rounded shadow">
        <h2 className="text-xl font-semibold mb-4">Tenants</h2>
        {loading ? (
          <div>Loading...</div>
        ) : (
          <table className="w-full">
            <thead>
              <tr>
                <th className="text-left">ID</th>
                <th className="text-left">Name</th>
                <th className="text-left">Admin Email</th>
                <th className="text-left">Actions</th>
              </tr>
            </thead>
            <tbody>
              {tenants.map((tenant) => (
                <tr key={tenant.id}>
                  <td>{tenant.id}</td>
                  <td>{tenant.name}</td>
                  <td>{tenant.adminEmail}</td>
                  <td>
                    <button className="text-blue-500 hover:text-blue-700 mr-2">
                      Edit
                    </button>
                    <button className="text-red-500 hover:text-red-700">
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
```

## API Routes

- Implement API routes for frontend
- Create proxy to backend services
- Handle authentication

```typescript
// app/api/logs/route.ts
import { getServerSession } from "next-auth/next";
import { authOptions } from "../auth/[...nextauth]/route";

export async function GET(request) {
  const session = await getServerSession(authOptions);
  
  if (!session) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" }
    });
  }
  
  const { searchParams } = new URL(request.url);
  const level = searchParams.get("level");
  const source = searchParams.get("source");
  const namespace = searchParams.get("namespace");
  
  // Build query parameters
  const queryParams = new URLSearchParams();
  if (level) queryParams.append("level", level);
  if (source) queryParams.append("source", source);
  if (namespace) queryParams.append("namespace", namespace);
  
  // Call backend API
  const res = await fetch(
    `${process.env.API_URL}/logs?${queryParams.toString()}`,
    {
      headers: {
        "Authorization": `Bearer ${session.accessToken}`
      }
    }
  );
  
  const data = await res.json();
  
  return new Response(JSON.stringify(data), {
    status: res.status,
    headers: { "Content-Type": "application/json" }
  });
}
```

## Testing Plan

1. **Unit Tests**:
   - Test components with React Testing Library
   - Test API routes with mocked responses

2. **Integration Tests**:
   - Test authentication flow
   - Test log viewer with real data

3. **E2E Tests**:
   - Test complete user journeys
   - Test admin workflows

## Deliverables

1. Next.js application codebase
2. Vercel deployment configuration
3. Authentication implementation
4. Log viewer interface
5. Admin dashboard

## Success Criteria

1. Frontend successfully deploys to Vercel
2. Authentication works with backend
3. Log viewer displays logs correctly
4. Admin dashboard manages tenants
5. UI is responsive and user-friendly
