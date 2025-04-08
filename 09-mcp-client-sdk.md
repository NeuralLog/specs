# NeuralLog MCP Client SDK Specification

## Overview

This specification defines the client SDKs that enable applications to connect to NeuralLog via the Model Control Protocol (MCP). These SDKs provide a simple, consistent interface for logging, searching, and interacting with NeuralLog's features across different programming languages and platforms.

## SDK Architecture

### Common Architecture

All NeuralLog MCP client SDKs follow a common architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Application                      │
│                                                             │
│  ┌─────────────┐  ┌─────────────────────┐  ┌─────────────┐  │
│  │ NeuralLog   │  │ MCP Client          │  │ Transport   │  │
│  │ Client      │◄─┤                     │◄─┤ Layer       │  │
│  │             │  │ • Connection Mgmt   │  │             │  │
│  │ • Logging   │  │ • Request Handling  │  │ • WebSocket │  │
│  │ • Searching │  │ • Authentication    │  │ • STDIO     │  │
│  │ • Rules     │  │ • Error Handling    │  │ • HTTP      │  │
│  │ • Actions   │  │ • Serialization     │  │             │  │
│  └─────────────┘  └─────────────────────┘  └─────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

1. **NeuralLog Client**: High-level API for NeuralLog features
2. **MCP Client**: Core MCP protocol implementation
3. **Transport Layer**: Communication transport (WebSocket, STDIO, etc.)
4. **Authentication**: Authentication mechanisms
5. **Error Handling**: Consistent error handling
6. **Serialization**: Request/response serialization

## SDK Implementations

### 1. TypeScript/JavaScript SDK

```typescript
// NeuralLog TypeScript SDK
import { MCPClient } from '@mcp/client';

export class NeuralLog {
  private client: MCPClient;
  
  constructor(options: NeuralLogOptions) {
    this.client = new MCPClient({
      endpoint: options.endpoint,
      authToken: options.authToken,
      transport: options.transport || 'websocket',
      timeout: options.timeout || 30000
    });
  }
  
  // Connect to NeuralLog
  async connect(): Promise<void> {
    await this.client.connect();
  }
  
  // Log a message
  async log(params: LogParams): Promise<LogResult> {
    return this.client.invoke('neurallog.log', params);
  }
  
  // Search logs
  async search(params: SearchParams): Promise<SearchResult> {
    return this.client.invoke('neurallog.search', params);
  }
  
  // Stream logs
  streamLogs(params: StreamParams): EventEmitter {
    return this.client.stream('neurallog.stream', params);
  }
  
  // Create a rule
  async createRule(params: RuleParams): Promise<RuleResult> {
    return this.client.invoke('neurallog.rules.create', params);
  }
  
  // Execute an action
  async executeAction(params: ActionParams): Promise<ActionResult> {
    return this.client.invoke('neurallog.actions.execute', params);
  }
  
  // Close the connection
  async disconnect(): Promise<void> {
    await this.client.disconnect();
  }
}

// Usage example
const neuralLog = new NeuralLog({
  endpoint: 'wss://mcp.tenant-123.neurallog.com',
  authToken: 'jwt-token',
  transport: 'websocket'
});

await neuralLog.connect();

// Log a message
await neuralLog.log({
  level: 'INFO',
  message: 'User logged in',
  metadata: { userId: '123' }
});
```

### 2. Unity SDK

