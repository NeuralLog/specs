# NeuralLog Next.js and Vercel Architecture Specification

## Overview

This specification outlines the architecture for deploying NeuralLog's web interfaces using Next.js and Vercel. This modern, serverless approach provides excellent performance, scalability, and developer experience while simplifying deployment and operations.

## Architecture Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Vercel Platform                         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Next.js     │  │ Serverless  │  │ Edge Functions      │  │
│  │ Frontend    │  │ Functions   │  │                     │  │
│  │             │  │             │  │ • Auth              │  │
│  │ • Pages     │  │ • API       │  │ • Middleware        │  │
│  │ • Components│  │   Routes    │  │ • Caching           │  │
│  │ • Static    │  │ • Webhooks  │  │ • A/B Testing       │  │
│  │   Assets    │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     External Services                       │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ NeuralLog   │  │ Auth        │  │ Database            │  │
│  │ API         │  │ Provider    │  │ Services            │  │
│  │             │  │             │  │                     │  │
│  │ • Core API  │  │ • Auth0     │  │ • PostgreSQL        │  │
│  │ • Tenant API│  │ • Clerk     │  │ • MongoDB           │  │
│  │ • Admin API │  │ • NextAuth  │  │ • Redis             │  │
│  │             │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Next.js Application Structure

### 1. Multi-Site Architecture

NeuralLog will use a monorepo approach with multiple Next.js applications:

- **Marketing Site**: Public-facing website and documentation
- **Tenant Portal**: Application for tenant users
- **Admin Dashboard**: Application for NeuralLog administrators

Each application will be deployed as a separate Vercel project with its own domain:

```
neurallog.com            -> Marketing Site
app.neurallog.com        -> Tenant Portal
admin.neurallog.com      -> Admin Dashboard
docs.neurallog.com       -> Documentation
```

### 2. Next.js Features Utilization

#### App Router

The applications will use Next.js App Router for modern React features:

```
app/
├── (marketing)/         # Marketing site routes
│   ├── page.tsx         # Homepage
│   ├── pricing/
│   │   └── page.tsx     # Pricing page
│   └── layout.tsx       # Marketing layout
├── (tenant)/            # Tenant portal routes
│   ├── dashboard/
│   │   └── page.tsx     # Tenant dashboard
│   ├── logs/
│   │   └── page.tsx     # Log explorer
│   └── layout.tsx       # Tenant portal layout
├── (admin)/             # Admin dashboard routes
│   ├── tenants/
│   │   └── page.tsx     # Tenant management
│   ├── billing/
│   │   └── page.tsx     # Billing management
│   └── layout.tsx       # Admin dashboard layout
└── layout.tsx           # Root layout
```

#### Server Components

Leverage React Server Components for improved performance:

- **Server Components**: For data fetching and rendering
- **Client Components**: For interactive elements
- **Streaming**: For progressive rendering of complex pages

#### API Routes

API routes will be organized by domain:

```
app/api/
├── auth/                # Authentication endpoints
│   ├── [...nextauth]/   # NextAuth.js routes
│   └── route.ts         # Custom auth handlers
├── tenant/              # Tenant-specific endpoints
│   ├── logs/
│   │   └── route.ts     # Log management
│   └── rules/
│       └── route.ts     # Rule management
├── admin/               # Admin-only endpoints
│   ├── tenants/
│   │   └── route.ts     # Tenant management
│   └── billing/
│       └── route.ts     # Billing management
└── webhooks/            # External service webhooks
    ├── stripe/
    │   └── route.ts     # Stripe webhook handler
    └── github/
        └── route.ts     # GitHub webhook handler
```

#### Middleware

