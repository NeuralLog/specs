# Billing Integration Implementation

## Overview

This specification outlines the implementation of the billing system for NeuralLog, which is the third highest priority after the core Redis logging infrastructure and Vercel frontend.

## Components

1. **Subscription Plans Setup**
2. **Stripe Integration**
3. **Usage Tracking**
4. **Billing UI**

## Implementation Steps

### 1. Subscription Plans Setup

- Define subscription plans
- Implement plan features and limits
- Create plan management API

```typescript
// Subscription plan definitions
const subscriptionPlans = [
  {
    id: 'free',
    name: 'Free',
    description: 'For individuals and small projects',
    price: 0,
    features: {
      logRetention: 7, // days
      maxLogsPerDay: 1000,
      maxUsers: 1,
      supportLevel: 'community'
    }
  },
  {
    id: 'basic',
    name: 'Basic',
    description: 'For small teams and growing projects',
    price: 29,
    features: {
      logRetention: 30, // days
      maxLogsPerDay: 10000,
      maxUsers: 5,
      supportLevel: 'email'
    }
  },
  {
    id: 'pro',
    name: 'Professional',
    description: 'For professional teams and serious applications',
    price: 99,
    features: {
      logRetention: 90, // days
      maxLogsPerDay: 100000,
      maxUsers: 20,
      supportLevel: 'priority'
    }
  }
];
```

### 2. Stripe Integration

- Set up Stripe account and API keys
- Implement subscription creation
- Handle payment methods

```typescript
// Stripe integration
import Stripe from 'stripe';
import { Redis } from 'ioredis';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const redis = new Redis(process.env.REDIS_URL);

// Create subscription
async function createSubscription(tenantId, planId, paymentMethodId) {
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

### 3. Usage Tracking

- Implement log usage tracking
- Track storage usage
- Enforce usage limits

```typescript
// Track log usage
async function trackLogUsage(tenantId, count = 1, namespace) {
  const today = new Date().toISOString().split('T')[0];
  
  // Base usage key (no namespace)
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
  
  // If namespace is provided, track namespace-specific usage
  if (namespace) {
    const namespaceUsageKey = `billing:usage:logs:${namespace}:${today}`;
    await redis.incrby(namespaceUsageKey, count);
    await redis.expire(namespaceUsageKey, 90 * 24 * 60 * 60);
    
    const namespaceMonthlyKey = `billing:usage:logs:${namespace}:${month}`;
    await redis.incrby(namespaceMonthlyKey, count);
    await redis.expire(namespaceMonthlyKey, 366 * 24 * 60 * 60);
  }
}

// Check if log ingestion is allowed based on plan limits
async function checkLogIngestionAllowed(tenantId, count = 1) {
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
```

### 4. Billing UI

- Create subscription management UI
- Implement payment method management
- Display usage and invoices

```jsx
// SubscriptionManagement.jsx
"use client";

import { useState, useEffect } from "react";
import { loadStripe } from "@stripe/stripe-js";
import { Elements, CardElement, useStripe, useElements } from "@stripe/react-stripe-js";

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY);

