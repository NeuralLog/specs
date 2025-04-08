# NeuralLog Minimum Viable Product Specification

## Overview

This specification defines the Minimum Viable Product (MVP) for NeuralLog, focusing on the essential components needed to deliver a functional product with Vercel for frontend, Kubernetes for backend services, and Redis for data storage.

## MVP Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Vercel (Frontend)                       │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ User        │  │ Admin       │  │ Billing             │  │
│  │ Interface   │  │ Dashboard   │  │ Interface           │  │
│  │             │  │             │  │                     │  │
│  │ • Log Viewer│  │ • Tenant    │  │ • Subscription      │  │
│  │ • Search    │  │   Management│  │   Management        │  │
│  │ • Dashboard │  │ • User      │  │ • Payment Methods   │  │
│  │             │  │   Management│  │ • Usage & Invoices  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes (Backend)                    │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Log Service │  │ MCP Service │  │ Admin Service       │  │
│  │             │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌─────────────┐  ┌─────────────────────────────────────┐   │
│  │ Billing     │  │ Tenant Namespaces                   │   │
│  │ Service     │  │                                     │   │
│  │             │  │ • Each tenant gets isolated         │   │
│  │             │  │   namespace with Redis instance     │   │
│  └─────────────┘  └─────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Next.js Frontend (Vercel)

A single Next.js application with three main interfaces:

#### User Interface
- Log viewer with basic search functionality
- Simple dashboard with log statistics
- User account management

#### Admin Interface
- Tenant creation and management
- User invitation and role assignment
- System monitoring dashboard

#### Billing Interface
- Subscription plan selection
- Payment method management
- Invoice history and usage tracking

### 2. Backend Services (Kubernetes)

#### Log Service
- Log ingestion API
- Log retrieval API
- Basic search functionality

#### MCP Service
- MCP server implementation
- Stdio transport for Unity
- Basic MCP tools for logging

#### Admin Service
- Tenant management API
- User management API
- System configuration API

#### Billing Service
- Subscription management
- Payment processing (Stripe integration)
- Usage tracking and invoicing

### 3. Data Storage (Redis)

- One Redis instance per tenant namespace
- JSON storage for all data
- Simple key structure without tenant encoding

## MVP Features

### Logging Features

- **Log Ingestion**: Basic log ingestion API
- **Log Retrieval**: Simple log retrieval API
- **Log Search**: Basic search by level, source, and time range
- **Log Viewer**: Simple web-based log viewer

### MCP Features

- **MCP Server**: Basic MCP server implementation
- **Stdio Transport**: Support for Unity integration
- **MCP Tools**: Essential tools for logging

### Admin Features

- **Tenant Management**: Create, update, and delete tenants
- **User Management**: Invite, update, and remove users
- **Role Assignment**: Basic role assignment (Admin, User)
- **System Monitoring**: Basic system status monitoring

### Billing Features

- **Subscription Plans**: 2-3 simple subscription tiers
- **Payment Processing**: Stripe integration for payments
- **Usage Tracking**: Track log volume for billing
- **Invoicing**: Basic invoice generation

## Technical Implementation

### Frontend (Next.js)

```typescript
// Next.js app structure
app/
├── (user)/
│   ├── dashboard/
│   │   └── page.tsx
│   ├── logs/
│   │   └── page.tsx
│   └── layout.tsx
├── (admin)/
│   ├── tenants/
│   │   └── page.tsx
│   ├── users/
│   │   └── page.tsx
│   └── layout.tsx
├── (billing)/
│   ├── subscriptions/
│   │   └── page.tsx
│   ├── invoices/
│   │   └── page.tsx
│   └── layout.tsx
├── api/
│   ├── logs/
│   │   └── route.ts
│   ├── admin/
│   │   └── route.ts
│   └── billing/
│       └── route.ts
└── layout.tsx
```

### Backend Services

#### Log Service

