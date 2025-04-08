# NeuralLog WebSocket API Specification

## Overview

This specification defines the WebSocket API for NeuralLog, enabling real-time communication between clients and the server for features like log streaming and notifications.

## Connection Endpoints

### Log Streaming

```
wss://api.{tenant-id}.neurallog.com/v1/logs/stream
```

### Notifications

```
wss://api.{tenant-id}.neurallog.com/v1/notifications
```

## Authentication

WebSocket connections are authenticated using:

1. **JWT Token**: Passed as a query parameter
   ```
   wss://api.{tenant-id}.neurallog.com/v1/logs/stream?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

2. **API Key**: Passed as a query parameter
   ```
   wss://api.{tenant-id}.neurallog.com/v1/logs/stream?apiKey=api-key-123
   ```

## Message Format

All WebSocket messages use JSON format:

```json
{
  "type": "message_type",
  "id": "message-id",
  "data": {
    // Message-specific data
  },
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

## Log Streaming

### Connection Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| query | Log search query | `level:ERROR` |
| filter | JSON filter object | `{"source":"api-service"}` |
| follow | Stream new logs | `true` |
| history | Include historical logs | `true` |
| limit | Max historical logs | `100` |

### Message Types

#### Log Message

```json
{
  "type": "log",
  "id": "msg-123",
  "data": {
    "id": "log-456",
    "timestamp": "2023-04-08T12:34:56.789Z",
    "level": "ERROR",
    "message": "Database connection failed",
    "source": "api-service",
    "metadata": {
      "errorCode": "DB_CONN_FAILED",
      "component": "database"
    }
  },
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

#### Stream Control Messages

```json
// Stream start
{
  "type": "stream_start",
  "id": "msg-123",
  "data": {
    "query": "level:ERROR",
    "filter": {"source":"api-service"},
    "follow": true
  },
  "timestamp": "2023-04-08T12:34:56.789Z"
}

// Stream end
{
  "type": "stream_end",
  "id": "msg-123",
  "data": {
    "reason": "client_disconnect"
  },
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

### Client Commands

Clients can send commands to control the stream:

```json
// Pause stream
{
  "type": "command",
  "id": "cmd-123",
  "data": {
    "action": "pause"
  }
}

// Resume stream
{
  "type": "command",
  "id": "cmd-123",
  "data": {
    "action": "resume"
  }
}

// Update filter
{
  "type": "command",
  "id": "cmd-123",
  "data": {
    "action": "update_filter",
    "filter": {"level":["ERROR","WARN"]}
  }
}
```

## Notifications

### Message Types

#### Rule Triggered

```json
{
  "type": "rule_triggered",
  "id": "msg-123",
  "data": {
    "ruleId": "rule-456",
    "ruleName": "Error Alert",
    "triggeredAt": "2023-04-08T12:34:56.789Z",
    "logId": "log-789",
    "severity": "high"
  },
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

#### Action Executed

```json
{
  "type": "action_executed",
  "id": "msg-123",
  "data": {
    "actionId": "action-456",
    "actionName": "Send Email",
    "executedAt": "2023-04-08T12:34:56.789Z",
    "status": "success",
    "ruleId": "rule-789"
  },
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

#### System Notification

```json
{
  "type": "system_notification",
  "id": "msg-123",
  "data": {
    "title": "Maintenance Scheduled",
    "message": "System maintenance scheduled for April 10, 2023",
    "severity": "info",
    "actionUrl": "https://status.neurallog.com"
  },
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

## Connection Management

### Heartbeat

The server sends heartbeat messages to keep the connection alive:

```json
{
  "type": "heartbeat",
  "id": "hb-123",
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

Clients should respond with:

```json
{
  "type": "heartbeat_ack",
  "id": "hb-123",
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

### Reconnection

Clients should implement reconnection with exponential backoff:

1. Initial delay: 1 second
2. Maximum delay: 30 seconds
3. Backoff factor: 1.5
4. Jitter: ±20%

## Error Handling

Error messages follow this format:

```json
{
  "type": "error",
  "id": "err-123",
  "data": {
    "code": "invalid_filter",
    "message": "The provided filter is invalid",
    "details": {
      "filter": {"invalid":"field"}
    }
  },
  "timestamp": "2023-04-08T12:34:56.789Z"
}
```

## Implementation Guidelines

1. **Scalability**: Use WebSocket clustering for horizontal scaling
2. **Connection Limits**: Implement per-tenant connection limits
3. **Monitoring**: Monitor connection health and metrics
4. **Graceful Degradation**: Fall back to polling if WebSocket fails
5. **Client Libraries**: Provide client libraries with reconnection logic