Middleware for cross-cutting concerns:

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  // Tenant identification
  const hostname = request.headers.get('host');
  const tenantId = extractTenantId(hostname);
  
  // Authentication check
  const session = getSession(request);
  
  // Rate limiting
  const rateLimitResult = checkRateLimit(request);
  
  // Add tenant context to headers
  const response = NextResponse.next();
  response.headers.set('x-tenant-id', tenantId);
  
  return response;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
};
```

### 3. Frontend Architecture

#### Component Library

A shared component library using a modern UI framework:

```
components/
├── ui/                  # Base UI components
│   ├── button.tsx
│   ├── input.tsx
│   └── card.tsx
├── layout/              # Layout components
│   ├── sidebar.tsx
│   ├── header.tsx
│   └── footer.tsx
├── data/                # Data display components
│   ├── table.tsx
│   ├── chart.tsx
│   └── log-viewer.tsx
└── forms/               # Form components
    ├── form.tsx
    ├── field.tsx
    └── select.tsx
```

#### State Management

Combination of server state and client state:

- **React Query/SWR**: For server state management
- **Zustand/Jotai**: For client-side state
- **Context API**: For theme and authentication state

#### Styling Approach

Modern styling with utility-first approach:

- **Tailwind CSS**: For utility-first styling
- **CSS Modules**: For component-specific styles
- **CSS Variables**: For theming and customization

## Vercel Deployment Strategy

### 1. Environment Configuration

Multiple environments with proper configuration:

- **Production**: Live environment (main branch)
- **Staging**: Pre-production testing (staging branch)
- **Preview**: Per-pull request environments
- **Development**: Local development environment

Environment variables managed through Vercel:

```
# Common variables
NEXT_PUBLIC_API_URL=https://api.neurallog.com
NEXT_PUBLIC_APP_URL=https://app.neurallog.com

# Environment-specific variables
DATABASE_URL=postgresql://user:password@host:port/db
REDIS_URL=redis://user:password@host:port

# Service integration
AUTH0_CLIENT_ID=...
AUTH0_CLIENT_SECRET=...
STRIPE_SECRET_KEY=...
STRIPE_WEBHOOK_SECRET=...
```

### 2. Deployment Pipeline

Automated deployment pipeline:

1. **Code Push**: Push to GitHub repository
2. **CI Checks**: Run tests, linting, type checking
3. **Preview Deployment**: Deploy to preview environment
4. **Review**: Manual review of preview deployment
5. **Merge**: Merge PR to main branch
6. **Production Deployment**: Automatic deployment to production

### 3. Performance Optimization

Vercel-specific optimizations:

- **Edge Caching**: Cache static assets at the edge
- **Image Optimization**: Use Next.js Image component
- **ISR**: Incremental Static Regeneration for semi-dynamic content
- **Edge Functions**: Move critical functionality to the edge
- **Analytics**: Use Vercel Analytics for performance monitoring

### 4. Monitoring and Observability

Comprehensive monitoring:

- **Vercel Analytics**: Performance and usage metrics
- **Error Tracking**: Integration with error tracking services
- **Logging**: Structured logging with proper context
- **Alerting**: Alerts for critical issues
- **Status Page**: Public status page for service health

## Integration with NeuralLog Backend

### 1. API Integration

Secure communication with NeuralLog API:

- **Authentication**: JWT-based authentication
- **API Client**: Type-safe API client
- **Error Handling**: Consistent error handling
- **Caching**: Intelligent caching of API responses
- **Retry Logic**: Automatic retry for transient failures

```typescript
// api/neurallog.ts
import { createClient } from '@neurallog/api-client';

export const neuralLogClient = createClient({
  baseUrl: process.env.NEURALLOG_API_URL,
  defaultHeaders: {
    'Content-Type': 'application/json',
  },
});

// Server-side API calls with authentication
export async function fetchWithAuth(endpoint: string, options: RequestInit = {}) {
  const session = await getServerSession();
  
  if (!session?.accessToken) {
    throw new Error('Not authenticated');
  }
  
  return neuralLogClient.fetch(endpoint, {
    ...options,
    headers: {
      ...options.headers,
      Authorization: `Bearer ${session.accessToken}`,
    },
  });
}
```

### 2. Real-time Updates

WebSocket integration for real-time features:

- **Log Streaming**: Real-time log updates
- **Notifications**: Real-time notifications
- **Status Updates**: Real-time status changes

```typescript
// hooks/useLogStream.ts
import { useEffect, useState } from 'react';
import { createWebSocketClient } from '@neurallog/websocket-client';

