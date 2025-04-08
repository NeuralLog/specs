# NeuralLog Event-Action Model Specification

## Overview

The Event-Action Model is the core paradigm of NeuralLog, defining how log events are processed and how actions are triggered based on conditions. This specification details the structure and flow of the event-action model.

## Key Concepts

### Log Event

A Log Event represents a single log entry captured by the system.

#### Structure:

```typescript
interface LogEvent {
  id: string;                      // Unique identifier
  source: string;                  // Source of the log (application, service, etc.)
  level: LogLevel;                 // Severity level (DEBUG, INFO, WARN, ERROR, FATAL)
  message: string;                 // Log message
  timestamp: Date;                 // When the log was generated
  metadata: Record<string, any>;   // Additional structured data
  context?: {                      // Optional contextual information
    testInfo?: TestInfo;           // Information about test execution
    errorInfo?: ErrorInfo;         // Detailed error information
    environmentInfo?: EnvironmentInfo; // Environment details
    traceInfo?: TraceInfo;         // Distributed tracing information
  };
  tags?: string[];                 // Optional tags for categorization
}

enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  FATAL = 4
}
```

### Condition

A Condition defines criteria that determine when an action should be triggered.

#### Structure:

```typescript
interface Condition {
  id: string;                      // Unique identifier
  name: string;                    // Human-readable name
  description?: string;            // Optional description
  type: ConditionType;             // Type of condition
  parameters: Record<string, any>; // Condition-specific parameters
  enabled: boolean;                // Whether the condition is active
  evaluate(event: LogEvent): boolean; // Evaluation function
}

enum ConditionType {
  LOG_LEVEL,                       // Based on log severity
  PATTERN_MATCH,                   // Based on message pattern
  FREQUENCY,                       // Based on occurrence frequency
  TEST_FAILURE,                    // Based on test results
  COMPOSITE,                       // Combination of other conditions
  CUSTOM                           // Custom plugin-defined condition
}
```

### Action

An Action defines what should happen when a condition is met.

#### Structure:

```typescript
interface Action {
  id: string;                      // Unique identifier
  name: string;                    // Human-readable name
  description?: string;            // Optional description
  type: ActionType;                // Type of action
  parameters: Record<string, any>; // Action-specific parameters
  enabled: boolean;                // Whether the action is active
  execute(event: LogEvent, context: ActionContext): Promise<ActionResult>; // Execution function
}

enum ActionType {
  GITHUB_ISSUE,                    // Create/update GitHub issues
  NOTIFICATION,                    // Send notifications
  WEBHOOK,                         // Call webhooks
  SCRIPT,                          // Execute scripts
  CUSTOM                           // Custom plugin-defined action
}

interface ActionResult {
  success: boolean;                // Whether the action succeeded
  message?: string;                // Optional result message
  data?: Record<string, any>;      // Action-specific result data
}
```

### Rule

A Rule connects conditions to actions, defining when specific actions should be triggered.

#### Structure:

```typescript
interface Rule {
  id: string;                      // Unique identifier
  name: string;                    // Human-readable name
  description?: string;            // Optional description
  conditionIds: string[];          // IDs of conditions to evaluate
  actionIds: string[];             // IDs of actions to execute
  enabled: boolean;                // Whether the rule is active
  priority: number;                // Execution priority (higher = earlier)
  cooldown?: number;               // Minimum time between triggers (ms)
  lastTriggered?: Date;            // When the rule was last triggered
}
```

## Event Processing Flow

1. **Log Event Ingestion**:
   - Log event is received through a transport adapter
   - Event is normalized and enriched
   - Event is assigned a unique ID and timestamp

2. **Event Storage**:
   - Event is persisted to the storage layer
   - Indexes are updated for efficient querying

3. **Condition Evaluation**:
   - Event is passed to the Condition System
   - All active conditions are evaluated against the event
   - Matching conditions are identified

4. **Rule Evaluation**:
   - Rules containing matching conditions are identified
   - Rule eligibility is checked (enabled, cooldown, etc.)
   - Eligible rules are selected for execution

