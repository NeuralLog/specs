# NeuralLog Billing System Specification

## Overview

The NeuralLog Billing System manages subscriptions, payments, and usage tracking for the cloud-hosted version of NeuralLog. It provides a flexible, scalable billing infrastructure that supports various pricing models, payment methods, and billing cycles.

## Key Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Billing System                          │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Subscription│  │ Payment     │  │ Usage Tracking      │  │
│  │ Management  │  │ Processing  │  │                     │  │
│  │             │  │             │  │ • Metering          │  │
│  │ • Plans     │  │ • Gateways  │  │ • Aggregation       │  │
│  │ • Cycles    │  │ • Methods   │  │ • Quotas            │  │
│  │ • Features  │  │ • Security  │  │ • Reporting         │  │
│  │             │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Invoicing   │  │ Tax         │  │ Reporting &         │  │
│  │             │  │ Management  │  │ Analytics           │  │
│  │ • Generation│  │             │  │                     │  │
│  │ • History   │  │ • Rates     │  │ • Revenue           │  │
│  │ • Templates │  │ • Rules     │  │ • Conversion        │  │
│  │ • Delivery  │  │ • Compliance│  │ • Churn             │  │
│  │             │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 1. Subscription Management

### Subscription Plans

- **Free Tier**:
  - Limited features and capacity
  - No payment required
  - Time-limited or feature-limited

- **Basic Plan**:
  - Core features
  - Moderate capacity
  - Standard support

- **Professional Plan**:
  - Advanced features
  - Higher capacity
  - Priority support

- **Enterprise Plan**:
  - All features
  - Custom capacity
  - Dedicated support
  - Custom contracts

### Plan Features

Each plan includes a specific set of features and limits:

- **Log Volume**: Maximum number of log entries per day/month
- **Retention Period**: How long logs are stored
- **Users**: Number of user accounts
- **Organizations**: Number of organizations
- **Rules**: Number of rules that can be created
- **Actions**: Types of actions available
- **API Rate Limits**: Maximum API calls per minute/hour
- **Support Level**: Support response time and channels

### Billing Cycles

- **Monthly**: Billed every month
- **Annual**: Billed yearly with discount
- **Custom**: Enterprise-specific billing cycles

### Plan Management API

```typescript
interface SubscriptionAPI {
  // Get available plans
  getPlans(): Promise<Plan[]>;
  
  // Get tenant subscription
  getSubscription(tenantId: string): Promise<Subscription>;
  
  // Create new subscription
  createSubscription(tenantId: string, planId: string, params: SubscriptionParams): Promise<Subscription>;
  
  // Update subscription
  updateSubscription(subscriptionId: string, params: UpdateSubscriptionParams): Promise<Subscription>;
  
  // Cancel subscription
  cancelSubscription(subscriptionId: string, reason?: string): Promise<Subscription>;
  
  // Change plan
  changePlan(subscriptionId: string, newPlanId: string): Promise<Subscription>;
}

interface Plan {
  id: string;
  name: string;
  description: string;
  price: {
    monthly: number;
    annual: number;
  };
  features: Record<string, any>;
  limits: Record<string, number>;
}

interface Subscription {
  id: string;
  tenantId: string;
  planId: string;
  status: 'active' | 'canceled' | 'past_due' | 'trialing';
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  cancelAtPeriodEnd: boolean;
  trialEnd?: Date;
  paymentMethodId?: string;
}
```

## 2. Payment Processing

### Payment Gateways

- **Stripe**: Primary payment processor
- **PayPal**: Alternative payment option
- **Bank Transfer**: For enterprise customers
- **Invoice Payment**: For enterprise customers

### Payment Methods

- **Credit/Debit Cards**
- **ACH/Direct Debit**
- **PayPal**
- **Wire Transfer**
- **Digital Wallets** (Apple Pay, Google Pay)

### Security Measures