```csharp
// NeuralLog Unity SDK
using NeuralLog.MCP;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace NeuralLog
{
    public class NeuralLogClient
    {
        private MCPClient _mcpClient;
        
        public NeuralLogClient(NeuralLogOptions options)
        {
            _mcpClient = new MCPClient(new MCPClientOptions
            {
                Endpoint = options.Endpoint,
                AuthToken = options.AuthToken,
                Transport = options.Transport ?? "websocket",
                Timeout = options.Timeout ?? 30000
            });
        }
        
        // Connect to NeuralLog
        public async Task ConnectAsync()
        {
            await _mcpClient.ConnectAsync();
        }
        
        // Log a message
        public async Task<LogResult> LogAsync(LogParams logParams)
        {
            return await _mcpClient.InvokeAsync<LogResult>("neurallog.log", logParams);
        }
        
        // Search logs
        public async Task<SearchResult> SearchAsync(SearchParams searchParams)
        {
            return await _mcpClient.InvokeAsync<SearchResult>("neurallog.search", searchParams);
        }
        
        // Create a rule
        public async Task<RuleResult> CreateRuleAsync(RuleParams ruleParams)
        {
            return await _mcpClient.InvokeAsync<RuleResult>("neurallog.rules.create", ruleParams);
        }
        
        // Execute an action
        public async Task<ActionResult> ExecuteActionAsync(ActionParams actionParams)
        {
            return await _mcpClient.InvokeAsync<ActionResult>("neurallog.actions.execute", actionParams);
        }
        
        // Close the connection
        public async Task DisconnectAsync()
        {
            await _mcpClient.DisconnectAsync();
        }
    }
    
    // Unity-specific integration
    public class NeuralLogUnity : MonoBehaviour
    {
        private NeuralLogClient _client;
        
        void Start()
        {
            _client = new NeuralLogClient(new NeuralLogOptions
            {
                Endpoint = "wss://mcp.tenant-123.neurallog.com",
                AuthToken = "jwt-token"
            });
            
            ConnectToNeuralLog();
        }
        
        async void ConnectToNeuralLog()
        {
            try
            {
                await _client.ConnectAsync();
                Debug.Log("Connected to NeuralLog");
            }
            catch (Exception ex)
            {
                Debug.LogError($"Failed to connect to NeuralLog: {ex.Message}");
            }
        }
        
        // Log a message from Unity
        public async Task LogMessageAsync(string message, string level = "INFO", Dictionary<string, object> metadata = null)
        {
            try
            {
                await _client.LogAsync(new LogParams
                {
                    Level = level,
                    Message = message,
                    Metadata = metadata ?? new Dictionary<string, object>()
                });
            }
            catch (Exception ex)
            {
                Debug.LogError($"Failed to log message: {ex.Message}");
            }
        }
        
        void OnDestroy()
        {
            _client.DisconnectAsync().ContinueWith(task =>
            {
                if (task.Exception != null)
                {
                    Debug.LogError($"Error disconnecting: {task.Exception.Message}");
                }
            });
        }
    }
}
```

### 3. Python SDK

```python
# NeuralLog Python SDK
import asyncio
from typing import Dict, Any, Optional, List
from mcp.client import MCPClient

class NeuralLog:
    def __init__(self, options: Dict[str, Any]):
        self.client = MCPClient(
            endpoint=options.get("endpoint"),
            auth_token=options.get("auth_token"),
            transport=options.get("transport", "websocket"),
            timeout=options.get("timeout", 30000)
        )
    
    async def connect(self) -> None:
        """Connect to NeuralLog"""
        await self.client.connect()
    
    async def log(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Log a message"""
        return await self.client.invoke("neurallog.log", params)
    
    async def search(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Search logs"""
        return await self.client.invoke("neurallog.search", params)
    
    async def stream_logs(self, params: Dict[str, Any]) -> asyncio.Queue:
        """Stream logs"""
        return await self.client.stream("neurallog.stream", params)
    
    async def create_rule(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Create a rule"""
        return await self.client.invoke("neurallog.rules.create", params)
    
    async def execute_action(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Execute an action"""
        return await self.client.invoke("neurallog.actions.execute", params)
    
    async def disconnect(self) -> None:
        """Close the connection"""
        await self.client.disconnect()

# Usage example
async def main():
    neurallog = NeuralLog({
        "endpoint": "wss://mcp.tenant-123.neurallog.com",
        "auth_token": "jwt-token"
    })
    
    await neurallog.connect()
    
    # Log a message
    result = await neurallog.log({
        "level": "INFO",
        "message": "User logged in",
        "metadata": {"user_id": "123"}
    })
    
    print(f"Log result: {result}")
    
    # Search logs
    search_result = await neurallog.search({
        "query": "error",
        "limit": 10
    })
    
    print(f"Found {len(search_result['results'])} logs")
    
    await neurallog.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

## Common Features

### 1. Connection Management

All SDKs provide consistent connection management:

- **Connection Establishment**: Establish connection to MCP server
- **Authentication**: Authenticate with JWT or other mechanism
- **Reconnection**: Automatic reconnection with backoff
- **Connection Status**: Monitor connection status
- **Graceful Disconnection**: Clean disconnection

```typescript
// Connection management example (TypeScript)
const neuralLog = new NeuralLog({
  endpoint: 'wss://mcp.tenant-123.neurallog.com',
  authToken: 'jwt-token',
  reconnect: true,
  reconnectOptions: {
    maxRetries: 10,
    initialDelay: 1000,
    maxDelay: 30000
  }
});