5. **Action Execution**:
   - Actions associated with eligible rules are executed
   - Action results are captured
   - Action execution is retried if necessary

6. **Result Processing**:
   - Action results are stored
   - Notifications are sent if configured
   - Rule state is updated (lastTriggered, etc.)

## Condition Types

### Log Level Condition

Triggers when a log event has a severity level at or above a specified threshold.

#### Parameters:
- `minLevel`: Minimum log level to trigger (e.g., ERROR)
- `sources`: Optional list of sources to include/exclude

### Pattern Match Condition

Triggers when a log message matches a specified pattern.

#### Parameters:
- `pattern`: String or regex pattern to match
- `field`: Field to match against (message, source, etc.)
- `caseSensitive`: Whether matching is case-sensitive

### Frequency Condition

Triggers when logs matching certain criteria occur at a specified frequency.

#### Parameters:
- `threshold`: Number of occurrences to trigger
- `timeWindow`: Time window to consider (ms)
- `criteria`: Criteria to match logs (level, source, etc.)

### Test Failure Condition

Triggers when a test failure is detected.

#### Parameters:
- `testPattern`: Pattern to match test names
- `includeSkipped`: Whether to include skipped tests
- `includeFlaky`: Whether to include known flaky tests

### Composite Condition

Combines multiple conditions with logical operators.

#### Parameters:
- `operator`: Logical operator (AND, OR, NOT)
- `conditions`: List of condition IDs to combine

## Action Types

### GitHub Issue Action

Creates, updates, or closes GitHub issues.

#### Parameters:
- `repository`: GitHub repository
- `labels`: Issue labels
- `assignees`: Issue assignees
- `template`: Issue template
- `updateExisting`: Whether to update existing issues

### Notification Action

Sends notifications through various channels.

#### Parameters:
- `channel`: Notification channel (email, Slack, etc.)
- `recipients`: Recipients of the notification
- `template`: Notification template
- `priority`: Notification priority

### Webhook Action

Calls a webhook with event data.

#### Parameters:
- `url`: Webhook URL
- `method`: HTTP method
- `headers`: HTTP headers
- `bodyTemplate`: Template for request body
- `retryConfig`: Retry configuration

### Script Action

Executes a script with event data.

#### Parameters:
- `script`: Script content or path
- `runtime`: Script runtime (node, python, etc.)
- `timeout`: Execution timeout
- `parameters`: Script parameters

## Rule Configuration

Rules can be configured through:

1. **API**: REST API endpoints for CRUD operations
2. **Configuration Files**: YAML/JSON configuration files
3. **Web Interface**: User-friendly web interface
4. **SDK**: Programmatic configuration through client SDKs

### Example Configuration (YAML):

```yaml
rules:
  - id: error-notification
    name: "Error Notification Rule"
    description: "Send notification when errors occur"
    conditionIds: ["error-level-condition"]
    actionIds: ["slack-notification"]
    enabled: true
    priority: 100
    cooldown: 300000  # 5 minutes

conditions:
  - id: error-level-condition
    name: "Error Level Condition"
    type: LOG_LEVEL
    parameters:
      minLevel: ERROR
      sources: ["api-service", "auth-service"]
    enabled: true

actions:
  - id: slack-notification
    name: "Slack Notification"
    type: NOTIFICATION
    parameters:
      channel: slack
      recipients: ["#alerts"]
      template: "error-notification-template"
      priority: high
    enabled: true
```

## Extension Points

The Event-Action Model provides several extension points for plugins:

1. **Custom Condition Types**: Define new types of conditions
2. **Custom Action Types**: Define new types of actions
3. **Event Processors**: Modify or enrich events during processing
4. **Rule Evaluators**: Customize rule evaluation logic
5. **Action Executors**: Customize action execution logic

## Performance Considerations

- **Condition Evaluation**: Optimize for frequent evaluation
- **Rule Matching**: Use efficient algorithms for rule matching
- **Action Execution**: Execute actions asynchronously
- **Cooldown Periods**: Prevent excessive action execution
- **Batching**: Batch similar actions when possible
