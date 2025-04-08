# NeuralLog REST API Design Specification

## Overview

This specification defines the design principles and structure for NeuralLog's REST API, providing a consistent interface for clients to interact with the platform.

## API Design Principles

1. **Resource-Oriented**: API organized around resources
2. **Predictable URLs**: Consistent URL patterns
3. **Standard HTTP Methods**: Proper use of HTTP verbs
4. **JSON Responses**: Consistent JSON response format
5. **Pagination**: Standard pagination for list endpoints
6. **Filtering**: Consistent query parameter filtering
7. **Error Handling**: Standard error response format
8. **Versioning**: Clear API versioning strategy

## Base URL Structure

```
https://api.{tenant-id}.neurallog.com/v1
```

For self-hosted deployments:
```
https://{your-domain}/api/v1
```

## Resource Endpoints

### Logs

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /logs | Create log entries |
| GET | /logs | List log entries |
| GET | /logs/{id} | Get a specific log entry |
| DELETE | /logs | Delete log entries |
| GET | /logs/search | Search log entries |
| GET | /logs/stream | Stream logs (WebSocket upgrade) |

### Rules

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /rules | Create a rule |
| GET | /rules | List rules |
| GET | /rules/{id} | Get a specific rule |
| PUT | /rules/{id} | Update a rule |
| DELETE | /rules/{id} | Delete a rule |
| POST | /rules/{id}/test | Test a rule |
| POST | /rules/{id}/enable | Enable a rule |
| POST | /rules/{id}/disable | Disable a rule |

### Actions

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /actions | Create an action |
| GET | /actions | List actions |
| GET | /actions/{id} | Get a specific action |
| PUT | /actions/{id} | Update an action |
| DELETE | /actions/{id} | Delete an action |
| POST | /actions/{id}/execute | Execute an action |

### Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /users | Create a user |
| GET | /users | List users |
| GET | /users/{id} | Get a specific user |
| PUT | /users/{id} | Update a user |
| DELETE | /users/{id} | Delete a user |
| POST | /users/invite | Invite a user |

### Organizations

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /organizations | Create an organization |
| GET | /organizations | List organizations |
| GET | /organizations/{id} | Get a specific organization |
| PUT | /organizations/{id} | Update an organization |
| DELETE | /organizations/{id} | Delete an organization |

## Request/Response Format

### Standard Response Format

```json
{
  "data": {
    // Resource data
  },
  "meta": {
    "requestId": "req-123",
    "timestamp": "2023-04-08T12:34:56.789Z"
  }
}
```

### List Response Format

```json
{
  "data": [
    // Array of resources
  ],
  "meta": {
    "pagination": {
      "total": 100,
      "limit": 10,
      "offset": 0,
      "hasMore": true
    },
    "requestId": "req-123",
    "timestamp": "2023-04-08T12:34:56.789Z"
  }
}
```

### Error Response Format

```json
{
  "error": {
    "code": "resource_not_found",
    "message": "The requested resource was not found",
    "details": {
      "resourceType": "log",
      "resourceId": "log-123"
    }
  },
  "meta": {
    "requestId": "req-123",
    "timestamp": "2023-04-08T12:34:56.789Z"
  }
}
```

## Pagination

Pagination uses `limit` and `offset` parameters:

```
GET /logs?limit=10&offset=20
```

## Filtering

Filtering uses query parameters:

```
GET /logs?level=ERROR&source=api-service&from=2023-04-01T00:00:00Z&to=2023-04-08T23:59:59Z
```

Complex filters use JSON encoding:

```
GET /logs?filter={"metadata.userId":"user-123","level":["ERROR","WARN"]}
```

## Sorting

Sorting uses the `sort` parameter:

```
GET /logs?sort=timestamp:desc
```

Multiple sort fields:

```
GET /logs?sort=level:asc,timestamp:desc
```

## Field Selection

Field selection uses the `fields` parameter:

```
GET /logs?fields=id,timestamp,message,level
```

## API Versioning

API versioning is included in the URL path:

```
/v1/logs
/v2/logs
```

## Authentication

Authentication uses JWT tokens in the Authorization header:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

API keys can be used as an alternative:

```
X-API-Key: api-key-123
```

## Rate Limiting

Rate limiting headers are included in responses:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1617234000
```

## CORS Support

CORS headers for cross-origin requests:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-API-Key
Access-Control-Max-Age: 86400
```

## Implementation Guidelines

1. **API Gateway**: Implement using API Gateway pattern
2. **Input Validation**: Validate all inputs
3. **Documentation**: Use OpenAPI/Swagger for documentation
4. **Testing**: Comprehensive API testing
5. **Monitoring**: API usage monitoring and analytics
