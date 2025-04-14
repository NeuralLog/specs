# NeuralLog: Zero-Knowledge Key Management

## Overview

NeuralLog implements a deterministic hierarchical key management system that enables powerful security features while maintaining zero server knowledge. This specification details how keys are generated, managed, and used throughout the system.

## The TypeScript Client SDK: Cornerstone of Zero-Knowledge

The TypeScript Client SDK is the cornerstone of NeuralLog's zero-knowledge architecture. It implements all cryptographic operations client-side, ensuring that sensitive data and encryption keys never leave the client. This SDK:

1. Handles all encryption and decryption operations
2. Manages the key hierarchy and derivation
3. Generates search tokens for searchable encryption
4. Implements secure authentication without transmitting passwords
5. Provides the foundation for all other language SDKs

## Core Principles

1. **Zero Server Knowledge**: The server never possesses encryption keys or plaintext
2. **Deterministic Key Hierarchy**: All keys derived from a master secret using deterministic paths
3. **Client-Side Cryptography**: All cryptographic operations happen client-side via the TypeScript Client SDK
4. **Metadata-Only Server**: Server stores only verification hashes and metadata
5. **Immediate Revocation**: Keys can be revoked instantly through metadata updates

## Deterministic Hierarchical Key Derivation (DHKD)

### Key Hierarchy

The system uses a three-tier key hierarchy:

```
Master Secret (derived from tenant ID and recovery phrase)
└── Master KEK (derived from Master Secret)
    └── Operational KEKs (versioned, derived from Master KEK)
        ├── Log Name Keys (derived from Operational KEK)
        │   └── Used for encrypting log names
        ├── Log Encryption Keys (derived from Operational KEK)
        │   └── Used for encrypting log data
        └── Search Keys (derived from Operational KEK)
            └── Used for generating search tokens
```

This hierarchy enables:
1. Secure key rotation through KEK versioning
2. Tenant-wide consistent encryption
3. Secure distribution of keys through encrypted KEK blobs

### Key Derivation Functions

Different key derivation functions are used at each level of the hierarchy:

#### Master Secret Derivation

```javascript
async function deriveMasterSecret(tenantId, recoveryPhrase) {
  // Create salt from tenant ID
  const salt = `NeuralLog-${tenantId}-MasterSecret`;

  // Derive key using PBKDF2
  const passwordBytes = new TextEncoder().encode(recoveryPhrase);
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    passwordBytes,
    { name: 'PBKDF2' },
    false,
    ['deriveBits']
  );

  return crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      salt: new TextEncoder().encode(salt),
      iterations: 100000,
      hash: 'SHA-256'
    },
    keyMaterial,
    256
  );
}
```

#### Master KEK Derivation

```javascript
async function deriveMasterKEK(masterSecret) {
  // Import master secret as key material
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    masterSecret,
    { name: 'HKDF' },
    false,
    ['deriveBits']
  );

  // Derive bits using HKDF
  return crypto.subtle.deriveBits(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new TextEncoder().encode('NeuralLog-MasterKEK'),
      info: new TextEncoder().encode('master-key-encryption-key')
    },
    keyMaterial,
    256
  );
}
```

#### Operational KEK Derivation

```javascript
async function deriveOperationalKEK(masterKEK, version) {
  // Import master KEK as key material
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    masterKEK,
    { name: 'HKDF' },
    false,
    ['deriveBits']
  );

  // Derive bits using HKDF
  return crypto.subtle.deriveBits(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new TextEncoder().encode(`NeuralLog-OpKEK-${version}`),
      info: new TextEncoder().encode('operational-key-encryption-key')
    },
    keyMaterial,
    256
  );
}
```

## Master Secret Management

The master secret can be managed in several ways:

### 1. Recovery Phrase

For individual users or small teams:
- Master secret derived from tenant ID and recovery phrase
- Recovery phrase can be a BIP-39 mnemonic (12-24 words)
- Can be regenerated anytime with the same recovery phrase
- Suitable for development environments

### 2. M-of-N Secret Sharing

For organizations with multiple administrators:
- Master secret split using Shamir's Secret Sharing
- Requires M of N shares to reconstruct
- Provides redundancy and security
- Used for admin promotion and key recovery
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

### KEK Version Storage

```
kek:version:{tenantId}:{versionId} -> {
  "createdAt": "2023-06-01T12:00:00Z",
  "createdBy": "user123",
  "status": "active",  // or "decrypt-only", "deprecated"
  "reason": "Initial setup",
  "tenantId": "tenant456"
}

kek:versions:{tenantId} -> ["versionId1", "versionId2", "versionId3"]
```

### KEK Blob Storage

```
kek:blob:{tenantId}:{userId}:{versionId} -> {
  "encryptedBlob": "base64encodedblob",
  "createdAt": "2023-06-01T12:00:00Z",
  "updatedAt": "2023-06-01T12:00:00Z"
}

kek:blobs:{tenantId}:{userId} -> ["versionId1", "versionId2"]
```

### API Key Storage

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

### KEK Version Rotation

1. Admin creates a new KEK version with status "active"
2. All existing active KEK versions are changed to "decrypt-only"
3. Admin provisions the new KEK version for authorized users
4. New logs are encrypted with the new KEK version
5. Old logs can still be decrypted using the appropriate KEK version

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

1. **TypeScript Client SDK First**: Implement all cryptographic operations in the TypeScript Client SDK first, then port to other languages
2. **Use Standard Libraries**: Rely on well-vetted cryptographic libraries
3. **Avoid Custom Crypto**: Don't implement custom cryptographic algorithms
4. **Client-Side Only**: Ensure all cryptographic operations happen exclusively client-side
5. **Regular Audits**: Conduct regular security audits of the key management system
6. **Defense in Depth**: Implement multiple layers of security
7. **Secure Defaults**: Provide secure default configurations
8. **Key Rotation**: Implement regular key rotation procedures
9. **Metadata Protection**: Encrypt all sensitive metadata
10. **Revocation Lists**: Maintain efficient revocation lists
11. **Audit Logging**: Log all key management operations
12. **Secure Recovery**: Implement secure key recovery mechanisms
13. **SDK Consistency**: Ensure all language SDKs follow the same security principles as the TypeScript Client SDK