```typescript
// Log service API endpoints
import express from 'express';
import { Redis } from 'ioredis';

const app = express();
const redis = new Redis(process.env.REDIS_URL);

// Log ingestion endpoint
app.post('/logs', async (req, res) => {
  const log = req.body;
  
  // Validate log
  if (!log.level || !log.message) {
    return res.status(400).json({ error: 'Invalid log format' });
  }
  
  // Add timestamp if not provided
  if (!log.timestamp) {
    log.timestamp = Date.now();
  }
  
  // Store log
  const logId = await storeLog(log);
  
  res.status(200).json({ id: logId });
});

// Log retrieval endpoint
app.get('/logs/:id', async (req, res) => {
  const logId = req.params.id;
  const log = await getLog(logId);
  
  if (!log) {
    return res.status(404).json({ error: 'Log not found' });
  }
  
  res.status(200).json(log);
});

// Log search endpoint
app.get('/logs', async (req, res) => {
  const query = {
    level: req.query.level,
    source: req.query.source,
    startTime: req.query.startTime ? parseInt(req.query.startTime as string) : undefined,
    endTime: req.query.endTime ? parseInt(req.query.endTime as string) : undefined,
    limit: req.query.limit ? parseInt(req.query.limit as string) : 100
  };
  
  const logs = await searchLogs(query);
  
  res.status(200).json({ logs, total: logs.length });
});

app.listen(3000, () => {
  console.log('Log service running on port 3000');
});
```

#### MCP Service

```typescript
// MCP service implementation
import { MCPServer } from '@mcp/server';
import { StdioTransport } from '@mcp/transport-stdio';
import { z } from 'zod';
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

// Create MCP server
const server = new MCPServer();

// Register log tool
server.tool("neurallog.log", {
  level: z.enum(['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']),
  message: z.string(),
  metadata: z.record(z.any()).optional(),
  source: z.string().optional(),
  tags: z.array(z.string()).optional()
}, async ({ level, message, metadata, source, tags }) => {
  // Create log entry
  const log = {
    level,
    message,
    metadata,
    source,
    tags,
    timestamp: Date.now()
  };
  
  // Store log
  const logId = await storeLog(log);
  
  return { success: true, logId };
});

// Register search tool
server.tool("neurallog.search", {
  query: z.string().optional(),
  level: z.enum(['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']).optional(),
  source: z.string().optional(),
  startTime: z.number().optional(),
  endTime: z.number().optional(),
  limit: z.number().optional()
}, async ({ query, level, source, startTime, endTime, limit }) => {
  // Search logs
  const logs = await searchLogs({
    level,
    source,
    startTime,
    endTime,
    limit: limit || 100
  });
  
  return { logs, total: logs.length };
});

// Connect to stdio transport
const transport = new StdioTransport();
server.connect(transport);

console.log('MCP server running with stdio transport');
```

### Kubernetes Deployment

#### Tenant Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-123
  labels:
    tenant: "123"
```

#### Redis Deployment

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
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```

#### Log Service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-service
  namespace: tenant-123
spec:
  replicas: 2
  selector:
    matchLabels:
      app: log-service
  template:
    metadata:
      labels:
        app: log-service
    spec:
      containers:
      - name: log-service
        image: neurallog/log-service:latest
        ports:
        - containerPort: 3000
        env:
        - name: REDIS_URL
          value: "redis:6379"
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

#### MCP Service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-service
  namespace: tenant-123
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mcp-service
  template:
    metadata:
      labels:
        app: mcp-service
    spec:
      containers:
      - name: mcp-service
        image: neurallog/mcp-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: REDIS_URL
          value: "redis:6379"
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

## Billing Implementation

### Subscription Plans

