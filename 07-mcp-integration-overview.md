# NeuralLog MCP Integration Overview

## Overview

This specification outlines how NeuralLog integrates with the Model Control Protocol (MCP) ecosystem. MCP provides a standardized way for AI models to interact with tools and services, and NeuralLog leverages this protocol to offer intelligent logging capabilities with AI-powered analysis and actions.

## Key Concepts

### MCP Architecture in NeuralLog

NeuralLog's MCP integration consists of three main components:

1. **MCP Server**: Hosted as part of the NeuralLog system
2. **MCP Tools**: NeuralLog-specific tools exposed via MCP
3. **MCP Clients**: SDKs for various platforms to connect to NeuralLog

```
┌─────────────────────────────────────────────────────────────┐
│                     NeuralLog System                        │
│                                                             │
│  ┌─────────────┐  ┌─────────────────────┐  ┌─────────────┐  │
│  │ NeuralLog   │  │ MCP Server          │  │ NeuralLog   │  │
│  │ Core        │◄─┤                     │◄─┤ MCP Clients │  │
│  │ Services    │  │ • Tool Registry     │  │             │  │
│  │             │  │ • Connection Mgmt   │  │ • TypeScript│  │
│  │ • Logging   │  │ • Authentication    │  │ • Unity     │  │
│  │ • Analysis  │  │ • Transport Layer   │  │ • Python    │  │
│  │ • Actions   │  │ • Request Handling  │  │ • Others    │  │
│  └─────────────┘  └─────────────────────┘  └─────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### MCP Server Hosting

The MCP server is hosted as an integral part of the NeuralLog system:

- **Tenant-Specific Instances**: Each tenant gets dedicated MCP server instances
- **Organization Namespaces**: Organizations within a tenant can have dedicated instances
- **Isolation**: Complete isolation between tenants at the Kubernetes level
- **Scaling**: Horizontal scaling based on connection and request volume

### MCP Tools

NeuralLog exposes the following tools via MCP:

1. **Log Management Tools**:
   - `neurallog.log`: Send log entries to NeuralLog
   - `neurallog.search`: Search for log entries
   - `neurallog.stream`: Stream log entries in real-time

2. **Rule Management Tools**:
   - `neurallog.rules.create`: Create a new rule
   - `neurallog.rules.update`: Update an existing rule
   - `neurallog.rules.delete`: Delete a rule
   - `neurallog.rules.list`: List all rules
   - `neurallog.rules.test`: Test a rule against sample data

3. **Action Management Tools**:
   - `neurallog.actions.execute`: Execute an action manually
   - `neurallog.actions.create`: Create a new action
   - `neurallog.actions.update`: Update an existing action
   - `neurallog.actions.delete`: Delete an action
   - `neurallog.actions.list`: List all actions

4. **Analysis Tools**:
   - `neurallog.analyze`: Analyze log entries
   - `neurallog.patterns.detect`: Detect patterns in logs
   - `neurallog.anomalies.detect`: Detect anomalies in logs

### MCP Client SDKs

NeuralLog provides client SDKs for various platforms:

- **TypeScript/JavaScript**: For web and Node.js applications
- **Unity**: For Unity-based applications
- **Python**: For Python applications
- **Others**: Additional SDKs as needed

## Integration Points

### 1. MCP Server Integration

The MCP server integrates with NeuralLog core services:

```typescript
// MCP Server initialization
const server = new MCPServer({
  tools: neuralLogTools,
  authentication: {
    strategy: 'jwt',
    validator: validateJwtToken
  },
  transports: [
    new WebSocketTransport({ port: 8080 }),
    new StdioTransport()
  ],
  tenantId: 'tenant-123',
  organizationId: 'org-456'
});

// Start the server
await server.start();
```

### 2. Tool Definitions

NeuralLog tools are defined using the MCP tool definition format:

```typescript
// Log tool definition
server.tool("neurallog.log", {
  level: z.enum(['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']),
  message: z.string(),
  metadata: z.record(z.any()).optional()
}, async ({ level, message, metadata }) => {
  // Log the message to NeuralLog
  const logEntry = await neuralLogService.log({
    level,
    message,
    metadata,
    source: 'mcp',
    timestamp: new Date()
  });
  
  return { success: true, logId: logEntry.id };
});

// Search tool definition
server.tool("neurallog.search", {
  query: z.string(),
  filters: z.record(z.any()).optional(),
  limit: z.number().optional(),
  offset: z.number().optional()
}, async ({ query, filters, limit, offset }) => {
  // Search logs in NeuralLog
  const results = await neuralLogService.search({
    query,
    filters,
    limit: limit || 100,
    offset: offset || 0
  });
  
  return { 
    results: results.items,
    total: results.total,
    hasMore: results.hasMore
  };
});
```

### 3. Client SDK Usage

Example of using the TypeScript client SDK:

```typescript
// Initialize the MCP client
const mcpClient = new MCPClient({
  endpoint: 'wss://mcp.tenant-123.neurallog.com',
  authToken: 'jwt-token',
  transport: 'websocket'
});

// Connect to the MCP server
await mcpClient.connect();

// Use the NeuralLog client
const neuralLog = new NeuralLog(mcpClient);

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
const results = await neuralLog.search({
  query: 'error',
  filters: {
    timeRange: {
      start: new Date(Date.now() - 24 * 60 * 60 * 1000),
      end: new Date()
    }
  },
  limit: 10
});
```

## Authentication and Authorization

### 1. Authentication

MCP connections are authenticated using JWT tokens:

- **Token Issuance**: Tokens are issued by the NeuralLog authentication service
- **Token Validation**: Tokens are validated by the MCP server
- **Token Claims**: Tokens include tenant, organization, and user information
- **Token Expiration**: Tokens have a configurable expiration time

### 2. Authorization

MCP tool access is authorized based on user roles:

- **Role-Based Access Control**: Tools are accessible based on user roles
- **Tenant Isolation**: Users can only access their tenant's tools
- **Organization Isolation**: Users can only access their organization's tools
- **Tool-Level Permissions**: Fine-grained permissions for specific tools

## Tenant Isolation

MCP servers are isolated at the tenant level:

- **Dedicated Instances**: Each tenant gets dedicated MCP server instances
- **Namespace Separation**: Organizations within a tenant use separate namespaces
- **Resource Quotas**: Tenants have resource quotas for MCP connections
- **Connection Limits**: Limits on concurrent connections per tenant

## Performance Considerations

- **Connection Pooling**: Efficient connection management
- **Request Batching**: Batch multiple requests when possible
- **Caching**: Cache frequently used data
- **Compression**: Compress request and response data
- **Timeout Handling**: Proper handling of timeouts
- **Backpressure**: Mechanisms to handle high load

## Security Considerations

- **Transport Security**: TLS encryption for all connections
- **Input Validation**: Validate all input parameters
- **Rate Limiting**: Prevent abuse through rate limiting
- **Audit Logging**: Log all MCP operations
- **Error Handling**: Secure error handling practices

## Implementation Guidelines

### 1. MCP Server Implementation

- Use the official MCP TypeScript SDK
- Implement proper error handling and logging
- Set up monitoring and alerting
- Configure appropriate resource limits
- Implement graceful shutdown

### 2. Tool Implementation

- Keep tools focused and single-purpose
- Validate all inputs thoroughly
- Handle errors gracefully
- Return consistent response formats
- Document tools comprehensively

### 3. Client SDK Implementation

- Provide a simple, intuitive API
- Handle connection management automatically
- Implement retry logic for transient failures
- Support both synchronous and asynchronous patterns
- Provide comprehensive documentation and examples
