# NeuralLog Python SDK Specification

## Overview

This specification defines the Python SDK for NeuralLog, providing Python developers with a simple and powerful interface to integrate with the NeuralLog platform.

## Installation

```bash
pip install neurallog
```

## Basic Usage

```python
from neurallog import NeuralLog

# Initialize the client
neurallog = NeuralLog(
    api_key="your-api-key",
    # or
    # token="your-jwt-token",
    endpoint="https://api.your-tenant.neurallog.com/v1"
)

# Log a message
neurallog.log(
    level="INFO",
    message="User logged in",
    metadata={
        "user_id": "123",
        "ip_address": "192.168.1.1"
    }
)

# Search logs
logs = neurallog.logs.search(
    query="error",
    time_range={
        "start": "2023-04-01T00:00:00Z",
        "end": "2023-04-08T23:59:59Z"
    },
    limit=10
)
```

## Core Components

### Client Configuration

```python
class NeuralLog:
    def __init__(
        self,
        api_key=None,
        token=None,
        endpoint=None,
        timeout=30,
        retries=3,
        max_retry_delay=60,
        transport="requests",
        log_level="INFO",
        logger=None,
        batch_size=10,
        batch_interval=5,
        auto_flush=True
    ):
        # Implementation details
```

### Client Structure

The SDK is organized into resource-specific modules:

```python
class NeuralLog:
    # Core logging methods
    def log(self, level, message, metadata=None, source=None, tags=None, timestamp=None):
        # Implementation
    
    def debug(self, message, metadata=None):
        # Implementation
    
    def info(self, message, metadata=None):
        # Implementation
    
    def warn(self, message, metadata=None):
        # Implementation
    
    def error(self, message, metadata=None):
        # Implementation
    
    def fatal(self, message, metadata=None):
        # Implementation
    
    # Resource modules
    @property
    def logs(self):
        # Returns LogsModule
    
    @property
    def rules(self):
        # Returns RulesModule
    
    @property
    def actions(self):
        # Returns ActionsModule
    
    # Utility methods
    def set_token(self, token):
        # Implementation
    
    def set_api_key(self, api_key):
        # Implementation
    
    def flush(self):
        # Implementation
```

## Logging API

### Basic Logging

```python
# Log a message
neurallog.log(
    level="ERROR",
    message="Database connection failed",
    source="database-service",
    metadata={
        "error_code": "DB_CONN_FAILED",
        "host": "db-1.example.com"
    },
    tags=["database", "connection"]
)

# Convenience methods
neurallog.info("User logged in", {"user_id": "123"})
neurallog.error("Operation failed", {"error_code": "OP_FAILED"})
```

### Batch Logging

```python
# Batch log messages
neurallog.logs.batch_log([
    {
        "level": "INFO",
        "message": "User logged in",
        "metadata": {"user_id": "123"}
    },
    {
        "level": "INFO",
        "message": "User updated profile",
        "metadata": {"user_id": "123"}
    }
])
```

### Context Manager

```python
# Use context manager for automatic flushing
with neurallog.batch() as batch:
    batch.info("User logged in", {"user_id": "123"})
    batch.info("User updated profile", {"user_id": "123"})
    batch.info("User logged out", {"user_id": "123"})
```

## Log Search API

```python
# Search logs
logs = neurallog.logs.search(
    query="error",
    filter={
        "level": ["ERROR", "FATAL"],
        "source": ["api-service", "auth-service"]
    },
    time_range={
        "start": "2023-04-01T00:00:00Z",
        "end": "2023-04-08T23:59:59Z"
    },
    sort=[
        {"field": "timestamp", "order": "desc"}
    ],
    limit=10
)

# Iterate through results
for log in logs:
    print(f"{log['timestamp']} [{log['level']}] {log['message']}")

# Pagination
next_page = neurallog.logs.search(
    query="error",
    limit=10,
    offset=10
)
```

## Log Streaming API

```python
# Stream logs
for log in neurallog.logs.stream(
    query="error",
    filter={"level": ["ERROR", "FATAL"]},
    follow=True
):
    print(f"{log['timestamp']} [{log['level']}] {log['message']}")
```

### Async Streaming

```python
import asyncio

async def stream_logs():
    async for log in neurallog.logs.astream(
        query="error",
        filter={"level": ["ERROR", "FATAL"]},
        follow=True
    ):
        print(f"{log['timestamp']} [{log['level']}] {log['message']}")

asyncio.run(stream_logs())
```

## Rules API

```python
# Create a rule
rule = neurallog.rules.create(
    name="Error Notification",
    description="Send notification when errors occur",
    condition={
        "type": "log_level",
        "parameters": {
            "level": "ERROR"
        }
    },
    actions=[
        {
            "action_id": "action-123",
            "parameters": {
                "channel": "slack",
                "message": "Error detected: {{log.message}}"
            }
        }
    ],
    enabled=True
)

# Update a rule
neurallog.rules.update(
    rule_id=rule["id"],
    enabled=False
)

# Delete a rule
neurallog.rules.delete(rule["id"])

# List rules
rules = neurallog.rules.list(
    filter={"enabled": True},
    limit=10
)

# Test a rule
result = neurallog.rules.test(
    rule_id=rule["id"],
    sample_data={
        "level": "ERROR",
        "message": "Test error message",
        "source": "api-service"
    }
)
```

## Actions API

```python
# Create an action
action = neurallog.actions.create(
    name="Slack Notification",
    description="Send notification to Slack",
    type="slack",
    parameters={
        "webhook": "https://hooks.slack.com/services/...",
        "channel": "#alerts"
    }
)

# Execute an action
result = neurallog.actions.execute(
    action_id=action["id"],
    parameters={
        "message": "Custom alert message"
    },
    context={
        "source": "manual-trigger"
    }
)
```