```typescript
// Subscription plan definitions
const subscriptionPlans = [
  {
    id: 'free',
    name: 'Free',
    price: 0,
    features: {
      logRetention: 7, // days
      maxLogsPerDay: 1000,
      maxUsers: 1
    }
  },
  {
    id: 'basic',
    name: 'Basic',
    price: 29,
    features: {
      logRetention: 30, // days
      maxLogsPerDay: 10000,
      maxUsers: 5
    }
  },
  {
    id: 'pro',
    name: 'Professional',
    price: 99,
    features: {
      logRetention: 90, // days
      maxLogsPerDay: 100000,
      maxUsers: 20
    }
  }
];
```

### Stripe Integration

```typescript
// Stripe integration
import Stripe from 'stripe';
import { Redis } from 'ioredis';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const redis = new Redis(process.env.REDIS_URL);

// Create subscription
async function createSubscription(tenantId: string, planId: string, paymentMethodId: string): Promise<any> {
  // Get tenant
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (!tenantJson) {
    throw new Error('Tenant not found');
  }
  
  const tenant = JSON.parse(tenantJson);
  
  // Get plan
  const plan = subscriptionPlans.find(p => p.id === planId);
  if (!plan) {
    throw new Error('Plan not found');
  }
  
  // Free plan doesn't need Stripe
  if (plan.price === 0) {
    const subscription = {
      id: `free-${tenantId}`,
      planId,
      status: 'active',
      currentPeriodStart: new Date(),
      currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
    };
    
    await redis.set(`billing:subscription`, JSON.stringify(subscription));
    return subscription;
  }
  
  // Create or get Stripe customer
  let customer;
  if (tenant.stripeCustomerId) {
    customer = await stripe.customers.retrieve(tenant.stripeCustomerId);
  } else {
    customer = await stripe.customers.create({
      name: tenant.name,
      email: tenant.adminEmail,
      metadata: {
        tenantId
      }
    });
    
    // Update tenant with Stripe customer ID
    tenant.stripeCustomerId = customer.id;
    await redis.set(`tenants:${tenantId}`, JSON.stringify(tenant));
  }
  
  // Attach payment method to customer
  await stripe.paymentMethods.attach(paymentMethodId, {
    customer: customer.id
  });
  
  // Set as default payment method
  await stripe.customers.update(customer.id, {
    invoice_settings: {
      default_payment_method: paymentMethodId
    }
  });
  
  // Create subscription
  const stripeSubscription = await stripe.subscriptions.create({
    customer: customer.id,
    items: [
      {
        price: `price_${planId}` // Price ID in Stripe
      }
    ],
    metadata: {
      tenantId
    }
  });
  
  // Store subscription in Redis
  const subscription = {
    id: stripeSubscription.id,
    planId,
    status: stripeSubscription.status,
    currentPeriodStart: new Date(stripeSubscription.current_period_start * 1000),
    currentPeriodEnd: new Date(stripeSubscription.current_period_end * 1000),
    stripeSubscriptionId: stripeSubscription.id
  };
  
  await redis.set(`billing:subscription`, JSON.stringify(subscription));
  
  return subscription;
}
```

## Implementation Plan

### Phase 1: Core Infrastructure

1. Set up Kubernetes cluster
2. Create tenant namespace structure
3. Deploy Redis instances
4. Set up CI/CD pipeline

### Phase 2: Backend Services

1. Implement Log Service
2. Implement MCP Service
3. Implement Admin Service
4. Implement Billing Service

### Phase 3: Frontend Development

1. Create Next.js application
2. Implement User Interface
3. Implement Admin Interface
4. Implement Billing Interface

### Phase 4: Integration and Testing

1. Integrate frontend with backend services
2. Set up Stripe integration
3. Perform end-to-end testing
4. Deploy to production

## MVP Limitations

The MVP has the following limitations that will be addressed in future versions:

1. **Limited Search**: Basic search functionality only
2. **No Advanced Rules**: No rule engine in MVP
3. **Simple Scaling**: Limited horizontal scaling
4. **Basic Analytics**: Minimal analytics capabilities
5. **Limited Integrations**: No third-party integrations
6. **Single Region**: Deployed in a single region
7. **Manual Deployment**: No automated tenant provisioning
