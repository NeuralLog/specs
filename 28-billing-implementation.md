# NeuralLog Billing Implementation Specification

## Overview

This specification defines the billing system for NeuralLog, providing a scalable and flexible approach to monetize the platform through subscription plans and usage-based billing.

## Billing Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Billing System                          │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Subscription│  │ Payment     │  │ Usage               │  │
│  │ Management  │  │ Processing  │  │ Tracking            │  │
│  │             │  │             │  │                     │  │
│  │ • Plans     │  │ • Stripe    │  │ • Log Volume        │  │
│  │ • Features  │  │   Integration│ │ • API Calls         │  │
│  │ • Limits    │  │ • Invoicing  │  │ • Storage          │  │
│  │             │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Subscription Plans

### Plan Definitions

```typescript
// Subscription plan definitions
const subscriptionPlans = [
  {
    id: 'free',
    name: 'Free',
    description: 'For individuals and small projects',
    price: 0,
    billingCycle: 'monthly',
    features: {
      logRetention: 7, // days
      maxLogsPerDay: 1000,
      maxUsers: 1,
      maxOrganizations: 1,
      supportLevel: 'community'
    }
  },
  {
    id: 'basic',
    name: 'Basic',
    description: 'For small teams and growing projects',
    price: 29,
    billingCycle: 'monthly',
    features: {
      logRetention: 30, // days
      maxLogsPerDay: 10000,
      maxUsers: 5,
      maxOrganizations: 3,
      supportLevel: 'email'
    }
  },
  {
    id: 'pro',
    name: 'Professional',
    description: 'For professional teams and serious applications',
    price: 99,
    billingCycle: 'monthly',
    features: {
      logRetention: 90, // days
      maxLogsPerDay: 100000,
      maxUsers: 20,
      maxOrganizations: 10,
      supportLevel: 'priority'
    }
  }
];
```

### Plan Feature Enforcement

```typescript
// Check if log ingestion is allowed based on plan limits
async function checkLogIngestionAllowed(tenantId: string, count: number = 1): Promise<boolean> {
  // Get subscription
  const subscriptionJson = await redis.get(`billing:subscription`);
  if (!subscriptionJson) {
    return false; // No subscription
  }
  
  const subscription = JSON.parse(subscriptionJson);
  
  // Get plan
  const plan = subscriptionPlans.find(p => p.id === subscription.planId);
  if (!plan) {
    return false; // Plan not found
  }
  
  // Get today's usage
  const today = new Date().toISOString().split('T')[0];
  const usageKey = `billing:usage:logs:${today}`;
  const currentUsage = parseInt(await redis.get(usageKey) || '0');
  
  // Check if adding more logs would exceed the limit
  if (currentUsage + count > plan.features.maxLogsPerDay) {
    return false; // Limit exceeded
  }
  
  return true;
}

// Track log usage
async function trackLogUsage(tenantId: string, count: number = 1): Promise<void> {
  const today = new Date().toISOString().split('T')[0];
  const usageKey = `billing:usage:logs:${today}`;
  
  // Increment usage counter
  await redis.incrby(usageKey, count);
  
  // Set expiry for automatic cleanup (keep for 90 days)
  await redis.expire(usageKey, 90 * 24 * 60 * 60);
  
  // Update monthly total
  const month = today.substring(0, 7); // YYYY-MM
  const monthlyKey = `billing:usage:logs:${month}`;
  await redis.incrby(monthlyKey, count);
  await redis.expire(monthlyKey, 366 * 24 * 60 * 60); // Keep for a year
}
```

## Stripe Integration

### Stripe Setup

```typescript
// Stripe integration
import Stripe from 'stripe';
import { Redis } from 'ioredis';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const redis = new Redis(process.env.REDIS_URL);

// Initialize Stripe products and prices
async function initializeStripePlans(): Promise<void> {
  for (const plan of subscriptionPlans) {
    // Skip free plan
    if (plan.price === 0) continue;
    
    // Create or update product
    let product;
    try {
      product = await stripe.products.retrieve(`product_${plan.id}`);
      
      // Update product if it exists
      product = await stripe.products.update(`product_${plan.id}`, {
        name: plan.name,
        description: plan.description,
        metadata: {
          planId: plan.id
        }
      });
    } catch (error) {
      // Create product if it doesn't exist
      product = await stripe.products.create({
        id: `product_${plan.id}`,
        name: plan.name,
        description: plan.description,
        metadata: {
          planId: plan.id
        }
      });
    }
    
    // Create or update price
    try {
      await stripe.prices.retrieve(`price_${plan.id}`);
    } catch (error) {
      await stripe.prices.create({
        id: `price_${plan.id}`,
        product: product.id,
        unit_amount: plan.price * 100, // Convert to cents
        currency: 'usd',
        recurring: {
          interval: plan.billingCycle
        },
        metadata: {
          planId: plan.id
        }
      });
    }
  }
}
```

