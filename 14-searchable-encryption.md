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

Search tokens are generated using HMAC with search keys derived from the Operational KEK:

```javascript
async function generateSearchTokens(content, searchKey, kekVersion) {
  // Extract searchable terms
  const terms = extractSearchableTerms(content);

  // For each term, generate a deterministic but secure token
  return Promise.all(terms.map(async term => {
    // Important: Normalize the term
    const normalizedTerm = term.toLowerCase().trim();

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
      encoder.encode(normalizedTerm)
    );

    // Include KEK version with the token
    return {
      token: arrayBufferToBase64(signature),
      kekVersion
    };
  }));
}

// Derive search key from Operational KEK
async function deriveSearchKey(operationalKEK) {
  // Import operational KEK as key material
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    operationalKEK,
    { name: 'HKDF' },
    false,
    ['deriveBits']
  );

  // Derive bits using HKDF
  const derivedBits = await crypto.subtle.deriveBits(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new TextEncoder().encode('NeuralLog-SearchKey'),
      info: new TextEncoder().encode('search-tokens')
    },
    keyMaterial,
    256
  );

  return new Uint8Array(derivedBits);
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
async function search(query, logName) {
  try {
    // Encrypt the log name
    const encryptedLogName = await this.cryptoService.encryptLogName(logName);

    // Get a resource token for the log
    const resourceToken = await this.authService.getResourceToken(
      `logs/${encryptedLogName}`,
      this.authManager.getAuthCredential()
    );

    // Get all available KEK versions
    const kekVersions = Array.from(this.cryptoService.getOperationalKEKs().keys());

    // Generate search tokens for each KEK version
    const allTokens = [];

    for (const kekVersion of kekVersions) {
      // Derive the search key for this version
      const searchKey = await this.cryptoService.deriveSearchKey(kekVersion);

      // Generate tokens
      const tokens = await this.cryptoService.generateSearchTokens(
        { query },
        searchKey,
        kekVersion
      );

      allTokens.push(...tokens);
    }

    // Send search request to server
    const response = await this.logsService.searchLogs(
      encryptedLogName,
      allTokens,
      resourceToken
    );

    // Decrypt entries client-side
    const decryptedLogs = await Promise.all(
      response.map(async (log) => {
        try {
          const decryptedData = await this.cryptoService.decryptLogData(log.data);
          return {
            id: log.id,
            timestamp: log.timestamp,
            data: decryptedData
          };
        } catch (error) {
          console.error(`Failed to decrypt log ${log.id}:`, error);
          return {
            id: log.id,
            timestamp: log.timestamp,
            data: { error: 'Failed to decrypt log data' }
          };
        }
      })
    );

    return decryptedLogs;
  } catch (error) {
    throw new LogError(
      `Failed to search logs: ${error instanceof Error ? error.message : String(error)}`,
      'search_logs_failed'
    );
  }
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

To enable multiple users in the same tenant to search the same logs, all users in a tenant have access to the same KEK versions through encrypted KEK blobs:

```javascript
// Client-side
async function initializeKeyHierarchy() {
  try {
    // Get KEK blobs for the current user
    const kekBlobs = await this.kekService.getUserKEKBlobs(
      this.authManager.getAuthCredential()
    );

    // Decrypt each KEK blob
    for (const blob of kekBlobs) {
      try {
        // Parse the encrypted blob
        const parsedBlob = JSON.parse(blob.encryptedBlob);

        // Decrypt the operational KEK
        const operationalKEK = this.base64ToArrayBuffer(parsedBlob.data);

        // Store the operational KEK
        this.operationalKEKs.set(blob.kekVersionId, new Uint8Array(operationalKEK));

        // Set the current KEK version if not set or if this is a newer version
        if (!this.currentKEKVersion ||
            (blob.kekVersionId > this.currentKEKVersion &&
             await this.kekService.isKEKVersionActive(blob.kekVersionId, this.authManager.getAuthCredential()))) {
          this.currentKEKVersion = blob.kekVersionId;
        }
      } catch (error) {
        console.error(`Failed to decrypt KEK blob for version ${blob.kekVersionId}:`, error);
      }
    }

    if (!this.currentKEKVersion) {
      throw new Error('No valid KEK version found');
    }
  } catch (error) {
    throw new LogError(
      `Failed to initialize key hierarchy: ${error instanceof Error ? error.message : String(error)}`,
      'initialize_key_hierarchy_failed'
    );
  }
}

// Derive search key from the operational KEK
async function deriveSearchKey(kekVersion) {
  // Get the operational KEK for this version
  const operationalKEK = this.getOperationalKEK(kekVersion);

  if (!operationalKEK) {
    throw new Error(`Operational KEK not found for version ${kekVersion}`);
  }

  // Derive the search key
  return await KeyDerivation.deriveKeyWithHKDF(operationalKEK, {
    salt: 'NeuralLog-SearchKey',
    info: 'search-tokens',
    hash: 'SHA-256',
    keyLength: 256
  });
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

### 3. FFT Analysis on Searchable Encryption Hashes

```javascript
// Server-side
async function performFFTAnalysis(tenantId, timeRange) {
  const redis = getRedisForTenant(tenantId);

  // Get token time series data
  const tokenTimeSeries = await getTokenTimeSeries(redis, tenantId, timeRange);

  // Apply FFT to each token's time series
  const fftResults = {};

  for (const [token, timeSeries] of Object.entries(tokenTimeSeries)) {
    // Apply FFT to the time series
    const fft = applyFFT(timeSeries);

    // Find dominant frequencies
    const dominantFrequencies = findDominantFrequencies(fft);

    // Store results
    fftResults[token] = {
      dominantFrequencies,
      periodicity: calculatePeriodicity(dominantFrequencies),
      strength: calculateSignalStrength(fft)
    };
  }

  // Find correlations between token frequencies
  const correlations = findTokenFrequencyCorrelations(fftResults);

  return {
    fftResults,
    correlations
  };
}
```

### 4. Zero-Knowledge Reports

```javascript
// Server-side
async function generateZeroKnowledgeReport(tenantId, timeRange) {
  // Generate report with token patterns and frequencies
  // without knowing what the tokens represent

  const patterns = await detectPatterns(tenantId, timeRange);
  const anomalies = await detectAnomalies(tenantId, timeRange);
  const fftAnalysis = await performFFTAnalysis(tenantId, timeRange);
  const volumeMetrics = await getVolumeMetrics(tenantId, timeRange);

  return {
    patterns,
    anomalies,
    fftAnalysis,
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
