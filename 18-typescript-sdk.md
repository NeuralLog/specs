# NeuralLog TypeScript SDK Specification

## Overview

This specification defines the TypeScript SDK for NeuralLog, providing a type-safe and developer-friendly interface for integrating with the platform.

## Installation

```bash
npm install @neurallog/sdk
# or
yarn add @neurallog/sdk
```

## Basic Usage

```typescript
import { NeuralLog } from '@neurallog/sdk';

// Initialize the client
const neuralLog = new NeuralLog({
  apiKey: 'your-api-key',
  // or
  // token: 'your-jwt-token',
  endpoint: 'https://api.your-tenant.neurallog.com/v1'
});

// Log a message
await neuralLog.log({
  level: 'INFO',
  message: 'User logged in',
  metadata: {
    userId: '123',
    ipAddress: '192.168.1.1'
  }
});

// Search logs
const logs = await neuralLog.logs.search({
  query: 'error',
  timeRange: {
    start: new Date(Date.now() - 24 * 60 * 60 * 1000),
    end: new Date()
  },
  limit: 10
});
```

## Core Components

### Client Configuration

```typescript
interface NeuralLogOptions {
  // Authentication (one of these is required)
  apiKey?: string;
  token?: string;
  
  // API endpoint (required)
  endpoint: string;
  
  // Optional configuration
  timeout?: number;
  retries?: number;
  maxRetryDelay?: number;
  
  // Transport options
  transport?: 'fetch' | 'node' | 'custom';
  customTransport?: Transport;
  
  // Logging options
  logLevel?: 'debug' | 'info' | 'warn' | 'error' | 'none';
  logger?: Logger;
}
```

### Client Structure

The SDK is organized into resource-specific modules:

```typescript
class NeuralLog {
  // Core logging methods
  log(params: LogParams): Promise<LogResult>;
  debug(message: string, metadata?: Record<string, any>): Promise<LogResult>;
  info(message: string, metadata?: Record<string, any>): Promise<LogResult>;
  warn(message: string, metadata?: Record<string, any>): Promise<LogResult>;
  error(message: string, metadata?: Record<string, any>): Promise<LogResult>;
  fatal(message: string, metadata?: Record<string, any>): Promise<LogResult>;
  
  // Resource modules
  logs: LogsModule;
  rules: RulesModule;
  actions: ActionsModule;
  users: UsersModule;
  organizations: OrganizationsModule;
  
  // Utility methods
  setToken(token: string): void;
  setApiKey(apiKey: string): void;
}
```

## Logging API

### Basic Logging

```typescript
// Log parameters
interface LogParams {
  level: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR' | 'FATAL';
  message: string;
  timestamp?: Date;
  source?: string;
  metadata?: Record<string, any>;
  tags?: string[];
}

// Log result
interface LogResult {
  id: string;
  timestamp: string;
  received: boolean;
}

// Usage
await neuralLog.log({
  level: 'ERROR',
  message: 'Database connection failed',
  source: 'database-service',
  metadata: {
    errorCode: 'DB_CONN_FAILED',
    host: 'db-1.example.com'
  },
  tags: ['database', 'connection']
});

// Convenience methods
await neuralLog.info('User logged in', { userId: '123' });
await neuralLog.error('Operation failed', { errorCode: 'OP_FAILED' });
```

### Batch Logging

```typescript
// Batch log parameters
interface BatchLogParams {
  logs: LogParams[];
}

// Batch log result
interface BatchLogResult {
  received: boolean;
  count: number;
  ids: string[];
}

// Usage
await neuralLog.logs.batchLog({
  logs: [
    {
      level: 'INFO',
      message: 'User logged in',
      metadata: { userId: '123' }
    },
    {
      level: 'INFO',
      message: 'User updated profile',
      metadata: { userId: '123' }
    }
  ]
});
```

## Log Search API

```typescript
// Search parameters
interface LogSearchParams {
  query?: string;
  filter?: LogFilter;
  timeRange?: TimeRange;
  sort?: SortOptions[];
  limit?: number;
  offset?: number;
}

interface LogFilter {
  level?: ('DEBUG' | 'INFO' | 'WARN' | 'ERROR' | 'FATAL')[];
  source?: string[];
  tags?: string[];
  metadata?: Record<string, any>;
}

interface TimeRange {
  start: Date;
  end: Date;
}

interface SortOptions {
  field: string;
  order: 'asc' | 'desc';
}

// Search result
interface LogSearchResult {
  logs: Log[];
  total: number;
  hasMore: boolean;
}

// Usage
const results = await neuralLog.logs.search({
  query: 'error',
  filter: {
    level: ['ERROR', 'FATAL'],
    source: ['api-service', 'auth-service']
  },
  timeRange: {
    start: new Date(Date.now() - 24 * 60 * 60 * 1000),
    end: new Date()
  },
  sort: [
    { field: 'timestamp', order: 'desc' }
  ],
  limit: 10
});
```

## Log Streaming API

```typescript
// Stream parameters
interface LogStreamParams {
  query?: string;
  filter?: LogFilter;
  follow?: boolean;
}

// Stream events
type LogStreamEvent = 
  | { type: 'log', data: Log }
  | { type: 'error', error: Error }
  | { type: 'open' }
  | { type: 'close', reason?: string };

// Usage
const stream = neuralLog.logs.stream({
  query: 'error',
  filter: {
    level: ['ERROR', 'FATAL']
  },
  follow: true
});

stream.on('log', (log) => {
  console.log(`New log: ${log.message}`);
});

stream.on('error', (error) => {
  console.error('Stream error:', error);
});

stream.on('open', () => {
  console.log('Stream opened');
});

stream.on('close', (reason) => {
  console.log(`Stream closed: ${reason}`);
});

// Close the stream
stream.close();
```