### Subscription Management

```typescript
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

// Update subscription
async function updateSubscription(tenantId: string, planId: string): Promise<any> {
  // Get current subscription
  const subscriptionJson = await redis.get(`billing:subscription`);
  if (!subscriptionJson) {
    throw new Error('No subscription found');
  }
  
  const subscription = JSON.parse(subscriptionJson);
  
  // Get plan
  const plan = subscriptionPlans.find(p => p.id === planId);
  if (!plan) {
    throw new Error('Plan not found');
  }
  
  // Handle transition to/from free plan
  if (plan.price === 0) {
    // Cancel Stripe subscription if exists
    if (subscription.stripeSubscriptionId) {
      await stripe.subscriptions.cancel(subscription.stripeSubscriptionId);
    }
    
    // Create free subscription
    const freeSubscription = {
      id: `free-${tenantId}`,
      planId,
      status: 'active',
      currentPeriodStart: new Date(),
      currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
    };
    
    await redis.set(`billing:subscription`, JSON.stringify(freeSubscription));
    return freeSubscription;
  }
  
  // Handle paid plan
  if (!subscription.stripeSubscriptionId) {
    throw new Error('Cannot update subscription without payment method');
  }
  
  // Update Stripe subscription
  const stripeSubscription = await stripe.subscriptions.retrieve(subscription.stripeSubscriptionId);
  
  await stripe.subscriptions.update(subscription.stripeSubscriptionId, {
    items: [
      {
        id: stripeSubscription.items.data[0].id,
        price: `price_${planId}`
      }
    ]
  });
  
  // Update subscription in Redis
  subscription.planId = planId;
  await redis.set(`billing:subscription`, JSON.stringify(subscription));
  
  return subscription;
}

// Cancel subscription
async function cancelSubscription(tenantId: string): Promise<void> {
  // Get current subscription
  const subscriptionJson = await redis.get(`billing:subscription`);
  if (!subscriptionJson) {
    throw new Error('No subscription found');
  }
  
  const subscription = JSON.parse(subscriptionJson);
  
  // Cancel Stripe subscription if exists
  if (subscription.stripeSubscriptionId) {
    await stripe.subscriptions.cancel(subscription.stripeSubscriptionId);
  }
  
  // Delete subscription from Redis
  await redis.del(`billing:subscription`);
}
```

### Payment Method Management

```typescript
// Get payment methods
async function getPaymentMethods(tenantId: string): Promise<any[]> {
  // Get tenant
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (!tenantJson) {
    throw new Error('Tenant not found');
  }
  
  const tenant = JSON.parse(tenantJson);
  
  // No Stripe customer ID means no payment methods
  if (!tenant.stripeCustomerId) {
    return [];
  }
  
  // Get payment methods from Stripe
  const paymentMethods = await stripe.paymentMethods.list({
    customer: tenant.stripeCustomerId,
    type: 'card'
  });
  
  return paymentMethods.data.map(pm => ({
    id: pm.id,
    brand: pm.card.brand,
    last4: pm.card.last4,
    expMonth: pm.card.exp_month,
    expYear: pm.card.exp_year,
    isDefault: pm.id === tenant.defaultPaymentMethodId
  }));
}

// Add payment method
async function addPaymentMethod(tenantId: string, paymentMethodId: string, setDefault: boolean = false): Promise<void> {
  // Get tenant
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (!tenantJson) {
    throw new Error('Tenant not found');
  }
  
  const tenant = JSON.parse(tenantJson);
  
  // Create Stripe customer if doesn't exist
  if (!tenant.stripeCustomerId) {
    const customer = await stripe.customers.create({
      name: tenant.name,
      email: tenant.adminEmail,
      metadata: {
        tenantId
      }
    });
    
    tenant.stripeCustomerId = customer.id;
  }
  
  // Attach payment method to customer
  await stripe.paymentMethods.attach(paymentMethodId, {
    customer: tenant.stripeCustomerId
  });
  
  // Set as default if requested
  if (setDefault) {
    await stripe.customers.update(tenant.stripeCustomerId, {
      invoice_settings: {
        default_payment_method: paymentMethodId
      }
    });
    
    tenant.defaultPaymentMethodId = paymentMethodId;
  }
  
  // Update tenant in Redis
  await redis.set(`tenants:${tenantId}`, JSON.stringify(tenant));
}

// Remove payment method
async function removePaymentMethod(tenantId: string, paymentMethodId: string): Promise<void> {
  // Get tenant
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (!tenantJson) {
    throw new Error('Tenant not found');
  }
  
  const tenant = JSON.parse(tenantJson);
  
  // No Stripe customer ID means no payment methods
  if (!tenant.stripeCustomerId) {
    throw new Error('No payment methods found');
  }
  
  // Check if this is the default payment method
  if (tenant.defaultPaymentMethodId === paymentMethodId) {
    throw new Error('Cannot remove default payment method');
  }
  
  // Detach payment method
  await stripe.paymentMethods.detach(paymentMethodId);
}
```

