# NeuralLog: Zero-Knowledge Searchable Encryption

## Overview

NeuralLog implements a novel searchable encryption scheme that enables powerful search capabilities over encrypted data without requiring the server to decrypt the data. This specification details how searchable encryption works in NeuralLog.

## Core Principles

1. **Zero Server Knowledge**: Server never sees plaintext content or search terms
2. **Client-Side Token Generation**: Search tokens are generated client-side
3. **Server-Side Token Indexing**: Tokens are indexed on the server without revealing content
4. **Tenant-Consistent Keys**: Users in the same tenant can search the same logs
5. **Minimal Information Leakage**: Only reveals which documents contain the same terms

## Token-Based Searchable Encryption

### Token Generation

Search tokens are generated using HMAC with tenant-specific search keys:

```javascript
async function generateSearchTokens(content, searchKey, tenantId) {
  // Extract searchable terms
  const terms = extractSearchableTerms(content);
  
  // For each term, generate a deterministic but secure token
  return Promise.all(terms.map(async term => {
    // Important: Combine the term with tenant ID to ensure tenant isolation
    const tokenInput = `${tenantId}:${term.toLowerCase().trim()}`;
    
    // Generate HMAC token
    const encoder = new TextEncoder();
    const keyData = await crypto.subtle.importKey(
      "raw",
      searchKey,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    
    const signature = await crypto.subtle.sign(
      "HMAC",
      keyData,
      encoder.encode(tokenInput)
    );
    
    return arrayBufferToBase64(signature);
  }));
}
```

### Term Extraction

Terms are extracted from content using natural language processing techniques:

```javascript
function extractSearchableTerms(content) {
  // Convert content to string if it's not already
  const contentStr = typeof content === 'string'
    ? content
    : JSON.stringify(content);
  
  // Extract words and normalize
  const words = contentStr
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter(word => word.length > 2); // Filter out short words
  
  // Deduplicate words
  return [...new Set(words)];
}
```

## Server-Side Token Storage

Tokens are stored in Redis for efficient searching:

```javascript
// Server-side
async function storeSearchTokens(logId, searchTokens, tenantId) {
  const redis = getRedisForTenant(tenantId);
  
  // For each token, store a reference to this log
  for (const token of searchTokens) {
    await redis.sadd(
      `tenant:${tenantId}:search:token:${token}`,
      logId
    );
  }
  
  // Store the tokens for this log
  await redis.sadd(
    `tenant:${tenantId}:log:${logId}:tokens`,
    ...searchTokens
  );
}
```

## Search Process

Searching is performed by generating tokens from the search query:

```javascript
// Client-side
async function search(query, searchKey, tenantId) {
  // Generate search tokens from the query
  const searchTokens = await generateSearchTokens({ query }, searchKey, tenantId);
  
  // Send search request to server
  const response = await fetch(`/api/logs/search`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'X-Tenant-ID': tenantId
    },
    body: JSON.stringify({
      tokens: searchTokens
    })
  });
  
  // Get encrypted log entries
  const { entries } = await response.json();
  
  // Decrypt entries client-side
  return await decryptLogEntries(entries, encryptionKey);
}

// Server-side
async function handleSearchRequest(req, res) {
  const { tokens } = req.body;
  const { tenantId } = req.headers;
  
  const redis = getRedisForTenant(tenantId);
  
  // Find logs that match all tokens
  let matchingLogIds = null;
  
  for (const token of tokens) {
    const logIds = await redis.smembers(
      `tenant:${tenantId}:search:token:${token}`
    );
    
    if (matchingLogIds === null) {
      matchingLogIds = new Set(logIds);
    } else {
      // Intersection - logs must match all tokens
      matchingLogIds = new Set(
        [...matchingLogIds].filter(id => logIds.includes(id))
      );
    }
    
    if (matchingLogIds.size === 0) {
      break; // No matches, stop early
    }
  }
  
  // Get the encrypted log entries
  const entries = await getEncryptedLogEntries(
    Array.from(matchingLogIds),
    tenantId
  );
  
  res.json({ entries });
}
```

## Tenant-Consistent Search Keys

To enable multiple users in the same tenant to search the same logs:

