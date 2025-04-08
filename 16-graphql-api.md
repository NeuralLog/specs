# NeuralLog GraphQL API Specification

## Overview

This specification defines the optional GraphQL API for NeuralLog, providing a flexible and efficient way for clients to query and mutate data with precise control over the response structure.

## GraphQL Endpoint

```
https://api.{tenant-id}.neurallog.com/v1/graphql
```

## Authentication

GraphQL requests are authenticated using:

1. **JWT Token**: In the Authorization header
   ```
   Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

2. **API Key**: In a custom header
   ```
   X-API-Key: api-key-123
   ```

## Schema Overview

The GraphQL schema includes these main types:

- **Log**: Log entry data
- **Rule**: Rule configuration
- **Action**: Action configuration
- **User**: User information
- **Organization**: Organization information

## Core Types

### Log Type

```graphql
type Log {
  id: ID!
  timestamp: DateTime!
  level: LogLevel!
  message: String!
  source: String
  metadata: JSONObject
  tags: [String!]
  context: JSONObject
  tenant: Tenant
  organization: Organization
}

enum LogLevel {
  DEBUG
  INFO
  WARN
  ERROR
  FATAL
}
```

### Rule Type

```graphql
type Rule {
  id: ID!
  name: String!
  description: String
  condition: Condition!
  actions: [ActionReference!]!
  enabled: Boolean!
  createdAt: DateTime!
  updatedAt: DateTime
  createdBy: User
  tenant: Tenant
  organization: Organization
}

type Condition {
  type: String!
  parameters: JSONObject!
}

type ActionReference {
  actionId: ID!
  parameters: JSONObject
  action: Action
}
```

### Action Type

```graphql
type Action {
  id: ID!
  name: String!
  description: String
  type: String!
  parameters: JSONObject!
  createdAt: DateTime!
  updatedAt: DateTime
  createdBy: User
  tenant: Tenant
  organization: Organization
}
```

## Queries

### Log Queries

```graphql
type Query {
  # Get a specific log by ID
  log(id: ID!): Log
  
  # Search logs with filtering, sorting, and pagination
  logs(
    query: String
    filter: LogFilterInput
    sort: [SortInput!]
    limit: Int = 10
    offset: Int = 0
  ): LogConnection!
  
  # Get log statistics
  logStats(
    query: String
    filter: LogFilterInput
    timeframe: TimeframeInput
    groupBy: [String!]
  ): [LogStatistic!]!
}

input LogFilterInput {
  level: [LogLevel!]
  source: [String!]
  timeRange: TimeRangeInput
  metadata: JSONObject
  tags: [String!]
}

input TimeRangeInput {
  start: DateTime!
  end: DateTime!
}

input SortInput {
  field: String!
  order: SortOrder = DESC
}

enum SortOrder {
  ASC
  DESC
}