// Connection events
neuralLog.on('connected', () => {
  console.log('Connected to NeuralLog');
});

neuralLog.on('disconnected', (reason) => {
  console.log(`Disconnected: ${reason}`);
});

neuralLog.on('reconnecting', (attempt) => {
  console.log(`Reconnecting (attempt ${attempt})...`);
});

neuralLog.on('error', (error) => {
  console.error('Connection error:', error);
});

// Connect
await neuralLog.connect();
```

### 2. Logging API

Consistent logging API across all SDKs:

```typescript
// Basic logging
await neuralLog.log({
  level: 'INFO',
  message: 'User logged in',
  metadata: { userId: '123' }
});

// Log with source
await neuralLog.log({
  level: 'ERROR',
  message: 'Database connection failed',
  source: 'database-service',
  metadata: { 
    errorCode: 'DB_CONN_FAILED',
    host: 'db-1.example.com'
  }
});

// Log with context
await neuralLog.log({
  level: 'WARN',
  message: 'Rate limit exceeded',
  context: {
    requestId: 'req-123',
    userId: 'user-456',
    ipAddress: '192.168.1.1'
  }
});

// Convenience methods
await neuralLog.debug('Debug message', { debugInfo: 'value' });
await neuralLog.info('Info message', { infoData: 'value' });
await neuralLog.warn('Warning message', { warnData: 'value' });
await neuralLog.error('Error message', { errorData: 'value' });
await neuralLog.fatal('Fatal message', { fatalData: 'value' });
```

### 3. Search API

Consistent search API across all SDKs:

```typescript
// Basic search
const results = await neuralLog.search({
  query: 'error',
  limit: 10
});

// Advanced search
const results = await neuralLog.search({
  query: 'database connection',
  filters: {
    level: ['ERROR', 'FATAL'],
    source: 'database-service',
    timeRange: {
      start: new Date(Date.now() - 24 * 60 * 60 * 1000), // Last 24 hours
      end: new Date()
    },
    metadata: {
      errorCode: 'DB_CONN_FAILED'
    }
  },
  sort: {
    field: 'timestamp',
    order: 'desc'
  },
  limit: 100,
  offset: 0
});

// Pagination
const page1 = await neuralLog.search({
  query: 'error',
  limit: 10,
  offset: 0
});

const page2 = await neuralLog.search({
  query: 'error',
  limit: 10,
  offset: 10
});
```

### 4. Streaming API

Real-time log streaming API:

```typescript
// TypeScript streaming example
const stream = neuralLog.streamLogs({
  query: 'error',
  filters: {
    level: ['ERROR', 'FATAL']
  }
});

stream.on('log', (log) => {
  console.log(`New log: ${log.message}`);
});

stream.on('error', (error) => {
  console.error('Stream error:', error);
});