## Usage Tracking and Billing

### Usage Tracking

```typescript
// Track resource usage
async function trackResourceUsage(tenantId: string, resourceType: string, quantity: number): Promise<void> {
  const today = new Date().toISOString().split('T')[0];
  const month = today.substring(0, 7); // YYYY-MM
  
  // Daily usage
  const dailyKey = `billing:usage:${resourceType}:${today}`;
  await redis.incrby(dailyKey, quantity);
  await redis.expire(dailyKey, 90 * 24 * 60 * 60); // Keep for 90 days
  
  // Monthly usage
  const monthlyKey = `billing:usage:${resourceType}:${month}`;
  await redis.incrby(monthlyKey, quantity);
  await redis.expire(monthlyKey, 366 * 24 * 60 * 60); // Keep for a year
}

// Get usage statistics
async function getUsageStatistics(tenantId: string, month: string): Promise<any> {
  // Get usage for each resource type
  const logs = parseInt(await redis.get(`billing:usage:logs:${month}`) || '0');
  const storage = parseInt(await redis.get(`billing:usage:storage:${month}`) || '0');
  const apiCalls = parseInt(await redis.get(`billing:usage:api:${month}`) || '0');
  
  return {
    month,
    resources: {
      logs,
      storage,
      apiCalls
    }
  };
}
```

### Invoice Generation

```typescript
// Generate invoice
async function generateInvoice(tenantId: string, month: string): Promise<any> {
  // Get tenant
  const tenantJson = await redis.get(`tenants:${tenantId}`);
  if (!tenantJson) {
    throw new Error('Tenant not found');
  }
  
  const tenant = JSON.parse(tenantJson);
  
  // Get subscription
  const subscriptionJson = await redis.get(`billing:subscription`);
  if (!subscriptionJson) {
    throw new Error('No subscription found');
  }
  
  const subscription = JSON.parse(subscriptionJson);
  
  // Get plan
  const plan = subscriptionPlans.find(p => p.id === subscription.planId);
  if (!plan) {
    throw new Error('Plan not found');
  }
  
  // Get usage statistics
  const usage = await getUsageStatistics(tenantId, month);
  
  // Create invoice
  const invoice = {
    id: `inv-${tenantId}-${month}`,
    tenantId,
    tenantName: tenant.name,
    month,
    createdAt: new Date(),
    subscription: {
      planId: plan.id,
      planName: plan.name,
      price: plan.price
    },
    usage: {
      logs: usage.resources.logs,
      storage: usage.resources.storage,
      apiCalls: usage.resources.apiCalls
    },
    total: plan.price, // Base price only for MVP
    status: 'pending'
  };
  
  // Store invoice in Redis
  await redis.set(`billing:invoices:${invoice.id}`, JSON.stringify(invoice));
  
  // Add to invoice list
  await redis.sadd(`billing:tenant:invoices:${tenantId}`, invoice.id);
  
  return invoice;
}

// Get invoice
async function getInvoice(tenantId: string, invoiceId: string): Promise<any> {
  const invoiceJson = await redis.get(`billing:invoices:${invoiceId}`);
  if (!invoiceJson) {
    throw new Error('Invoice not found');
  }
  
  return JSON.parse(invoiceJson);
}

// List invoices
async function listInvoices(tenantId: string): Promise<any[]> {
  const invoiceIds = await redis.smembers(`billing:tenant:invoices:${tenantId}`);
  
  if (invoiceIds.length === 0) {
    return [];
  }
  
  const pipeline = redis.pipeline();
  for (const invoiceId of invoiceIds) {
    pipeline.get(`billing:invoices:${invoiceId}`);
  }
  
  const results = await pipeline.exec();
  return results
    .filter(result => result[1])
    .map(result => JSON.parse(result[1] as string))
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}
```