export default function SubscriptionPage() {
  const [subscription, setSubscription] = useState(null);
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      
      // Fetch subscription
      const subRes = await fetch("/api/billing/subscription");
      const subData = await subRes.json();
      
      // Fetch plans
      const plansRes = await fetch("/api/billing/plans");
      const plansData = await plansRes.json();
      
      setSubscription(subData);
      setPlans(plansData.plans);
      setLoading(false);
    }
    
    fetchData();
  }, []);
  
  if (loading) {
    return <div>Loading...</div>;
  }
  
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Subscription Management</h1>
      
      {/* Current Subscription */}
      <div className="bg-white p-4 rounded shadow">
        <h2 className="text-xl font-semibold mb-4">Current Subscription</h2>
        {subscription ? (
          <div>
            <p><strong>Plan:</strong> {subscription.planName}</p>
            <p><strong>Status:</strong> {subscription.status}</p>
            <p><strong>Current Period:</strong> {new Date(subscription.currentPeriodStart).toLocaleDateString()} to {new Date(subscription.currentPeriodEnd).toLocaleDateString()}</p>
          </div>
        ) : (
          <p>No active subscription</p>
        )}
      </div>
      
      {/* Available Plans */}
      <div className="bg-white p-4 rounded shadow">
        <h2 className="text-xl font-semibold mb-4">Available Plans</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {plans.map((plan) => (
            <div 
              key={plan.id} 
              className={`border rounded p-4 ${subscription?.planId === plan.id ? 'border-blue-500 bg-blue-50' : ''}`}
            >
              <h3 className="text-lg font-semibold">{plan.name}</h3>
              <p className="text-gray-600">{plan.description}</p>
              <p className="text-2xl font-bold my-2">${plan.price}/month</p>
              <ul className="space-y-2 mb-4">
                <li>• {plan.features.maxLogsPerDay.toLocaleString()} logs/day</li>
                <li>• {plan.features.logRetention} days retention</li>
                <li>• {plan.features.maxUsers} users</li>
                <li>• {plan.features.supportLevel} support</li>
              </ul>
              {subscription?.planId !== plan.id && (
                <button 
                  className="w-full bg-blue-500 text-white py-2 rounded"
                  onClick={() => handleChangePlan(plan.id)}
                >
                  {plan.price === 0 ? 'Select Free Plan' : 'Select Plan'}
                </button>
              )}
              {subscription?.planId === plan.id && (
                <div className="text-center py-2 text-blue-700 font-semibold">
                  Current Plan
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
      
      {/* Payment Method */}
      {subscription && subscription.planId !== 'free' && (
        <div className="bg-white p-4 rounded shadow">
          <h2 className="text-xl font-semibold mb-4">Payment Method</h2>
          <Elements stripe={stripePromise}>
            <PaymentMethodForm />
          </Elements>
        </div>
      )}
    </div>
  );
}

function PaymentMethodForm() {
  const stripe = useStripe();
  const elements = useElements();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);
  
  async function handleSubmit(e) {
    e.preventDefault();
    
    if (!stripe || !elements) {
      return;
    }
    
    setLoading(true);
    setError(null);
    
    // Create payment method
    const result = await stripe.createPaymentMethod({
      type: 'card',
      card: elements.getElement(CardElement)
    });
    
    if (result.error) {
      setError(result.error.message);
      setLoading(false);
      return;
    }
    
    // Send to server
    const res = await fetch("/api/billing/payment-methods", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ 
        paymentMethodId: result.paymentMethod.id,
        setDefault: true
      })
    });
    
    if (res.ok) {
      setSuccess(true);
      elements.getElement(CardElement).clear();
    } else {
      const data = await res.json();
      setError(data.error || "Failed to save payment method");
    }
    
    setLoading(false);
  }
  
  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="border rounded p-3">
        <CardElement options={{
          style: {
            base: {
              fontSize: '16px',
              color: '#424770',
              '::placeholder': {
                color: '#aab7c4',
              },
            },
            invalid: {
              color: '#9e2146',
            },
          },
        }} />
      </div>
      
      {error && (
        <div className="text-red-500">{error}</div>
      )}
      
      {success && (
        <div className="text-green-500">Payment method added successfully!</div>
      )}
      
      <button 
        type="submit" 
        className="bg-blue-500 text-white px-4 py-2 rounded"
        disabled={!stripe || loading}
      >
        {loading ? "Processing..." : "Add Payment Method"}
      </button>
    </form>
  );
}
```

## Webhook Handling

- Implement Stripe webhook handler
- Process subscription events
- Handle payment failures

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
```

## Testing Plan

1. **Unit Tests**:
   - Test subscription management
   - Test usage tracking
   - Test plan limits

2. **Integration Tests**:
   - Test Stripe integration
   - Test webhook handling

3. **E2E Tests**:
   - Test subscription workflow
   - Test payment method management

## Deliverables

1. Subscription plan definitions
2. Stripe integration code
3. Usage tracking implementation
4. Billing UI components
5. Webhook handlers

## Success Criteria

1. Users can subscribe to plans
2. Usage is tracked accurately
3. Plan limits are enforced
4. Billing UI works correctly
5. Webhooks handle Stripe events properly