// Stop streaming
stream.close();

// Python streaming example
async def stream_logs():
    queue = await neurallog.stream_logs({
        "query": "error",
        "filters": {
            "level": ["ERROR", "FATAL"]
        }
    })
    
    try:
        while True:
            log = await queue.get()
            if log == "CLOSE":
                break
            print(f"New log: {log['message']}")
    except Exception as e:
        print(f"Stream error: {e}")
```

### 5. Rule Management

API for managing rules:

```typescript
// Create a rule
const rule = await neuralLog.createRule({
  name: 'Error Notification Rule',
  description: 'Send notification when errors occur',
  condition: {
    type: 'LOG_LEVEL',
    parameters: {
      minLevel: 'ERROR',
      sources: ['api-service', 'auth-service']
    }
  },
  actions: [
    {
      type: 'NOTIFICATION',
      parameters: {
        channel: 'slack',
        recipients: ['#alerts'],
        template: 'error-notification-template'
      }
    }
  ],
  enabled: true
});

// Update a rule
await neuralLog.updateRule({
  id: rule.id,
  enabled: false
});

// Delete a rule
await neuralLog.deleteRule(rule.id);

// List rules
const rules = await neuralLog.listRules();

// Test a rule
const testResult = await neuralLog.testRule({
  ruleId: rule.id,
  sampleData: {
    level: 'ERROR',
    message: 'Test error message',
    source: 'api-service'
  }
});
```

### 6. Action Management

API for managing and executing actions:

```typescript
// Execute an action
await neuralLog.executeAction({
  type: 'NOTIFICATION',
  parameters: {
    channel: 'slack',
    recipients: ['#alerts'],
    message: 'Manual notification'
  }
});

// Create an action
const action = await neuralLog.createAction({
  name: 'Slack Notification',
  type: 'NOTIFICATION',
  parameters: {
    channel: 'slack',
    recipients: ['#alerts'],
    template: 'notification-template'
  }
});

// Update an action
await neuralLog.updateAction({
  id: action.id,
  parameters: {
    recipients: ['#alerts', '#monitoring']
  }
});

// Delete an action
await neuralLog.deleteAction(action.id);

// List actions
const actions = await neuralLog.listActions();
```

## Error Handling

### 1. Error Types

Consistent error types across all SDKs:

```typescript
// TypeScript error types
export class NeuralLogError extends Error {
  constructor(message: string, public code: string, public details?: any) {
    super(message);
    this.name = 'NeuralLogError';
  }
}

export class ConnectionError extends NeuralLogError {
  constructor(message: string, details?: any) {
    super(message, 'CONNECTION_ERROR', details);
    this.name = 'ConnectionError';
  }
}

export class AuthenticationError extends NeuralLogError {
  constructor(message: string, details?: any) {
    super(message, 'AUTHENTICATION_ERROR', details);
    this.name = 'AuthenticationError';
  }
}

export class RequestError extends NeuralLogError {
  constructor(message: string, details?: any) {
    super(message, 'REQUEST_ERROR', details);
    this.name = 'RequestError';
  }
}

export class TimeoutError extends NeuralLogError {
  constructor(message: string, details?: any) {
    super(message, 'TIMEOUT_ERROR', details);
    this.name = 'TimeoutError';
  }
}
```

### 2. Error Handling Patterns

```typescript
// TypeScript error handling
try {
  await neuralLog.connect();
  await neuralLog.log({
    level: 'INFO',
    message: 'User logged in'
  });
} catch (error) {
  if (error instanceof ConnectionError) {
    console.error('Connection failed:', error.message);
    // Handle connection error
  } else if (error instanceof AuthenticationError) {
    console.error('Authentication failed:', error.message);
    // Handle authentication error
  } else if (error instanceof RequestError) {
    console.error('Request failed:', error.message);
    // Handle request error
  } else {
    console.error('Unknown error:', error);
    // Handle unknown error
  }
}

