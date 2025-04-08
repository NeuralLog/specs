# NeuralLog SDK Common Patterns Specification

## Overview

This specification defines the common patterns, interfaces, and behaviors that should be consistent across all NeuralLog SDKs, ensuring a unified developer experience regardless of programming language or platform.

## Core Principles

1. **Consistency**: Similar API structure across all SDKs
2. **Simplicity**: Easy to use with minimal configuration
3. **Idiomatic**: Follow language-specific conventions and best practices
4. **Reliability**: Robust error handling and retry mechanisms
5. **Performance**: Efficient resource usage and minimal overhead

## Common Components

### Client Initialization

All SDKs should support similar initialization patterns:

```typescript
// TypeScript
const neuralLog = new NeuralLog({
  apiKey: "your-api-key",
  endpoint: "https://api.your-tenant.neurallog.com/v1"
});
```

```csharp
// C# / Unity
var neuralLog = new NeuralLog(new NeuralLogConfig {
  ApiKey = "your-api-key",
  Endpoint = "https://api.your-tenant.neurallog.com/v1"
});
```

```python
# Python
neurallog = NeuralLog(
  api_key="your-api-key",
  endpoint="https://api.your-tenant.neurallog.com/v1"
)
```

### Authentication Methods

All SDKs should support both API key and JWT token authentication:

1. **API Key Authentication**:
   - Simple string-based authentication
   - Passed in headers or configuration
   - Support for key rotation

2. **JWT Authentication**:
   - Token-based authentication
   - Support for token refresh
   - Handling of token expiration

### Module Structure

SDKs should use a consistent module structure:

1. **Core Client**: Main entry point with basic logging methods
2. **Logs Module**: Advanced log management functions
3. **Rules Module**: Rule management functions
4. **Actions Module**: Action management functions
5. **Utility Modules**: Helper functions and utilities

### Logging Methods

Standard logging methods across all SDKs:

1. **Basic Log Method**:
   ```
   log(level, message, metadata)
   ```

2. **Level-Specific Methods**:
   ```
   debug(message, metadata)
   info(message, metadata)
   warn(message, metadata)
   error(message, metadata)
   fatal(message, metadata)
   ```

### Log Parameters

Consistent log parameter structure:

```json
{
  "level": "INFO|DEBUG|WARN|ERROR|FATAL",
  "message": "Log message text",
  "timestamp": "2023-04-08T12:34:56.789Z", // Optional, auto-generated if not provided
  "source": "component-name", // Optional
  "metadata": {}, // Optional key-value pairs
  "tags": [] // Optional string tags
}
```

### Response Structures

Consistent response structures:

```json
// Log result
{
  "id": "log-123",
  "timestamp": "2023-04-08T12:34:56.789Z",
  "received": true
}

// Search result
{
  "logs": [...],
  "total": 100,
  "hasMore": true
}

// Rule result
{
  "id": "rule-123",
  "name": "Rule name",
  "condition": {...},
  "actions": [...],
  "enabled": true,
  "createdAt": "2023-04-08T12:34:56.789Z"
}
```

## Common Behaviors

### Error Handling

Consistent error handling patterns:

1. **Error Types**:
   - `NeuralLogError`: Base error class
   - `ApiError`: API-related errors
   - `NetworkError`: Network-related errors
   - `ValidationError`: Input validation errors
   - `AuthenticationError`: Authentication-related errors

2. **Error Properties**:
   - `message`: Human-readable error message
   - `code`: Error code for programmatic handling
   - `status`: HTTP status code (for API errors)
   - `details`: Additional error details

3. **Error Handling Pattern**:
   ```typescript
   try {
     await neuralLog.log(...);
   } catch (error) {
     if (error instanceof ApiError) {
       // Handle API error
     } else if (error instanceof NetworkError) {
       // Handle network error
     } else {
       // Handle other errors
     }
   }
   ```

### Retry Mechanism