- **PCI Compliance**: Follow PCI DSS requirements
- **Tokenization**: Store tokens instead of card details
- **3D Secure**: Additional authentication layer
- **Fraud Detection**: Automated fraud prevention
- **Encryption**: Encrypt sensitive payment data

### Payment API

```typescript
interface PaymentAPI {
  // Add payment method
  addPaymentMethod(tenantId: string, paymentDetails: PaymentMethodDetails): Promise<PaymentMethod>;
  
  // Get payment methods
  getPaymentMethods(tenantId: string): Promise<PaymentMethod[]>;
  
  // Set default payment method
  setDefaultPaymentMethod(tenantId: string, paymentMethodId: string): Promise<void>;
  
  // Remove payment method
  removePaymentMethod(tenantId: string, paymentMethodId: string): Promise<void>;
  
  // Process payment
  processPayment(tenantId: string, amount: number, currency: string): Promise<PaymentResult>;
}

interface PaymentMethod {
  id: string;
  type: 'card' | 'bank_account' | 'paypal' | 'other';
  isDefault: boolean;
  details: {
    last4?: string;
    brand?: string;
    expiryMonth?: number;
    expiryYear?: number;
    // Other payment method specific details
  };
}

interface PaymentResult {
  success: boolean;
  transactionId?: string;
  error?: string;
}
```

## 3. Usage Tracking

### Metering

- **Log Volume**: Count of log entries ingested
- **Storage**: Amount of storage used
- **API Calls**: Number of API requests
- **Actions Executed**: Count of actions triggered
- **Users**: Active user count
- **Organizations**: Active organization count

### Usage Aggregation

- **Real-time Aggregation**: Immediate usage updates
- **Daily Rollups**: Daily usage summaries
- **Monthly Totals**: Monthly usage for billing
- **Custom Periods**: Enterprise-specific periods

### Quota Management

- **Soft Limits**: Warning when approaching limits
- **Hard Limits**: Enforce strict usage limits
- **Overage Handling**: Configure behavior when limits exceeded
- **Auto-scaling**: Automatically adjust limits based on usage

### Usage API

```typescript
interface UsageAPI {
  // Get current usage
  getCurrentUsage(tenantId: string): Promise<Usage>;
  
  // Get historical usage
  getHistoricalUsage(tenantId: string, period: 'day' | 'week' | 'month', start: Date, end: Date): Promise<UsageHistory>;
  
  // Get quota status
  getQuotaStatus(tenantId: string): Promise<QuotaStatus>;
  
  // Update quota
  updateQuota(tenantId: string, quotaUpdates: QuotaUpdates): Promise<QuotaStatus>;
}

interface Usage {
  tenantId: string;
  timestamp: Date;
  metrics: {
    logVolume: number;
    storage: number;
    apiCalls: number;
    actionsExecuted: number;
    activeUsers: number;
    activeOrganizations: number;
  };
}

interface QuotaStatus {
  tenantId: string;
  quotas: {
    logVolume: { limit: number; used: number; remaining: number };
    storage: { limit: number; used: number; remaining: number };
    apiCalls: { limit: number; used: number; remaining: number };
    actionsExecuted: { limit: number; used: number; remaining: number };
    users: { limit: number; used: number; remaining: number };
    organizations: { limit: number; used: number; remaining: number };
  };
}
```

## 4. Invoicing

### Invoice Generation

- **Automatic Generation**: Based on billing cycle
- **Manual Generation**: For custom invoices
- **Prorated Invoices**: For mid-cycle changes
- **Credit Notes**: For refunds and adjustments

### Invoice History

- **Storage**: Long-term storage of all invoices
- **Retrieval**: Easy access to past invoices
- **Audit Trail**: Track invoice-related activities

### Invoice Templates

- **Customizable Templates**: Brand-specific invoicing
- **Multiple Formats**: PDF, HTML, CSV
- **Localization**: Multi-language support
- **Legal Compliance**: Region-specific requirements

### Invoice Delivery

- **Email**: Automatic email delivery
- **Portal**: Available in tenant portal
- **API**: Programmatic access
- **Download**: Direct download options