// Python error handling
try:
    await neurallog.connect()
    await neurallog.log({
        "level": "INFO",
        "message": "User logged in"
    })
except ConnectionError as e:
    print(f"Connection failed: {e}")
    # Handle connection error
except AuthenticationError as e:
    print(f"Authentication failed: {e}")
    # Handle authentication error
except RequestError as e:
    print(f"Request failed: {e}")
    # Handle request error
except Exception as e:
    print(f"Unknown error: {e}")
    # Handle unknown error
```

## Authentication

### 1. JWT Authentication

```typescript
// JWT authentication
const neuralLog = new NeuralLog({
  endpoint: 'wss://mcp.tenant-123.neurallog.com',
  authToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  authType: 'jwt'
});

// Token refresh
neuralLog.on('token-expiring', async () => {
  const newToken = await fetchNewToken();
  neuralLog.updateAuthToken(newToken);
});
```

### 2. API Key Authentication

```typescript
// API key authentication
const neuralLog = new NeuralLog({
  endpoint: 'wss://mcp.tenant-123.neurallog.com',
  authToken: 'api-key-123',
  authType: 'api-key'
});
```

## Configuration

### 1. Client Configuration

```typescript
// Full configuration options
const neuralLog = new NeuralLog({
  // Connection options
  endpoint: 'wss://mcp.tenant-123.neurallog.com',
  transport: 'websocket', // 'websocket', 'stdio', 'http'
  timeout: 30000, // Request timeout in ms
  
  // Authentication options
  authToken: 'jwt-token',
  authType: 'jwt', // 'jwt', 'api-key'
  
  // Reconnection options
  reconnect: true,
  reconnectOptions: {
    maxRetries: 10,
    initialDelay: 1000,
    maxDelay: 30000,
    factor: 2
  },
  
  // Logging options
  logLevel: 'info', // SDK internal logging level
  logger: customLogger, // Custom logger for SDK
  
  // Advanced options
  compression: true, // Enable compression
  batchingOptions: {
    enabled: true,
    maxBatchSize: 100,
    maxDelayMs: 1000
  }
});
```

### 2. Default Configuration

```typescript
// Default configuration
const DEFAULT_CONFIG = {
  transport: 'websocket',
  timeout: 30000,
  authType: 'jwt',
  reconnect: true,
  reconnectOptions: {
    maxRetries: 10,
    initialDelay: 1000,
    maxDelay: 30000,
    factor: 2
  },
  logLevel: 'info',
  compression: true,
  batchingOptions: {
    enabled: false
  }
};
```

## Platform-Specific Considerations

### 1. Unity Considerations

- **Main Thread**: Ensure callbacks run on the main thread
- **Lifecycle Management**: Proper initialization and cleanup
- **Async/Await**: Support for async/await in Unity
- **WebGL Support**: Special handling for WebGL builds
- **Mobile Considerations**: Battery and network optimizations

```csharp
// Unity main thread callback handling
public class NeuralLogUnity : MonoBehaviour
{
    private NeuralLogClient _client;
    private Queue<Action> _mainThreadActions = new Queue<Action>();
    
    void Update()
    {
        // Execute queued actions on the main thread
        while (_mainThreadActions.Count > 0)
        {
            var action = _mainThreadActions.Dequeue();
            action();
        }
    }
    
    // Queue action to run on main thread
    public void RunOnMainThread(Action action)
    {
        _mainThreadActions.Enqueue(action);
    }
    