## Webhook Handling

### Stripe Webhook Handler

```typescript
// Stripe webhook handler
import express from 'express';
import Stripe from 'stripe';
import { Redis } from 'ioredis';

const app = express();
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const redis = new Redis(process.env.REDIS_URL);

// Parse raw body for Stripe webhook
app.use('/webhooks/stripe', express.raw({ type: 'application/json' }));

// Stripe webhook endpoint
app.post('/webhooks/stripe', async (req, res) => {
  const sig = req.headers['stripe-signature'];
  
  let event;
  
  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }
  
  // Handle the event
  switch (event.type) {
    case 'invoice.payment_succeeded':
      await handleInvoicePaymentSucceeded(event.data.object);
      break;
    case 'invoice.payment_failed':
      await handleInvoicePaymentFailed(event.data.object);
      break;
    case 'customer.subscription.updated':
      await handleSubscriptionUpdated(event.data.object);
      break;
    case 'customer.subscription.deleted':
      await handleSubscriptionDeleted(event.data.object);
      break;
    default:
      console.log(`Unhandled event type ${event.type}`);
  }
  
  res.json({ received: true });
});

// Handle invoice payment succeeded
async function handleInvoicePaymentSucceeded(invoice): Promise<void> {
  const tenantId = invoice.metadata.tenantId;
  if (!tenantId) return;
  
  // Update invoice status
  const invoiceId = `inv-${tenantId}-${new Date(invoice.created * 1000).toISOString().substring(0, 7)}`;
  const invoiceJson = await redis.get(`billing:invoices:${invoiceId}`);
  
  if (invoiceJson) {
    const invoiceData = JSON.parse(invoiceJson);
    invoiceData.status = 'paid';
    invoiceData.paidAt = new Date();
    invoiceData.stripeInvoiceId = invoice.id;
    
    await redis.set(`billing:invoices:${invoiceId}`, JSON.stringify(invoiceData));
  }
}

// Handle invoice payment failed
async function handleInvoicePaymentFailed(invoice): Promise<void> {
  const tenantId = invoice.metadata.tenantId;
  if (!tenantId) return;
  
  // Update invoice status
  const invoiceId = `inv-${tenantId}-${new Date(invoice.created * 1000).toISOString().substring(0, 7)}`;
  const invoiceJson = await redis.get(`billing:invoices:${invoiceId}`);
  
  if (invoiceJson) {
    const invoiceData = JSON.parse(invoiceJson);
    invoiceData.status = 'failed';
    invoiceData.failedAt = new Date();
    invoiceData.stripeInvoiceId = invoice.id;
    
    await redis.set(`billing:invoices:${invoiceId}`, JSON.stringify(invoiceData));
  }
}

// Handle subscription updated
async function handleSubscriptionUpdated(subscription): Promise<void> {
  const tenantId = subscription.metadata.tenantId;
  if (!tenantId) return;
  
  // Get current subscription from Redis
  const subscriptionJson = await redis.get(`billing:subscription`);
  if (!subscriptionJson) return;
  
  const currentSubscription = JSON.parse(subscriptionJson);
  
  // Update subscription in Redis
  currentSubscription.status = subscription.status;
  currentSubscription.currentPeriodStart = new Date(subscription.current_period_start * 1000);
  currentSubscription.currentPeriodEnd = new Date(subscription.current_period_end * 1000);
  
  await redis.set(`billing:subscription`, JSON.stringify(currentSubscription));
}

// Handle subscription deleted
async function handleSubscriptionDeleted(subscription): Promise<void> {
  const tenantId = subscription.metadata.tenantId;
  if (!tenantId) return;
  
  // Get current subscription from Redis
  const subscriptionJson = await redis.get(`billing:subscription`);
  if (!subscriptionJson) return;
  
  const currentSubscription = JSON.parse(subscriptionJson);
  
  // Only delete if it's the same subscription
  if (currentSubscription.stripeSubscriptionId === subscription.id) {
    // Create free plan subscription
    const freeSubscription = {
      id: `free-${tenantId}`,
      planId: 'free',
      status: 'active',
      currentPeriodStart: new Date(),
      currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
    };
    
    await redis.set(`billing:subscription`, JSON.stringify(freeSubscription));
  }
}

app.listen(3000, () => {
  console.log('Webhook handler running on port 3000');
});
```