type LogConnection {
  edges: [LogEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type LogEdge {
  node: Log!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

type LogStatistic {
  key: String!
  count: Int!
  groupBy: JSONObject
}
```

### Rule Queries

```graphql
type Query {
  # Get a specific rule by ID
  rule(id: ID!): Rule
  
  # List rules with filtering and pagination
  rules(
    filter: RuleFilterInput
    sort: [SortInput!]
    limit: Int = 10
    offset: Int = 0
  ): RuleConnection!
}

input RuleFilterInput {
  name: String
  enabled: Boolean
  actionTypes: [String!]
}

type RuleConnection {
  edges: [RuleEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type RuleEdge {
  node: Rule!
  cursor: String!
}
```

### Action Queries

```graphql
type Query {
  # Get a specific action by ID
  action(id: ID!): Action
  
  # List actions with filtering and pagination
  actions(
    filter: ActionFilterInput
    sort: [SortInput!]
    limit: Int = 10
    offset: Int = 0
  ): ActionConnection!
}

input ActionFilterInput {
  name: String
  type: [String!]
}

type ActionConnection {
  edges: [ActionEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type ActionEdge {
  node: Action!
  cursor: String!
}
```

## Mutations

### Log Mutations

```graphql
type Mutation {
  # Create a new log entry
  createLog(input: CreateLogInput!): CreateLogPayload!
  
  # Delete logs matching a filter
  deleteLogs(input: DeleteLogsInput!): DeleteLogsPayload!
}

input CreateLogInput {
  level: LogLevel!
  message: String!
  source: String
  metadata: JSONObject
  tags: [String!]
  timestamp: DateTime
}

type CreateLogPayload {
  log: Log!
}

input DeleteLogsInput {
  filter: LogFilterInput!
}

type DeleteLogsPayload {
  deletedCount: Int!
}
```

### Rule Mutations

```graphql
type Mutation {
  # Create a new rule
  createRule(input: CreateRuleInput!): CreateRulePayload!
  
  # Update an existing rule
  updateRule(input: UpdateRuleInput!): UpdateRulePayload!
  
  # Delete a rule
  deleteRule(input: DeleteRuleInput!): DeleteRulePayload!
  
  # Enable or disable a rule
  toggleRuleStatus(input: ToggleRuleStatusInput!): ToggleRuleStatusPayload!
  
  # Test a rule against sample data
  testRule(input: TestRuleInput!): TestRulePayload!
}

input CreateRuleInput {
  name: String!
  description: String
  condition: ConditionInput!
  actions: [ActionReferenceInput!]!
  enabled: Boolean = true
}

input ConditionInput {
  type: String!
  parameters: JSONObject!
}

input ActionReferenceInput {
  actionId: ID!
  parameters: JSONObject
}

type CreateRulePayload {
  rule: Rule!
}

input UpdateRuleInput {
  id: ID!
  name: String
  description: String
  condition: ConditionInput
  actions: [ActionReferenceInput!]
  enabled: Boolean
}

type UpdateRulePayload {
  rule: Rule!
}

input DeleteRuleInput {
  id: ID!
}

type DeleteRulePayload {
  success: Boolean!
  id: ID!
}

input ToggleRuleStatusInput {
  id: ID!
  enabled: Boolean!
}

type ToggleRuleStatusPayload {
  rule: Rule!
}

input TestRuleInput {
  ruleId: ID
  rule: CreateRuleInput
  sampleData: JSONObject!
}

type TestRulePayload {
  matches: Boolean!
  actions: [TestActionResult!]!
}

type TestActionResult {
  actionId: ID!
  actionName: String!
  parameters: JSONObject!
  wouldExecute: Boolean!
}
```

## Subscriptions

```graphql
type Subscription {
  # Subscribe to new logs matching a filter
  logAdded(filter: LogFilterInput): Log!
  
  # Subscribe to rule triggers
  ruleTriggered(ruleId: ID): RuleTriggerEvent!
  
  # Subscribe to action executions
  actionExecuted(actionId: ID): ActionExecutionEvent!
}

type RuleTriggerEvent {
  rule: Rule!
  log: Log!
  triggeredAt: DateTime!
}

type ActionExecutionEvent {
  action: Action!
  rule: Rule
  status: String!
  executedAt: DateTime!
  result: JSONObject
}
```

## Scalar Types

```graphql
# ISO 8601 date-time string
scalar DateTime

# JSON object
scalar JSONObject
```

## Error Handling

GraphQL errors follow this structure:

```json
{
  "errors": [
    {
      "message": "Rule not found",
      "locations": [
        {
          "line": 6,
          "column": 7
        }
      ],
      "path": [
        "rule"
      ],
      "extensions": {
        "code": "NOT_FOUND",
        "resourceType": "Rule",
        "resourceId": "rule-123"
      }
    }
  ],
  "data": {
    "rule": null
  }
}
```

## Implementation Guidelines

1. **Schema First**: Use schema-first development approach
2. **Resolvers**: Implement efficient resolvers with proper data loading
3. **Batching**: Use DataLoader for batching and caching
4. **Authorization**: Implement field-level authorization
5. **Rate Limiting**: Apply rate limiting to complex queries
6. **Monitoring**: Track query complexity and performance