    // Log event handler that ensures callbacks run on main thread
    private void SetupLogEventHandler()
    {
        _client.OnLogEvent += (logEvent) => {
            RunOnMainThread(() => {
                Debug.Log($"Log event: {logEvent.Message}");
                // Process log event on main thread
            });
        };
    }
}
```

### 2. Browser Considerations

- **WebSocket Support**: Fallback for browsers without WebSocket
- **Connection Persistence**: Handle page refreshes and tab changes
- **Local Storage**: Store configuration in localStorage
- **Service Workers**: Optional integration with service workers
- **Offline Support**: Queue logs when offline

```typescript
// Browser-specific features
class BrowserNeuralLog extends NeuralLog {
  constructor(options) {
    super(options);
    
    // Setup offline support
    if (navigator.onLine === false) {
      this.enableOfflineMode();
    }
    
    window.addEventListener('online', () => {
      this.disableOfflineMode();
      this.flushOfflineQueue();
    });
    
    window.addEventListener('offline', () => {
      this.enableOfflineMode();
    });
    
    // Handle page visibility changes
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        this.reconnectIfNeeded();
      }
    });
  }
  
  // Store logs when offline
  enableOfflineMode() {
    this._offlineMode = true;
    this._offlineQueue = this._offlineQueue || [];
  }
  
  // Restore online operation
  disableOfflineMode() {
    this._offlineMode = false;
  }
  
  // Override log method to queue when offline
  async log(params) {
    if (this._offlineMode) {
      this._offlineQueue.push({
        method: 'log',
        params,
        timestamp: Date.now()
      });
      return { queued: true };
    }
    
    return super.log(params);
  }
  
  // Send queued logs when back online
  async flushOfflineQueue() {
    if (!this._offlineQueue || this._offlineQueue.length === 0) {
      return;
    }
    
    const queue = [...this._offlineQueue];
    this._offlineQueue = [];
    
    for (const item of queue) {
      try {
        await super[item.method](item.params);
      } catch (error) {
        console.error(`Failed to process offline queue item:`, error);
        // Re-queue failed items
        this._offlineQueue.push(item);
      }
    }
  }
}
```

### 3. Node.js Considerations

- **Process Exit**: Graceful shutdown on process exit
- **Worker Threads**: Support for worker threads
- **Stream Integration**: Integration with Node.js streams
- **Cluster Support**: Support for clustered applications
- **Memory Management**: Efficient memory usage

```typescript
// Node.js specific features
class NodeNeuralLog extends NeuralLog {
  constructor(options) {
    super(options);
    
    // Handle process exit
    process.on('SIGINT', async () => {
      await this.disconnect();
      process.exit(0);
    });
    
    process.on('SIGTERM', async () => {
      await this.disconnect();
      process.exit(0);
    });
  }
  
  // Create a writable stream for piping logs
  createWritableStream(level = 'INFO') {
    const stream = new Writable({
      objectMode: true,
      write: (chunk, encoding, callback) => {
        this.log({
          level,
          message: chunk.toString(),
          timestamp: new Date(),
          source: 'stream'
        }).then(() => callback())
          .catch(err => callback(err));
      }
    });
    
    return stream;
  }
  
  // Integration with popular Node.js logging libraries
  integrateWithWinston(winston) {
    // Implementation details...
  }
  
  integrateWithPino(pino) {
    // Implementation details...
  }
  
  integrateWithBunyan(bunyan) {
    // Implementation details...
  }
}
```

## Implementation Guidelines

### 1. SDK Development

- **TypeScript**: Use TypeScript for type safety
- **Modular Design**: Use modular architecture
- **Consistent API**: Maintain consistent API across SDKs
- **Comprehensive Testing**: Unit and integration tests
- **Documentation**: Thorough documentation with examples
- **Versioning**: Semantic versioning

### 2. Distribution

- **Package Managers**: Publish to npm, PyPI, NuGet, etc.
- **CDN**: Provide CDN distribution for browser SDK
- **Minification**: Minify browser bundles
- **Tree Shaking**: Support tree shaking
- **Source Maps**: Include source maps for debugging

### 3. Documentation

- **API Reference**: Comprehensive API documentation
- **Tutorials**: Step-by-step tutorials
- **Examples**: Code examples for common use cases
- **Integration Guides**: Guides for integrating with frameworks
- **Troubleshooting**: Common issues and solutions