export function useLogStream(logName: string) {
  const [logs, setLogs] = useState([]);
  const [status, setStatus] = useState('connecting');
  
  useEffect(() => {
    const client = createWebSocketClient({
      url: process.env.NEXT_PUBLIC_WEBSOCKET_URL,
      token: getAuthToken(),
    });
    
    client.subscribe(`logs/${logName}`, (message) => {
      setLogs((prev) => [...prev, message]);
    });
    
    client.onStatusChange((newStatus) => {
      setStatus(newStatus);
    });
    
    return () => {
      client.unsubscribe(`logs/${logName}`);
      client.disconnect();
    };
  }, [logName]);
  
  return { logs, status };
}
```

### 3. Authentication Flow

Integration with authentication providers:

- **NextAuth.js**: For authentication management
- **Auth0/Clerk**: For identity provider integration
- **JWT Handling**: Secure token management
- **Role-Based Access**: Permission-based UI rendering

```typescript
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth';
import Auth0Provider from 'next-auth/providers/auth0';

export const authOptions = {
  providers: [
    Auth0Provider({
      clientId: process.env.AUTH0_CLIENT_ID,
      clientSecret: process.env.AUTH0_CLIENT_SECRET,
      issuer: process.env.AUTH0_ISSUER,
    }),
  ],
  callbacks: {
    async jwt({ token, user, account }) {
      // Add custom claims to JWT
      if (account && user) {
        token.accessToken = account.access_token;
        token.tenantId = user.tenantId;
        token.roles = user.roles;
      }
      return token;
    },
    async session({ session, token }) {
      // Add custom session properties
      session.accessToken = token.accessToken;
      session.tenantId = token.tenantId;
      session.roles = token.roles;
      return session;
    },
  },
};

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };
```

## Multi-Tenant Implementation

### 1. Tenant Identification

Methods for identifying tenants:

- **Subdomain-based**: tenant-name.app.neurallog.com
- **Path-based**: app.neurallog.com/tenant-name
- **Header-based**: Custom header for API requests
- **JWT-based**: Tenant ID embedded in JWT

### 2. Tenant-Specific UI

Customization for each tenant:

- **Theming**: Tenant-specific colors and branding
- **Features**: Feature flags based on tenant plan
- **Layouts**: Custom layouts per tenant
- **Localization**: Tenant-specific language settings

```typescript
// hooks/useTenant.ts
import { useEffect, useState } from 'react';
import { fetchTenantConfig } from '@/api/tenant';

export function useTenant() {
  const [tenant, setTenant] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    async function loadTenant() {
      try {
        const tenantId = getTenantIdFromContext();
        const tenantConfig = await fetchTenantConfig(tenantId);
        setTenant(tenantConfig);
      } catch (error) {
        console.error('Failed to load tenant config', error);
      } finally {
        setLoading(false);
      }
    }
    
    loadTenant();
  }, []);
  
  return { tenant, loading };
}
```

### 3. Tenant Routing

Routing strategy for multi-tenant application:

- **Dynamic Routes**: Based on tenant identifier
- **Access Control**: Tenant-specific access control
- **Redirects**: Proper handling of tenant migrations
- **404 Handling**: Custom 404 pages for invalid tenants

## Development Workflow

### 1. Local Development

Streamlined local development:

- **Next.js Dev Server**: Fast refresh and HMR
- **Mock API**: Local mock API for development
- **Environment Variables**: Local .env files
- **Docker Compose**: Local services (optional)

```bash
# Start development server
npm run dev

# Start with mock API
npm run dev:mock