Consistent retry behavior:

1. **Automatic Retries**:
   - Retry on network errors
   - Retry on server errors (5xx)
   - Configurable retry count
   - Exponential backoff with jitter

2. **Retry Configuration**:
   ```
   retries: 3,           // Number of retry attempts
   maxRetryDelay: 30000, // Maximum delay between retries (ms)
   retryFactor: 2,       // Exponential backoff factor
   retryJitter: 0.2      // Random jitter factor (0-1)
   ```

### Batching

Consistent batching behavior:

1. **Automatic Batching**:
   - Collect logs in memory
   - Send when batch size is reached
   - Send when batch interval is reached
   - Send on flush

2. **Batching Configuration**:
   ```
   batchSize: 10,       // Maximum batch size
   batchInterval: 5000, // Maximum batch interval (ms)
   autoFlush: true      // Automatically flush on process exit
   ```

### Connection Management

Consistent connection behavior:

1. **Connection Pooling**:
   - Reuse connections when possible
   - Limit maximum connections
   - Timeout for idle connections

2. **Connection Resilience**:
   - Handle connection failures
   - Reconnect automatically
   - Circuit breaker pattern for persistent failures

### Offline Support

Consistent offline behavior:

1. **Offline Queue**:
   - Store logs when offline
   - Limit queue size
   - Persist queue if supported
   - Send when back online

2. **Connectivity Detection**:
   - Detect network status
   - Handle transitions between online/offline
   - Platform-specific implementations

## Common Interfaces

### Log Interface

```typescript
interface Log {
  id: string;
  timestamp: string;
  level: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR' | 'FATAL';
  message: string;
  source?: string;
  metadata?: Record<string, any>;
  tags?: string[];
}
```

### Rule Interface

```typescript
interface Rule {
  id: string;
  name: string;
  description?: string;
  condition: {
    type: string;
    parameters: Record<string, any>;
  };
  actions: Array<{
    actionId: string;
    parameters?: Record<string, any>;
  }>;
  enabled: boolean;
  createdAt: string;
  updatedAt?: string;
}
```

### Action Interface

```typescript
interface Action {
  id: string;
  name: string;
  description?: string;
  type: string;
  parameters: Record<string, any>;
  createdAt: string;
  updatedAt?: string;
}
```

## Language-Specific Considerations

### TypeScript/JavaScript

1. **Promise-based API**:
   - All async operations return Promises
   - Support for async/await

2. **Event Emitters**:
   - Use EventEmitter for streaming
   - Standard event names

3. **Browser Compatibility**:
   - Support modern browsers
   - Polyfills for older browsers
   - Bundle size optimization

### C# / Unity

1. **Async/Await Pattern**:
   - Use Task-based async pattern
   - Provide synchronous alternatives

2. **Unity Main Thread**:
   - Ensure callbacks on main thread
   - Handle Unity lifecycle events

3. **Memory Management**:
   - Minimize garbage collection
   - Proper resource disposal

### Python

1. **Sync and Async APIs**:
   - Support both synchronous and async patterns
   - Use asyncio for async operations

2. **Context Managers**:
   - Support Python context managers
   - Automatic resource cleanup

3. **Framework Integration**:
   - Integrate with popular frameworks
   - Support Python logging ecosystem

## Implementation Guidelines

1. **Versioning**:
   - Use semantic versioning
   - Maintain compatibility within major versions
   - Document breaking changes

2. **Documentation**:
   - Consistent documentation format
   - Code examples for all features
   - API reference documentation
   - Tutorials and guides

3. **Testing**:
   - Comprehensive test coverage
   - Unit and integration tests
   - Cross-platform testing
   - Performance testing

4. **Distribution**:
   - Package for language-specific package managers
   - Clear installation instructions
   - Dependency management

5. **Security**:
   - Secure handling of credentials
   - Input validation
   - Output sanitization
   - Secure defaults
