# NeuralLog Monitoring and Observability Specification

## Overview

This specification defines the monitoring and observability strategy for NeuralLog, ensuring the platform's health, performance, and reliability can be effectively monitored and issues quickly diagnosed.

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Monitoring Stack                        │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Metrics     │  │ Logging     │  │ Tracing             │  │
│  │             │  │             │  │                     │  │
│  │ • Prometheus│  │ • Fluentd   │  │ • OpenTelemetry     │  │
│  │ • Grafana   │  │ • Elastic   │  │ • Jaeger            │  │
│  │ • Alerts    │  │ • Kibana    │  │ • Spans             │  │
│  │             │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Health      │  │ Synthetic   │  │ Alerting            │  │
│  │ Checks      │  │ Monitoring  │  │                     │  │
│  │             │  │             │  │ • Alert Manager     │  │
│  │ • Readiness │  │ • Canaries  │  │ • PagerDuty         │  │
│  │ • Liveness  │  │ • E2E Tests │  │ • Slack             │  │
│  │ • Probes    │  │ • Uptime    │  │ • Email             │  │
│  │             │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Key Metrics

### System Metrics

1. **CPU Usage**:
   - Per service
   - Per node
   - Utilization percentages

2. **Memory Usage**:
   - Per service
   - Per node
   - Heap vs. non-heap (for JVM services)

3. **Disk Usage**:
   - Storage utilization
   - I/O operations
   - Latency

4. **Network**:
   - Bandwidth usage
   - Connection counts
   - Packet loss

### Application Metrics

1. **Request Metrics**:
   - Request rate
   - Error rate
   - Latency (p50, p90, p99)
   - Request size

2. **Database Metrics**:
   - Query rate
   - Query latency
   - Connection pool usage
   - Transaction rate

3. **Cache Metrics**:
   - Hit rate
   - Miss rate
   - Eviction rate
   - Memory usage

4. **Queue Metrics**:
   - Queue depth
   - Processing rate
   - Processing time
   - Error rate

### Business Metrics

1. **Log Volume**:
   - Logs per second
   - Logs per tenant
   - Log size distribution

2. **Rule Execution**:
   - Rules triggered
   - Rule execution time
   - Rule success/failure rate

3. **Action Execution**:
   - Actions executed
   - Action execution time
   - Action success/failure rate

4. **User Activity**:
   - Active users
   - API calls per user
   - Session duration

## Prometheus Configuration

### Service Instrumentation

All NeuralLog services expose Prometheus metrics:

```yaml
# Example Prometheus annotations
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

### Metric Naming Convention

Metrics follow a consistent naming convention:

```
neurallog_{service}_{metric_name}_{unit}
```

Examples:
- `neurallog_api_requests_total`
- `neurallog_log_service_processing_time_seconds`
- `neurallog_rule_service_rules_triggered_total`

### Service Discovery

Prometheus uses Kubernetes service discovery:

```yaml
# Prometheus configuration
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
```

## Logging Strategy

### Log Levels

NeuralLog uses standard log levels:

- **DEBUG**: Detailed debugging information
- **INFO**: General operational information
- **WARN**: Warning events that might cause issues
- **ERROR**: Error events that might still allow the application to continue
- **FATAL**: Severe error events that cause the application to terminate

### Structured Logging

All logs are structured in JSON format:

```json
{
  "timestamp": "2023-04-08T12:34:56.789Z",
  "level": "INFO",
  "service": "api-service",
  "instance": "api-service-5d8f7b9c8-xvz2p",
  "message": "Request processed successfully",
  "traceId": "abc123",
  "spanId": "def456",
  "requestId": "req-789",
  "tenantId": "tenant-123",
  "userId": "user-456",
  "path": "/api/v1/logs",
  "method": "POST",
  "statusCode": 200,
  "duration": 45,
  "metadata": {
    "logCount": 10,
    "batchSize": 1024
  }
}
```

### Log Collection

Logs are collected using Fluentd:

```yaml
# Fluentd configuration
<source>
  @type tail
  path /var/log/containers/*.log
  pos_file /var/log/fluentd-containers.log.pos
  tag kubernetes.*
  read_from_head true
  <parse>
    @type json
    time_format %Y-%m-%dT%H:%M:%S.%NZ
  </parse>
</source>

<filter kubernetes.**>
  @type kubernetes_metadata
  kubernetes_url https://kubernetes.default.svc
  bearer_token_file /var/run/secrets/kubernetes.io/serviceaccount/token
  ca_file /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
</filter>

<match kubernetes.var.log.containers.**neurallog**.log>
  @type elasticsearch
  host elasticsearch
  port 9200
  logstash_format true
  logstash_prefix neurallog
  <buffer>
    @type file
    path /var/log/fluentd-buffers/kubernetes.containers.buffer
    flush_mode interval
    retry_type exponential_backoff
    flush_thread_count 2
    flush_interval 5s
    retry_forever
    retry_max_interval 30
    chunk_limit_size 2M
    queue_limit_length 8
    overflow_action block
  </buffer>
</match>
```

## Distributed Tracing

### OpenTelemetry Integration

NeuralLog uses OpenTelemetry for distributed tracing:

```yaml
# OpenTelemetry configuration
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: neurallog-otel-collector
spec:
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
      
      resourcedetection:
        detectors: [env, kubernetes]
        timeout: 2s
    
    exporters:
      jaeger:
        endpoint: jaeger-collector:14250
        tls:
          insecure: true
      
      prometheus:
        endpoint: 0.0.0.0:8889
    
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch, resourcedetection]
          exporters: [jaeger]
        metrics:
          receivers: [otlp]
          processors: [batch, resourcedetection]
          exporters: [prometheus]
```

### Trace Context Propagation

Trace context is propagated through:

1. **HTTP Headers**:
   - `traceparent`
   - `tracestate`

2. **Message Headers**:
   - For Kafka messages
   - For RabbitMQ messages

3. **Database Comments**:
   - SQL query comments with trace IDs

## Health Checks

### Kubernetes Probes

All services implement Kubernetes health probes:

```yaml
# Health probe configuration
readinessProbe:
  httpGet:
    path: /health/readiness
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health/liveness
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 20
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /health/startup
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 30
```

### Health Check Endpoints

Standard health check endpoints:

1. **Liveness**: `/health/liveness`
   - Basic check that the service is running
   - No dependency checks

2. **Readiness**: `/health/readiness`
   - Check that the service is ready to accept traffic
   - Includes dependency checks

3. **Startup**: `/health/startup`
   - Check that the service has completed startup
   - More lenient than readiness

4. **Health**: `/health`
   - Comprehensive health check
   - Includes all dependencies
   - Returns detailed status

## Alerting

### Alert Rules

Example Prometheus alert rules:

```yaml
groups:
- name: neurallog-alerts
  rules:
  - alert: HighErrorRate
    expr: sum(rate(neurallog_api_requests_total{status_code=~"5.."}[5m])) / sum(rate(neurallog_api_requests_total[5m])) > 0.05
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is above 5% for the last 5 minutes"

  - alert: ServiceDown
    expr: up{job=~"neurallog-.*"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service {{ $labels.job }} is down"
      description: "Service {{ $labels.job }} has been down for more than 1 minute"

  - alert: HighLatency
    expr: histogram_quantile(0.95, sum(rate(neurallog_api_request_duration_seconds_bucket[5m])) by (le, service)) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High latency detected for {{ $labels.service }}"
      description: "95th percentile latency is above 1 second for {{ $labels.service }}"
```

### Alert Routing

Alert Manager configuration:

```yaml
route:
  group_by: ['alertname', 'service', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'slack-notifications'
  routes:
  - match:
      severity: critical
    receiver: 'pagerduty-critical'
    continue: true
  - match:
      severity: warning
    receiver: 'slack-notifications'

receivers:
- name: 'slack-notifications'
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
    channel: '#monitoring'
    send_resolved: true
    title: '{{ template "slack.default.title" . }}'
    text: '{{ template "slack.default.text" . }}'

- name: 'pagerduty-critical'
  pagerduty_configs:
  - service_key: '0123456789abcdef0123456789abcdef'
    send_resolved: true
```

## Dashboards

### System Dashboard

Key panels:
- CPU usage per service
- Memory usage per service
- Disk usage
- Network traffic
- Node status

### Application Dashboard

Key panels:
- Request rate
- Error rate
- Latency (p50, p90, p99)
- Active connections
- Database queries
- Cache hit rate

### Business Dashboard

Key panels:
- Logs ingested per second
- Rules triggered per minute
- Actions executed per minute
- Active users
- Tenant usage

## Implementation Guidelines

1. **Instrumentation**: Instrument all services with metrics, logs, and traces
2. **Correlation**: Ensure correlation between metrics, logs, and traces
3. **Cardinality**: Be mindful of high cardinality metrics
4. **Retention**: Configure appropriate retention periods
5. **Aggregation**: Use appropriate aggregation for long-term storage
6. **Dashboards**: Create useful, actionable dashboards
7. **Alerts**: Configure meaningful alerts with clear remediation steps