# Start with specific tenant
npm run dev -- --tenant=example
```

### 2. Testing Strategy

Comprehensive testing approach:

- **Unit Tests**: Component and utility testing with Jest/Vitest
- **Integration Tests**: API integration testing
- **E2E Tests**: End-to-end testing with Playwright
- **Visual Testing**: Component visual testing with Storybook

```
__tests__/
├── unit/                # Unit tests
│   ├── components/
│   └── utils/
├── integration/         # Integration tests
│   ├── api/
│   └── hooks/
└── e2e/                 # End-to-end tests
    ├── auth.spec.ts
    ├── logs.spec.ts
    └── rules.spec.ts
```

### 3. CI/CD Pipeline

Automated CI/CD with GitHub Actions:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main, staging]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - run: npm run lint
      - run: npm run type-check
      - run: npm test

  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run build
      - run: npm run start & npx wait-on http://localhost:3000
      - run: npm run test:e2e
```

## Performance Considerations

### 1. Core Web Vitals Optimization

Strategies for optimal Core Web Vitals:

- **LCP (Largest Contentful Paint)**:
  - Optimize image loading
  - Preload critical assets
  - Server-side rendering for fast initial load

- **FID (First Input Delay)**:
  - Minimize JavaScript execution time
  - Use Web Workers for heavy computations
  - Implement code splitting

- **CLS (Cumulative Layout Shift)**:
  - Set explicit dimensions for images
  - Reserve space for dynamic content
  - Avoid late-loading content shifts

### 2. Bundle Optimization

Techniques for minimal bundle size:

- **Code Splitting**: Route-based and component-based
- **Tree Shaking**: Remove unused code
- **Dynamic Imports**: Load components on demand
- **Module Analysis**: Regular bundle analysis

### 3. Caching Strategy

Effective caching for improved performance:

- **Static Generation**: Pre-render static pages
- **ISR**: Incremental Static Regeneration for semi-dynamic content
- **SWR/React Query**: Client-side data caching
- **Service Worker**: Offline support and asset caching

## Security Considerations

### 1. Authentication and Authorization

Secure authentication implementation:

- **OAuth/OIDC**: Industry-standard authentication
- **JWT Validation**: Proper token validation
- **RBAC**: Role-based access control
- **CSRF Protection**: Cross-Site Request Forgery protection
- **Session Management**: Secure session handling

### 2. Data Protection

Protecting sensitive data:

- **HTTPS**: TLS for all communications
- **Content Security Policy**: Prevent XSS attacks
- **Input Validation**: Validate all user inputs
- **Output Encoding**: Prevent injection attacks
- **Sensitive Data Handling**: Secure handling of PII

### 3. API Security

Securing API endpoints:

- **Rate Limiting**: Prevent abuse
- **Input Validation**: Validate all API inputs
- **Authentication**: Secure authentication for all endpoints
- **CORS**: Proper Cross-Origin Resource Sharing
- **Error Handling**: Non-revealing error messages

## Accessibility

- **WCAG Compliance**: Meet WCAG 2.1 AA standards
- **Semantic HTML**: Use proper HTML elements
- **Keyboard Navigation**: Ensure keyboard accessibility
- **Screen Reader Support**: Support assistive technologies
- **Color Contrast**: Ensure sufficient contrast ratios
- **Focus Management**: Proper focus handling

## Internationalization

- **Next.js i18n**: Built-in internationalization
- **Translation Management**: Organized translation files
- **RTL Support**: Right-to-left language support
- **Date/Time Formatting**: Locale-aware formatting
- **Number Formatting**: Locale-aware number formatting

## Deployment Checklist

- **Environment Variables**: Verify all required variables
- **Build Process**: Ensure successful build
- **Lighthouse Audit**: Check performance scores
- **Cross-Browser Testing**: Test in major browsers
- **Mobile Testing**: Test on mobile devices
- **Accessibility Audit**: Verify accessibility compliance
- **Security Scan**: Check for security vulnerabilities
- **SEO Verification**: Verify meta tags and sitemap