### Invoicing API

```typescript
interface InvoiceAPI {
  // Get invoices
  getInvoices(tenantId: string, params?: InvoiceQueryParams): Promise<Invoice[]>;
  
  // Get invoice by ID
  getInvoice(invoiceId: string): Promise<Invoice>;
  
  // Generate invoice
  generateInvoice(tenantId: string, params: InvoiceGenerationParams): Promise<Invoice>;
  
  // Send invoice
  sendInvoice(invoiceId: string, destination: string): Promise<void>;
  
  // Mark invoice as paid
  markAsPaid(invoiceId: string, paymentDetails: PaymentDetails): Promise<Invoice>;
}

interface Invoice {
  id: string;
  tenantId: string;
  number: string;
  status: 'draft' | 'open' | 'paid' | 'void' | 'uncollectible';
  currency: string;
  amount: number;
  tax: number;
  total: number;
  issuedAt: Date;
  dueAt: Date;
  paidAt?: Date;
  lineItems: InvoiceLineItem[];
}

interface InvoiceLineItem {
  description: string;
  quantity: number;
  unitPrice: number;
  amount: number;
  taxRate?: number;
  taxAmount?: number;
}
```

## 5. Tax Management

### Tax Rates

- **Regional Rates**: Country, state, and local tax rates
- **VAT/GST**: Value-added tax and goods and services tax
- **Special Taxes**: Industry-specific taxes
- **Tax Exemptions**: Handle tax-exempt customers

### Tax Rules

- **Tax Determination**: Determine applicable taxes
- **Tax Calculation**: Calculate correct tax amounts
- **Digital Services Tax**: Handle digital service taxes
- **B2B vs B2C**: Different rules for business vs consumer

### Tax Compliance

- **Tax Filing**: Support for tax filing requirements
- **Tax Reports**: Generate tax reports
- **Documentation**: Maintain required documentation
- **Regulatory Updates**: Stay current with tax laws

### Tax API

```typescript
interface TaxAPI {
  // Calculate tax
  calculateTax(params: TaxCalculationParams): Promise<TaxCalculation>;
  
  // Get tax rates
  getTaxRates(country: string, state?: string, city?: string): Promise<TaxRate[]>;
  
  // Set tax exemption
  setTaxExemption(tenantId: string, exemptionDetails: TaxExemptionDetails): Promise<void>;
  
  // Generate tax report
  generateTaxReport(period: 'month' | 'quarter' | 'year', start: Date, end: Date): Promise<TaxReport>;
}

interface TaxCalculationParams {
  tenantId: string;
  amount: number;
  currency: string;
  country: string;
  state?: string;
  city?: string;
  postalCode?: string;
  isBusinessCustomer?: boolean;
  taxId?: string;
}

interface TaxCalculation {
  subtotal: number;
  taxableAmount: number;
  taxAmount: number;
  total: number;
  taxBreakdown: TaxBreakdownItem[];
}

interface TaxBreakdownItem {
  taxType: string;
  taxRate: number;
  taxableAmount: number;
  taxAmount: number;
}
```

## 6. Reporting & Analytics

### Revenue Analytics

- **MRR/ARR**: Monthly/Annual Recurring Revenue
- **Revenue Growth**: Track revenue growth over time
- **Revenue by Plan**: Revenue breakdown by plan
- **Revenue by Region**: Geographic revenue distribution
- **Forecasting**: Revenue projections

### Conversion Analytics

- **Trial Conversion**: Track trial to paid conversion
- **Upgrade Rates**: Track plan upgrade frequency
- **Downgrade Rates**: Track plan downgrade frequency
- **Conversion Funnel**: Analyze conversion steps

### Churn Analytics

- **Churn Rate**: Customer cancellation rate
- **Churn Reasons**: Track reasons for cancellation
- **Churn Prediction**: Identify at-risk customers
- **Retention Strategies**: Measure retention efforts

### Reporting API