```javascript
// Client-side
async function deriveSearchKey(apiKey, tenantId) {
  // 1. First derive a user-specific key from the API key
  const userKey = await deriveUserKey(apiKey);
  
  // 2. Use the user key to authenticate to the server
  const response = await fetch('/api/tenant/search-key-material', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'X-Tenant-ID': tenantId
    }
  });
  
  // 3. Get tenant-specific key material (same for all tenant users)
  const { keyMaterial } = await response.json();
  
  // 4. Combine user key with tenant key material
  // This produces the same search key for all users in the tenant
  return await crypto.subtle.deriveKey(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: hexToArrayBuffer(keyMaterial),
      info: new TextEncoder().encode("search-key")
    },
    userKey,
    { name: "HMAC", hash: "SHA-256", length: 256 },
    true,
    ["sign"]
  );
}
```

## Advanced Search Capabilities

NeuralLog's searchable encryption supports advanced search features:

### 1. Phrase Search

```javascript
function generatePhraseTokens(phrase, searchKey, tenantId) {
  // Generate tokens for the entire phrase
  const phraseToken = generateToken(`phrase:${phrase}`, searchKey, tenantId);
  
  // Also generate tokens for individual words for fallback
  const wordTokens = phrase.split(/\s+/).map(word => 
    generateToken(word, searchKey, tenantId)
  );
  
  return [phraseToken, ...wordTokens];
}
```

### 2. Field-Specific Search

```javascript
function generateFieldTokens(field, value, searchKey, tenantId) {
  // Generate token for field:value pair
  return generateToken(`field:${field}:${value}`, searchKey, tenantId);
}
```

### 3. Numeric Range Search

```javascript
function generateRangeTokens(field, min, max, searchKey, tenantId) {
  // For numeric ranges, generate tokens for bucketed values
  const tokens = [];
  const bucketSize = 10; // Adjust based on precision needs
  
  for (let bucket = Math.floor(min / bucketSize); 
       bucket <= Math.floor(max / bucketSize); 
       bucket++) {
    tokens.push(
      generateToken(`range:${field}:${bucket}`, searchKey, tenantId)
    );
  }
  
  return tokens;
}
```

## AI-Powered Analysis on Encrypted Data

NeuralLog enables AI-powered analysis on encrypted data:

### 1. Pattern Detection

```javascript
// Server-side
async function detectPatterns(tenantId, timeRange) {
  const redis = getRedisForTenant(tenantId);
  
  // Get all tokens used in the time range
  const tokens = await getTokensInTimeRange(redis, tenantId, timeRange);
  
  // Count token co-occurrences
  const cooccurrences = await countTokenCooccurrences(redis, tenantId, tokens);
  
  // Find significant patterns
  const patterns = findSignificantPatterns(cooccurrences);
  
  return patterns;
}
```

### 2. Anomaly Detection

```javascript
// Server-side
async function detectAnomalies(tenantId, timeRange) {
  const redis = getRedisForTenant(tenantId);
  
  // Get token frequency baseline
  const baseline = await getTokenFrequencyBaseline(redis, tenantId);
  
  // Get current token frequencies
  const current = await getTokenFrequencies(redis, tenantId, timeRange);
  
  // Detect significant deviations
  const anomalies = detectSignificantDeviations(baseline, current);
  
  return anomalies;
}
```

### 3. Zero-Knowledge Reports

```javascript
// Server-side
async function generateZeroKnowledgeReport(tenantId, timeRange) {
  // Generate report with token patterns and frequencies
  // without knowing what the tokens represent
  
  const patterns = await detectPatterns(tenantId, timeRange);
  const anomalies = await detectAnomalies(tenantId, timeRange);
  const volumeMetrics = await getVolumeMetrics(tenantId, timeRange);
  
  return {
    patterns,
    anomalies,
    volumeMetrics
  };
}
```

## Security Properties

NeuralLog's searchable encryption provides:

1. **Zero Knowledge**: Server never learns plaintext content or search terms
2. **Tenant Isolation**: Search tokens are tenant-specific
3. **Forward Security**: Revoked users cannot search historical data
4. **Minimal Leakage**: Only reveals which documents contain the same terms

## Security Considerations

1. **Token Inference**: With enough data, statistical analysis might reveal patterns
2. **Update Security**: Adding or removing searchable terms requires careful handling
3. **Query Privacy**: Search patterns themselves might reveal sensitive information

## Implementation Guidelines

1. **Token Size**: Use full-length HMAC outputs (32 bytes) for security
2. **Normalization**: Consistently normalize terms before token generation
3. **Selective Indexing**: Only index terms that need to be searchable
4. **Rate Limiting**: Implement rate limiting to prevent brute force attacks