## Admin Interface

### Billing Dashboard

```typescript
// Next.js billing dashboard page
// app/admin/billing/page.tsx
import { getSubscription, listInvoices, getUsageStatistics } from '@/lib/billing';

export default async function BillingDashboardPage() {
  const subscription = await getSubscription();
  const invoices = await listInvoices();
  const currentMonth = new Date().toISOString().substring(0, 7);
  const usage = await getUsageStatistics(currentMonth);
  
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6">Billing Dashboard</h1>
      
      {/* Subscription Information */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <h2 className="text-xl font-semibold mb-4">Subscription</h2>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <p className="text-gray-600">Plan</p>
            <p className="font-medium">{subscription.planName}</p>
          </div>
          <div>
            <p className="text-gray-600">Status</p>
            <p className="font-medium">{subscription.status}</p>
          </div>
          <div>
            <p className="text-gray-600">Current Period</p>
            <p className="font-medium">
              {new Date(subscription.currentPeriodStart).toLocaleDateString()} to {new Date(subscription.currentPeriodEnd).toLocaleDateString()}
            </p>
          </div>
          <div>
            <p className="text-gray-600">Price</p>
            <p className="font-medium">${subscription.price}/month</p>
          </div>
        </div>
        <div className="mt-4">
          <button className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">
            Change Plan
          </button>
        </div>
      </div>
      
      {/* Usage Information */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <h2 className="text-xl font-semibold mb-4">Current Usage</h2>
        <div className="grid grid-cols-3 gap-4">
          <div>
            <p className="text-gray-600">Logs</p>
            <p className="font-medium">{usage.resources.logs.toLocaleString()}</p>
          </div>
          <div>
            <p className="text-gray-600">Storage</p>
            <p className="font-medium">{(usage.resources.storage / 1024 / 1024).toFixed(2)} MB</p>
          </div>
          <div>
            <p className="text-gray-600">API Calls</p>
            <p className="font-medium">{usage.resources.apiCalls.toLocaleString()}</p>
          </div>
        </div>
      </div>
      
      {/* Invoices */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-xl font-semibold mb-4">Invoices</h2>
        <table className="w-full">
          <thead>
            <tr className="border-b">
              <th className="text-left py-2">Invoice</th>
              <th className="text-left py-2">Date</th>
              <th className="text-left py-2">Amount</th>
              <th className="text-left py-2">Status</th>
              <th className="text-left py-2">Actions</th>
            </tr>
          </thead>
          <tbody>
            {invoices.map(invoice => (
              <tr key={invoice.id} className="border-b">
                <td className="py-2">{invoice.id}</td>
                <td className="py-2">{new Date(invoice.createdAt).toLocaleDateString()}</td>
                <td className="py-2">${invoice.total}</td>
                <td className="py-2">{invoice.status}</td>
                <td className="py-2">
                  <button className="text-blue-500 hover:text-blue-700">
                    View
                  </button>
                </td>
              </tr>
            ))}
            {invoices.length === 0 && (
              <tr>
                <td colSpan={5} className="py-4 text-center text-gray-500">
                  No invoices found
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
```

## Implementation Guidelines

1. **Start Simple**: Begin with basic subscription plans
2. **Automate Billing**: Use Stripe for payment processing
3. **Track Usage**: Implement usage tracking from day one
4. **Clear Pricing**: Make pricing transparent to users
5. **Flexible Plans**: Design plans that can evolve over time
6. **Proper Testing**: Test billing flows thoroughly
7. **Error Handling**: Handle payment failures gracefully