```typescript
interface ReportingAPI {
  // Get revenue report
  getRevenueReport(period: 'day' | 'week' | 'month' | 'year', start: Date, end: Date): Promise<RevenueReport>;
  
  // Get conversion report
  getConversionReport(period: 'day' | 'week' | 'month' | 'year', start: Date, end: Date): Promise<ConversionReport>;
  
  // Get churn report
  getChurnReport(period: 'day' | 'week' | 'month' | 'year', start: Date, end: Date): Promise<ChurnReport>;
  
  // Get custom report
  getCustomReport(reportDefinition: ReportDefinition): Promise<Report>;
}

interface RevenueReport {
  period: string;
  start: Date;
  end: Date;
  totalRevenue: number;
  mrr: number;
  arr: number;
  growth: number;
  revenueByPlan: Record<string, number>;
  revenueByRegion: Record<string, number>;
  forecast: {
    nextMonth: number;
    nextQuarter: number;
    nextYear: number;
  };
}
```

## Integration with Tenant Management

### Tenant Lifecycle Events

- **Tenant Creation**: Initialize billing records
- **Plan Changes**: Update subscription details
- **Tenant Suspension**: Handle billing implications
- **Tenant Deletion**: Finalize billing and generate final invoice

### Free Tier Management

- **Trial Period**: Manage trial duration
- **Usage Limits**: Enforce free tier limits
- **Conversion Prompts**: Encourage upgrade to paid plans
- **Grace Period**: Provide grace period after trial

### Tenant Billing API

```typescript
interface TenantBillingAPI {
  // Initialize billing for new tenant
  initializeBilling(tenantId: string, plan: string): Promise<void>;
  
  // Handle tenant suspension
  suspendBilling(tenantId: string, reason: string): Promise<void>;
  
  // Handle tenant reactivation
  reactivateBilling(tenantId: string): Promise<void>;
  
  // Finalize billing for deleted tenant
  finalizeBilling(tenantId: string): Promise<FinalBillingResult>;
}

interface FinalBillingResult {
  tenantId: string;
  finalInvoiceId?: string;
  refundAmount?: number;
  billingClosed: boolean;
}
```

## Self-Hosted Considerations

For self-hosted deployments, the billing system is optional:

- **License Management**: Alternative to subscription billing
- **Usage Reporting**: Optional anonymous usage reporting
- **Enterprise Licensing**: Support for air-gapped environments
- **License Verification**: Offline license verification

## Implementation Guidelines

### 1. Technology Stack

- **Backend**: Node.js with TypeScript
- **Database**: PostgreSQL for transactional data
- **Queue**: Redis or RabbitMQ for async processing
- **Cache**: Redis for high-speed caching
- **API**: RESTful API with OpenAPI specification

### 2. Integration Points

- **Payment Gateways**: Stripe, PayPal, etc.
- **Accounting Software**: QuickBooks, Xero, etc.
- **Tax Services**: Avalara, TaxJar, etc.
- **CRM**: Salesforce, HubSpot, etc.
- **Email Service**: SendGrid, Mailgun, etc.

### 3. Security Considerations

- **PCI Compliance**: Follow PCI DSS requirements
- **Data Encryption**: Encrypt sensitive billing data
- **Access Control**: Strict RBAC for billing functions
- **Audit Logging**: Comprehensive audit trail
- **Secure API**: Authentication and authorization

### 4. Scalability Considerations

- **Horizontal Scaling**: Scale billing services independently
- **Database Sharding**: Partition data for performance
- **Caching Strategy**: Optimize for read-heavy operations
- **Asynchronous Processing**: Queue-based architecture
- **Batch Processing**: Efficient handling of billing cycles

### 5. Compliance Considerations

- **GDPR**: Data protection and privacy
- **CCPA**: California Consumer Privacy Act
- **SCA**: Strong Customer Authentication
- **SOX**: Sarbanes-Oxley for financial reporting
- **Local Regulations**: Country-specific requirements