## Error Handling

```python
from neurallog.exceptions import NeuralLogError, ApiError, NetworkError

try:
    neurallog.info("User logged in", {"user_id": "123"})
except ApiError as e:
    print(f"API Error: {e.message}, Code: {e.code}, Status: {e.status}")
except NetworkError as e:
    print(f"Network Error: {e.message}")
except NeuralLogError as e:
    print(f"SDK Error: {e.message}")
except Exception as e:
    print(f"Unknown Error: {e}")
```

## Framework Integrations

### Flask Integration

```python
from flask import Flask, request
from neurallog.integrations.flask import NeuralLogFlask

app = Flask(__name__)
neurallog = NeuralLogFlask(
    app,
    api_key="your-api-key",
    endpoint="https://api.your-tenant.neurallog.com/v1"
)

@app.route('/api/users')
def get_users():
    try:
        # Log request
        neurallog.info("User API request", {
            "path": request.path,
            "method": request.method,
            "ip": request.remote_addr
        })
        
        # Process request
        users = get_users_from_db()
        return {"users": users}
    except Exception as e:
        # Log error
        neurallog.error("User API error", {
            "path": request.path,
            "method": request.method,
            "error": str(e)
        })
        
        return {"error": "Internal server error"}, 500
```

### Django Integration

```python
# settings.py
INSTALLED_APPS = [
    # ...
    'neurallog.integrations.django',
]

NEURALLOG = {
    'API_KEY': 'your-api-key',
    'ENDPOINT': 'https://api.your-tenant.neurallog.com/v1',
    'MIN_LEVEL': 'INFO',
    'CAPTURE_DJANGO_LOGS': True
}

# middleware.py
from neurallog.integrations.django import NeuralLogMiddleware

class MyNeuralLogMiddleware(NeuralLogMiddleware):
    def process_request(self, request):
        self.neurallog.info("Request started", {
            "path": request.path,
            "method": request.method,
            "user_id": request.user.id if request.user.is_authenticated else None
        })
```

### FastAPI Integration

```python
from fastapi import FastAPI, Request
from neurallog.integrations.fastapi import NeuralLogFastAPI

app = FastAPI()
neurallog = NeuralLogFastAPI(
    api_key="your-api-key",
    endpoint="https://api.your-tenant.neurallog.com/v1"
)

app.add_middleware(neurallog.middleware)

@app.get("/api/users")
async def get_users(request: Request):
    try:
        # Log request
        await neurallog.info("User API request", {
            "path": request.url.path,
            "method": request.method,
            "client": request.client.host
        })
        
        # Process request
        users = await get_users_from_db()
        return {"users": users}
    except Exception as e:
        # Log error
        await neurallog.error("User API error", {
            "path": request.url.path,
            "method": request.method,
            "error": str(e)
        })
        
        return {"error": "Internal server error"}
```

## Logging Framework Integrations

### Python Logging Integration

```python
import logging
from neurallog.integrations.logging import NeuralLogHandler

# Configure Python logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Add NeuralLog handler
neurallog_handler = NeuralLogHandler(
    api_key="your-api-key",
    endpoint="https://api.your-tenant.neurallog.com/v1"
)
logger.addHandler(neurallog_handler)

# Use standard logging
logger.info("Application started")
logger.error("An error occurred", exc_info=True)
```

### Structlog Integration

```python
import structlog
from neurallog.integrations.structlog import NeuralLogProcessor

# Configure structlog
structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        NeuralLogProcessor(
            api_key="your-api-key",
            endpoint="https://api.your-tenant.neurallog.com/v1"
        )
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
)

# Get logger
logger = structlog.get_logger()

# Use structlog
logger.info("Application started", app_version="1.0.0")
logger.error("Database error", db_host="db.example.com", error_code="DB_ERROR")
```

## Advanced Features

### Automatic Context Enrichment

```python
# Configure context enrichment
neurallog.configure_context({
    "app_name": "my-python-app",
    "app_version": "1.0.0",
    "environment": "production"
})

# Context is automatically added to all logs
neurallog.info("User logged in", {"user_id": "123"})
```

### Log Batching

```python
# Configure batching
neurallog = NeuralLog(
    api_key="your-api-key",
    endpoint="https://api.your-tenant.neurallog.com/v1",
    batch_size=20,  # Send logs in batches of 20
    batch_interval=10  # Or every 10 seconds, whichever comes first
)

# Logs are automatically batched
for i in range(100):
    neurallog.info(f"Iteration {i}")

# Force send any pending logs
neurallog.flush()
```

### Async Support

```python
import asyncio
from neurallog.async_client import AsyncNeuralLog

async def main():
    # Initialize async client
    neurallog = AsyncNeuralLog(
        api_key="your-api-key",
        endpoint="https://api.your-tenant.neurallog.com/v1"
    )
    
    # Log asynchronously
    await neurallog.info("User logged in", {"user_id": "123"})
    
    # Search logs asynchronously
    logs = await neurallog.logs.search(
        query="error",
        limit=10
    )
    
    # Stream logs asynchronously
    async for log in neurallog.logs.stream(
        query="error",
        follow=True
    ):
        print(f"{log['timestamp']} [{log['level']}] {log['message']}")

asyncio.run(main())
```

## Implementation Guidelines

1. **Type Hints**: Use Python type hints for better IDE support
2. **Async Support**: Provide both sync and async APIs
3. **Framework Integration**: Support popular Python frameworks
4. **Logging Integration**: Integrate with Python logging ecosystem
5. **Documentation**: Comprehensive documentation with examples
6. **Testing**: Thorough test coverage
7. **Performance**: Optimize for performance and resource usage
