# NeuralLog Core Architecture Specification

## Overview

NeuralLog is an intelligent logging system with automated action capabilities. It captures log events from various sources, analyzes patterns in those logs, and triggers configurable actions when specific conditions are met.

## Core Components

### 1. Log Ingestion Layer

The Log Ingestion Layer is responsible for collecting logs from various sources and normalizing them into a standard format.

#### Components:
- **Transport Adapters**: Integrations with popular logging frameworks (Winston, Pino, Bunyan, etc.)
- **Input Processors**: Normalize and enrich incoming log data
- **Buffering System**: Handle high-volume log ingestion with backpressure mechanisms

#### Requirements:
- Support for multiple logging frameworks
- Minimal performance impact on client applications
- Configurable buffering and batching
- Graceful handling of connection issues

### 2. Storage Layer

The Storage Layer manages the persistence of log data and related metadata.

#### Components:
- **Storage Adapters**: Support for different storage backends
- **Query Engine**: Efficient retrieval of logs based on various criteria
- **Retention Policies**: Manage log lifecycle based on configurable rules

#### Requirements:
- Pluggable storage backends (default: NeDB for simplicity)
- Efficient indexing for fast queries
- Support for structured and unstructured data
- Configurable retention policies

### 3. Analysis Layer

The Analysis Layer processes logs to identify patterns, anomalies, and trigger conditions.

#### Components:
- **Pattern Matcher**: Identify logs matching specific patterns
- **Frequency Analyzer**: Detect unusual frequency of specific log types
- **Correlation Engine**: Connect related logs across time and services
- **ML Integration**: Optional machine learning for advanced pattern detection

#### Requirements:
- Real-time analysis capabilities
- Support for complex pattern matching
- Extensible with custom analyzers
- Scalable to handle high log volumes

### 4. Condition System

The Condition System evaluates logs against defined conditions to determine when actions should be triggered.

#### Components:
- **Condition Registry**: Manage and store condition definitions
- **Condition Evaluator**: Evaluate logs against conditions
- **Condition Types**: Various condition implementations (pattern, threshold, test failure, etc.)

#### Requirements:
- Support for multiple condition types
- Composable conditions (AND, OR, NOT)
- Condition persistence and versioning
- Performance optimization for frequent condition evaluation

### 5. Action System

The Action System executes actions when conditions are met.

#### Components:
- **Action Registry**: Manage and store action definitions
- **Action Executor**: Execute actions with proper error handling and retries
- **Action Types**: Various action implementations (GitHub issues, notifications, webhooks, etc.)

#### Requirements:
- Support for multiple action types
- Configurable retry policies
- Action result tracking
- Throttling and rate limiting

### 6. Rule Engine

The Rule Engine connects conditions to actions through configurable rules.

#### Components:
- **Rule Registry**: Manage and store rule definitions
- **Rule Evaluator**: Evaluate which rules should trigger for a given log event
- **Rule Executor**: Coordinate the execution of actions for triggered rules

#### Requirements:
- Support for complex rule definitions
- Rule prioritization and ordering
- Rule versioning and history
- Performance optimization for rule evaluation

### 7. Plugin System

The Plugin System enables extensibility across all layers of the architecture.

#### Components:
- **Plugin Registry**: Manage and load plugins
- **Plugin Manager**: Handle plugin lifecycle
- **Extension Points**: Well-defined interfaces for extending functionality

#### Requirements:
- Support for various plugin types
- Plugin isolation and error containment
- Version compatibility checking
- Dynamic loading and unloading

### 8. API Layer

The API Layer provides interfaces for interacting with the system.

#### Components:
- **REST API**: HTTP endpoints for system management
- **WebSocket API**: Real-time log streaming and notifications
- **MCP Integration**: Tools for MCP server integration

#### Requirements:
- Comprehensive API coverage
- Authentication and authorization
- Rate limiting and throttling
- Documentation and client libraries

## Cross-Cutting Concerns

### Zero-Knowledge Security
- Client-side encryption for all data using a hierarchical key system
- Three-tier key hierarchy: Master Secret → Master KEK → Operational KEKs
- KEK versioning for secure key rotation
- Encrypted KEK blobs for secure key distribution
- Searchable encryption for encrypted data
- Zero server knowledge of plaintext or keys
- Shamir's Secret Sharing (M-of-N) for administrative key recovery
- Complete tenant isolation through cryptography

### Scalability
- Horizontal scaling of components
- Load balancing
- Resource efficiency
- Performance monitoring

### Tenant Isolation
- Complete isolation at Kubernetes level
- Organization separation via namespaces
- Resource quotas and limits
- Data segregation

### Observability
- Internal logging
- Metrics collection
- Distributed tracing
- Health checks

## Deployment Models

### Self-Hosted
- Kubernetes deployment (Helm charts)
- Docker Compose deployment
- Standalone deployment

### Cloud-Hosted
- Multi-tenant SaaS offering
- Free tier with same architecture
- Paid tiers with additional features/capacity
- Tenant management system

## Integration Points

### Client SDKs
- TypeScript/JavaScript
- Unity
- Python
- Java
- Go

### External Systems
- CI/CD platforms
- Issue trackers
- Monitoring systems
- Notification services

## Zero-Knowledge Data Flow

1. Client application initializes with recovery phrase or mnemonic
2. Master Secret is derived from tenant ID and recovery phrase
3. Master KEK is derived from Master Secret
4. Operational KEKs are derived from Master KEK for each KEK version
5. Client application generates log data
6. Log name is encrypted using a key derived from the Operational KEK
7. Log data is encrypted using a key derived from the Operational KEK
8. SDK generates search tokens for searchable terms
9. Encrypted logs, KEK version information, and search tokens are sent to the server
10. Server stores encrypted logs and indexes search tokens without ability to decrypt
11. Server performs analysis on search tokens without decryption
12. Client requests logs with search queries
13. Server matches search tokens and returns encrypted logs
14. Client decrypts logs using the appropriate Operational KEK based on version information
15. Zero-knowledge reports are generated from token patterns

## Performance Considerations

- Log ingestion: 10,000+ logs per second per node
- Storage: Efficient compression and indexing
- Analysis: Real-time processing with minimal latency
- Rule evaluation: Optimized for high-throughput
- Action execution: Asynchronous with proper backpressure

## Future Expansion

- Advanced ML-based pattern detection
- Predictive analytics
- Automated remediation
- Integration with additional external systems
