# NeuralLog API Versioning Specification

## Overview

This specification defines the API versioning strategy for NeuralLog, ensuring backward compatibility while allowing for evolution of the API.

## Versioning Strategy

NeuralLog uses a URI path-based versioning strategy:

```
https://api.{tenant-id}.neurallog.com/v1/logs
https://api.{tenant-id}.neurallog.com/v2/logs
```

## Version Lifecycle

Each API version follows this lifecycle:

1. **Preview**: Early access for testing
2. **Stable**: Generally available for production use
3. **Deprecated**: Still available but marked for removal
4. **Sunset**: No longer available

## Version Support Policy

- **Minimum Support**: Each stable API version is supported for at least 12 months
- **Deprecation Notice**: 6 months notice before deprecation
- **Sunset Notice**: 3 months notice before sunset
- **Documentation**: All versions remain documented even after sunset

## Version Compatibility

### Backward Compatibility Guarantees

For stable API versions, NeuralLog guarantees:

1. **No Breaking Changes**: Existing functionality remains unchanged
2. **No Removed Fields**: Fields are not removed from responses
3. **No Changed Types**: Field types remain consistent
4. **No New Required Parameters**: New parameters are optional

### Allowed Changes

Changes that may be made without incrementing the major version:

1. **Adding Fields**: New fields in responses
2. **Adding Endpoints**: New API endpoints
3. **Adding Parameters**: New optional parameters
4. **Extending Enums**: New enum values
5. **Relaxing Constraints**: Less restrictive validation

## Version Headers

API responses include version information in headers:

```
X-API-Version: v1
X-API-Deprecated: false
X-API-Sunset-Date: null
```

For deprecated versions:

```
X-API-Version: v1
X-API-Deprecated: true
X-API-Sunset-Date: 2024-06-30
X-API-Successor-Version: v2
```

## Version Discovery

Clients can discover available versions:

```
GET /api-versions
```

Response:

```json
{
  "data": [
    {
      "version": "v1",
      "status": "stable",
      "releaseDate": "2023-01-15",
      "deprecated": false,
      "sunsetDate": null
    },
    {
      "version": "v2",
      "status": "preview",
      "releaseDate": "2023-04-01",
      "deprecated": false,
      "sunsetDate": null
    }
  ],
  "meta": {
    "currentVersion": "v1",
    "latestStableVersion": "v1",
    "latestPreviewVersion": "v2"
  }
}
```

## Version Documentation

Each API version has dedicated documentation:

```
https://docs.neurallog.com/api/v1
https://docs.neurallog.com/api/v2
```

## Migration Guides

When releasing a new version, NeuralLog provides:

1. **Migration Guide**: Step-by-step migration instructions
2. **Changelog**: Detailed list of changes
3. **Compatibility Tools**: Tools to assess migration impact

## Implementation Guidelines

1. **API Gateway**: Implement versioning at the API gateway level
2. **Code Organization**: Organize code by API version
3. **Shared Core**: Maintain shared core logic across versions
4. **Testing**: Test all supported versions
5. **Monitoring**: Track usage by version