## Rules API

```typescript
// Rule creation
interface CreateRuleParams {
  name: string;
  description?: string;
  condition: RuleCondition;
  actions: RuleAction[];
  enabled?: boolean;
}

interface RuleCondition {
  type: string;
  parameters: Record<string, any>;
}

interface RuleAction {
  actionId: string;
  parameters?: Record<string, any>;
}

// Rule result
interface Rule {
  id: string;
  name: string;
  description?: string;
  condition: RuleCondition;
  actions: RuleAction[];
  enabled: boolean;
  createdAt: string;
  updatedAt?: string;
}

// Usage
const rule = await neuralLog.rules.create({
  name: 'Error Notification',
  description: 'Send notification when errors occur',
  condition: {
    type: 'log_level',
    parameters: {
      level: 'ERROR'
    }
  },
  actions: [
    {
      actionId: 'action-123',
      parameters: {
        channel: 'slack',
        message: 'Error detected: {{log.message}}'
      }
    }
  ],
  enabled: true
});
```

## Actions API

```typescript
// Action creation
interface CreateActionParams {
  name: string;
  description?: string;
  type: string;
  parameters: Record<string, any>;
}

// Action result
interface Action {
  id: string;
  name: string;
  description?: string;
  type: string;
  parameters: Record<string, any>;
  createdAt: string;
  updatedAt?: string;
}

// Action execution
interface ExecuteActionParams {
  actionId: string;
  parameters?: Record<string, any>;
  context?: Record<string, any>;
}

interface ActionExecutionResult {
  success: boolean;
  actionId: string;
  executionId: string;
  result?: Record<string, any>;
  error?: string;
}

// Usage
const action = await neuralLog.actions.create({
  name: 'Slack Notification',
  description: 'Send notification to Slack',
  type: 'slack',
  parameters: {
    webhook: 'https://hooks.slack.com/services/...',
    channel: '#alerts'
  }
});

const result = await neuralLog.actions.execute({
  actionId: action.id,
  parameters: {
    message: 'Custom alert message'
  },
  context: {
    source: 'manual-trigger'
  }
});
```

## Error Handling

```typescript
import { NeuralLog, NeuralLogError, ApiError, NetworkError } from '@neurallog/sdk';

try {
  await neuralLog.log({
    level: 'INFO',
    message: 'User logged in'
  });
} catch (error) {
  if (error instanceof ApiError) {
    console.error(`API Error: ${error.message}, Code: ${error.code}, Status: ${error.status}`);
  } else if (error instanceof NetworkError) {
    console.error(`Network Error: ${error.message}`);
  } else if (error instanceof NeuralLogError) {
    console.error(`SDK Error: ${error.message}`);
  } else {
    console.error(`Unknown Error: ${error}`);
  }
}
```

## Authentication

```typescript
// JWT authentication
const neuralLog = new NeuralLog({
  token: 'your-jwt-token',
  endpoint: 'https://api.your-tenant.neurallog.com/v1'
});

// Update token
neuralLog.setToken('new-jwt-token');

// API key authentication
const neuralLog = new NeuralLog({
  apiKey: 'your-api-key',
  endpoint: 'https://api.your-tenant.neurallog.com/v1'
});

// Update API key
neuralLog.setApiKey('new-api-key');
```

## Advanced Configuration

```typescript
// Custom transport
class MyCustomTransport implements Transport {
  async request(options: RequestOptions): Promise<Response> {
    // Custom implementation
  }
}

const neuralLog = new NeuralLog({
  apiKey: 'your-api-key',
  endpoint: 'https://api.your-tenant.neurallog.com/v1',
  transport: 'custom',
  customTransport: new MyCustomTransport(),
  timeout: 10000,
  retries: 3,
  maxRetryDelay: 5000,
  logLevel: 'debug',
  logger: customLogger
});
```

## Browser Usage

```typescript
// ESM import
import { NeuralLog } from '@neurallog/sdk';

// Browser bundle (UMD)
<script src="https://cdn.neurallog.com/sdk/latest/neurallog.min.js"></script>
<script>
  const neuralLog = new NeuralLogSDK.NeuralLog({
    apiKey: 'your-api-key',
    endpoint: 'https://api.your-tenant.neurallog.com/v1'
  });
  
  neuralLog.info('Page loaded', { url: window.location.href })
    .then(() => console.log('Log sent'))
    .catch(err => console.error('Log error', err));
</script>
```

## Node.js Usage

```typescript
import { NeuralLog } from '@neurallog/sdk';

// Initialize with environment variables
const neuralLog = new NeuralLog({
  apiKey: process.env.NEURALLOG_API_KEY,
  endpoint: process.env.NEURALLOG_ENDPOINT
});

// Express middleware example
app.use((req, res, next) => {
  req.neuralLog = neuralLog;
  next();
});

app.get('/api/users', async (req, res) => {
  try {
    // Log request
    await req.neuralLog.info('User API request', {
      path: req.path,
      method: req.method,
      ip: req.ip
    });
    
    // Process request
    const users = await getUsers();
    res.json(users);
  } catch (error) {
    // Log error
    await req.neuralLog.error('User API error', {
      path: req.path,
      method: req.method,
      error: error.message
    });
    
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

## Implementation Guidelines

1. **Type Safety**: Full TypeScript type definitions
2. **Tree Shaking**: Support for tree shaking
3. **Minimal Dependencies**: Few external dependencies
4. **Browser Compatibility**: Support modern browsers
5. **Documentation**: Comprehensive documentation with examples
