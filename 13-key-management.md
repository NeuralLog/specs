# NeuralLog: Zero-Knowledge Key Management

## Overview

NeuralLog implements a deterministic hierarchical key management system that enables powerful security features while maintaining zero server knowledge. This specification details how keys are generated, managed, and used throughout the system.

## Core Principles

1. **Zero Server Knowledge**: The server never possesses encryption keys or plaintext
2. **Deterministic Key Hierarchy**: All keys derived from a master secret using deterministic paths
3. **Client-Side Cryptography**: All cryptographic operations happen client-side
4. **Metadata-Only Server**: Server stores only verification hashes and metadata
5. **Immediate Revocation**: Keys can be revoked instantly through metadata updates

## Deterministic Hierarchical Key Derivation (DHKD)

### Key Hierarchy

The system uses a structured path hierarchy:

```
master_secret
├── tenant/{tenantId}/encryption
│   └── Used for encrypting tenant-wide data
├── tenant/{tenantId}/search
│   └── Used for generating search tokens
├── tenant/{tenantId}/user/{userId}/api-key
│   └── Used for generating API keys
├── tenant/{tenantId}/user/{userId}/auth
│   └── Used for user authentication
├── tenant/{tenantId}/log/{logId}/encryption
│   └── Used for encrypting log entries
└── tenant/{tenantId}/log/{logId}/search
    └── Used for generating log-specific search tokens
```

### Key Derivation Function

Keys are derived using HKDF (HMAC-based Key Derivation Function):

```javascript
async function deriveKey(masterSecret, path) {
  // Convert master secret to a seed
  const seed = await crypto.subtle.importKey(
    "raw",
    masterSecret,
    { name: "HKDF" },
    false,
    ["deriveBits"]
  );

  // Derive key using HKDF
  return crypto.subtle.deriveBits(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: new TextEncoder().encode(path),
      info: new TextEncoder().encode("neurallog-key")
    },
    seed,
    256
  );
}
```

## Master Secret Management

The master secret can be managed in several ways:

### 1. Password-Based

For individual users or small teams:
- Master secret derived from a strong password
- Can be regenerated anytime with the same password
- Suitable for development environments

### 2. M-of-N Secret Sharing

For organizations with multiple administrators:
- Master secret split using Shamir's Secret Sharing
- Requires M of N shares to reconstruct
- Provides redundancy and security
- Suitable for production environments

### 3. Hardware Security Module (HSM)

For enterprise deployments:
- Master secret stored in hardware security modules
- Physical security for the most sensitive key
- Suitable for high-security environments

## API Key Management

### API Key Generation

```javascript
// Client-side
async function generateApiKey(name, userId, tenantId, masterSecret) {
  // Generate a unique key ID
  const keyId = generateId();

  // Derive the API key from the master secret
  const keyHierarchy = new KeyHierarchy(masterSecret);
  const apiKey = await keyHierarchy.deriveKey(
    `tenant/${tenantId}/user/${userId}/api-key/${keyId}`
  );

  // Generate verification hash
  const apiKeyVerification = await generateVerificationHash(apiKey);

  // Send only verification hash to server
  await fetch(`/api/apikeys`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'X-Tenant-ID': tenantId
    },
    body: JSON.stringify({
      name,
      keyId,
      verification: apiKeyVerification,
      userId
    })
  });

  return { apiKey, keyId };
}
```

### API Key Verification

```javascript
// Client-side
function generateApiKeyVerification(apiKey) {
  // Use Argon2id with high work factor
  return argon2.hash({
    pass: apiKey,
    salt: generateRandomSalt(),
    type: argon2.ArgonType.Argon2id,
    time: 3,
    mem: 4096,
    hashLen: 32
  });
}

// Server-side
async function verifyApiKey(providedApiKey, storedVerificationHash) {
  return await argon2.verify({
    pass: providedApiKey,
    hash: storedVerificationHash
  });
}
```

## Key Revocation

Keys are revoked through metadata entries:

```javascript
// Server-side
async function revokeKey(keyPath, revocationMetadata) {
  await redis.set(
    `tenant:${tenantId}:revoked:${keyPath}`,
    JSON.stringify({
      revokedAt: Date.now(),
      revokedBy: revocationMetadata.userId,
      reason: revocationMetadata.reason
    })
  );
}

async function isKeyRevoked(keyPath) {
  return await redis.exists(`tenant:${tenantId}:revoked:${keyPath}`);
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

## Redis Data Structure

The Redis instance for each tenant stores key metadata:

```
tenant:{tenantId}:apikey:{keyId} -> {
  "userId": "user123",
  "verification": "argon2hash",
  "name": "Development Environment",
  "createdAt": 1623456789
}

tenant:{tenantId}:user:{userId}:apikeys -> ["keyId1", "keyId2"]

tenant:{tenantId}:revoked:apikeys -> ["keyId1"]
```

## Key Rotation

Keys can be rotated while maintaining backward compatibility:

### API Key Rotation

1. Generate a new API key using a new key ID
2. Store new verification hash
3. Both old and new keys work during transition period
4. Revoke old key after transition

### Master Secret Rotation

1. Reconstruct current master secret
2. Generate new master secret
3. Re-encrypt critical metadata with new keys
4. Update verification hashes
5. Revoke old master secret

## Security Considerations

1. **Master Secret Protection**: The master secret must be strongly protected
2. **Client Security**: Client-side key derivation requires secure client environments
3. **Verification Strength**: Verification hashes use strong algorithms (Argon2id)
4. **Metadata Protection**: Even metadata should be protected from unauthorized access

## M-of-N Key Sharing for Zero-Knowledge Reports

NeuralLog implements secure m-of-n key sharing for transforming zero-knowledge reports to full knowledge:

```javascript
// Client-side
async function requestReportTransformation(reportId, reason) {
  // Create transformation request
  const response = await fetch(`/api/reports/${reportId}/transform-request`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'X-Tenant-ID': tenantId
    },
    body: JSON.stringify({ reason })
  });

  const { requestId } = await response.json();
  return requestId;
}

// Client-side (approver)
async function approveTransformation(requestId, approverKeyShare) {
  // Submit approver's key share
  await fetch(`/api/transform-requests/${requestId}/approve`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'X-Tenant-ID': tenantId
    },
    body: JSON.stringify({ keyShare: approverKeyShare })
  });
}

// Client-side (requester)
async function getTransformedReport(requestId, reportId) {
  // Check if enough approvals have been collected
  const statusResponse = await fetch(`/api/transform-requests/${requestId}/status`, {
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'X-Tenant-ID': tenantId
    }
  });

  const { status, combinedKeyShares } = await statusResponse.json();

  if (status !== 'approved') {
    throw new Error('Not enough approvals yet');
  }

  // Get the encrypted report
  const reportResponse = await fetch(`/api/reports/${reportId}`, {
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'X-Tenant-ID': tenantId
    }
  });

  const { encryptedReport } = await reportResponse.json();

  // Reconstruct the decryption key from combined shares
  const decryptionKey = reconstructKeyFromShares(combinedKeyShares);

  // Decrypt the report
  return decryptReport(encryptedReport, decryptionKey);
}
```

## Web of Trust for Key Signing

NeuralLog implements a web of trust mechanism for key signing:

```javascript
// Client-side
async function signUserKey(userId, signerPrivateKey) {
  // Get the user's public key
  const response = await fetch(`/api/users/${userId}/public-key`, {
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'X-Tenant-ID': tenantId
    }
  });

  const { publicKey } = await response.json();

  // Sign the user's public key
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signerPrivateKey,
    new TextEncoder().encode(publicKey)
  );

  // Store the signature
  await fetch(`/api/users/${userId}/signatures`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'X-Tenant-ID': tenantId
    },
    body: JSON.stringify({
      signature: arrayBufferToBase64(signature),
      signerId: currentUserId
    })
  });
}
```

## Implementation Guidelines

1. **Use Standard Libraries**: Rely on well-vetted cryptographic libraries
2. **Avoid Custom Crypto**: Don't implement custom cryptographic algorithms
3. **Regular Audits**: Conduct regular security audits of the key management system
4. **Defense in Depth**: Implement multiple layers of security
5. **Secure Defaults**: Provide secure default configurations
6. **Key Rotation**: Implement regular key rotation procedures
7. **Metadata Protection**: Encrypt all sensitive metadata
8. **Revocation Lists**: Maintain efficient revocation lists
9. **Audit Logging**: Log all key management operations
10. **Secure Recovery**: Implement secure key recovery mechanisms
