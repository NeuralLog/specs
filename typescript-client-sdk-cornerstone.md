# TypeScript Client SDK: The Cornerstone of NeuralLog's Zero-Knowledge Architecture

## Overview

The TypeScript Client SDK is the cornerstone of NeuralLog's zero-knowledge architecture. This document explains how the SDK implements the zero-knowledge principles and why it's the foundation of NeuralLog's security model.

## Core Principles

1. **Client-Side Cryptography**: All cryptographic operations happen exclusively on the client
2. **Zero Server Knowledge**: The server never possesses encryption keys or plaintext data
3. **End-to-End Encryption**: Data is encrypted before transmission and only decrypted by authorized clients
4. **Deterministic Key Derivation**: All encryption keys are derived from a master secret or API keys
5. **Searchable Encryption**: Search capabilities without compromising the zero-knowledge model

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  TypeScript Client SDK                      │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Key         │  │ Crypto      │  │ Auth                │  │
│  │ Hierarchy   │  │ Service     │  │ Service             │  │
│  │             │  │             │  │                     │  │
│  │ • Derive    │  │ • Encrypt   │  │ • Authenticate      │  │
│  │   Keys      │  │ • Decrypt   │  │ • Get Tokens        │  │
│  │ • Manage    │  │ • Generate  │  │ • Verify            │  │
│  │   Hierarchy │  │   Tokens    │  │   Tokens            │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Logs        │  │ Search      │  │ API                 │  │
│  │ Service     │  │ Service     │  │ Client              │  │
│  │             │  │             │  │                     │  │
│  │ • Store     │  │ • Generate  │  │ • Make HTTP         │  │
│  │   Logs      │  │   Tokens    │  │   Requests          │  │
│  │ • Retrieve  │  │ • Search    │  │ • Handle            │  │
│  │   Logs      │  │   Logs      │  │   Responses         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Key Hierarchy Manager

The Key Hierarchy Manager manages the deterministic derivation of encryption keys and KEK versioning:

```typescript
class KeyHierarchyManager {
  // Initialize the key hierarchy with a recovery phrase
  async initializeWithRecoveryPhrase(recoveryPhrase: string, versions?: string[]): Promise<void>;

  // Initialize the key hierarchy with a mnemonic
  async initializeWithMnemonic(mnemonic: string, versions?: string[]): Promise<void>;

  // Initialize the key hierarchy with KEK blobs
  async initializeWithKEKBlobs(kekBlobs: any[]): Promise<void>;

  // Create a new KEK version
  async createKEKVersion(reason: string, authToken: string): Promise<KEKVersion>;

  // Rotate KEK
  async rotateKEK(reason: string, removedUsers: string[], authToken: string): Promise<KEKVersion>;

  // Provision KEK for a user
  async provisionKEKForUser(userId: string, kekVersionId: string, authToken: string): Promise<void>;
```

### 2. Crypto Service

The Crypto Service handles all encryption and decryption operations and key derivation:

```typescript
class CryptoService {
  // Initialize the key hierarchy
  async initializeKeyHierarchy(tenantId: string, recoveryPhrase: string, versions?: string[]): Promise<void>;

  // Derive master secret from tenant ID and recovery phrase
  async deriveMasterSecret(tenantId: string, recoveryPhrase: string): Promise<Uint8Array>;

  // Derive master KEK from master secret
  async deriveMasterKEK(masterSecret: Uint8Array): Promise<Uint8Array>;

  // Derive operational KEK for a specific version
  async deriveOperationalKEK(version: string): Promise<Uint8Array>;

  // Encrypt log name
  async encryptLogName(logName: string, kekVersion?: string): Promise<string>;

  // Decrypt log name
  async decryptLogName(encryptedLogName: string): Promise<string>;

  // Encrypt log data
  async encryptLogData(data: any, kekVersion?: string): Promise<Record<string, any>>;

  // Decrypt log data
  async decryptLogData(encryptedData: Record<string, any>): Promise<any>;

  // Derive log key
  async deriveLogKey(kekVersion?: string): Promise<Uint8Array>;

  // Derive search key
  async deriveSearchKey(kekVersion?: string): Promise<Uint8Array>;

  // Generate search tokens
  async generateSearchTokens(data: any, searchKey: Uint8Array, kekVersion?: string): Promise<string[]>;

  // Get current KEK version
  getCurrentKEKVersion(): string;

  // Set current KEK version
  setCurrentKEKVersion(version: string): void;

  // Get operational KEK for a specific version
  getOperationalKEK(version: string): Uint8Array | undefined;

  // Set operational KEK for a specific version
  setOperationalKEK(version: string, key: Uint8Array): void;

  // Get all operational KEKs
  getOperationalKEKs(): Map<string, Uint8Array>;
```

### 3. Auth Service

The Auth Service handles authentication and token management:

```typescript
class AuthService {
  // Authenticate with username and password
  async authenticateWithPassword(username: string, password: string): Promise<AuthResponse>;

  // Authenticate with API key
  async authenticateWithApiKey(apiKey: string): Promise<AuthResponse>;

  // Get resource token for accessing specific resources
  async getResourceToken(resource: string, authToken: string): Promise<string>;

  // Get auth credential
  getAuthCredential(): string;

  // Set auth credential
  setAuthCredential(credential: string): void;

  // Check if authenticated
  isAuthenticated(): boolean;

  // Logout
  logout(): void;
}
```

### 4. Logs Service

The Logs Service handles log storage and retrieval:

```typescript
class LogsService {
  // Append encrypted log to the server
  async appendLog(logName: string, encryptedData: Record<string, any>, resourceToken: string, searchTokens?: string[]): Promise<string>;

  // Get encrypted logs from the server
  async getLogs(logName: string, limit: number, resourceToken: string): Promise<any[]>;

  // Search logs using tokens
  async searchLogs(logName: string, searchTokens: any[], resourceToken: string): Promise<any[]>;

  // Delete log from the server
  async deleteLog(logId: string, logName: string, resourceToken: string): Promise<void>;
}
```

### 5. KEK Service

The KEK Service handles KEK version management and KEK blob operations:

```typescript
class KekService {
  // Get all KEK versions
  async getKEKVersions(authToken: string): Promise<KEKVersion[]>;

  // Get active KEK version
  async getActiveKEKVersion(authToken: string): Promise<KEKVersion | null>;

  // Create a new KEK version
  async createKEKVersion(reason: string, authToken: string): Promise<KEKVersion>;

  // Rotate KEK
  async rotateKEK(reason: string, removedUsers: string[], authToken: string): Promise<KEKVersion>;

  // Update KEK version status
  async updateKEKVersionStatus(versionId: string, status: string, authToken: string): Promise<KEKVersion>;

  // Check if KEK version is active
  async isKEKVersionActive(versionId: string, authToken: string): Promise<boolean>;

  // Get KEK blob
  async getKEKBlob(userId: string, versionId: string, authToken: string): Promise<any>;

  // Get all KEK blobs for a user
  async getUserKEKBlobs(authToken: string): Promise<any[]>;

  // Provision KEK blob
  async provisionKEKBlob(userId: string, versionId: string, encryptedBlob: string, authToken: string): Promise<void>;

  // Delete KEK blob
  async deleteKEKBlob(userId: string, versionId: string, authToken: string): Promise<void>;
}
```

## Zero-Knowledge Implementation

### Authentication Flow

1. **Password-Based Authentication**:
   - The client authenticates with username and password
   - The server verifies credentials and returns a JWT token
   - The client stores the JWT token for subsequent requests

2. **Recovery Phrase Initialization**:
   - The client derives a master secret from tenant ID and recovery phrase
   - The master secret is used to derive the master KEK
   - The master KEK is used to derive operational KEKs for each KEK version
   - All derivation happens client-side, no secrets are sent to the server

3. **KEK Blob Initialization**:
   - The client retrieves encrypted KEK blobs from the server
   - The client decrypts the KEK blobs to get operational KEKs
   - The operational KEKs are used to derive log keys

### Log Encryption Flow

1. **Log Creation**:
   - The client encrypts the log name using a key derived from the operational KEK
   - The client encrypts the log data using a key derived from the operational KEK
   - The client includes the KEK version with the encrypted data
   - The client generates search tokens for searchable encryption
   - Only encrypted data, KEK version, and search tokens are sent to the server
   - The server stores the encrypted data without being able to decrypt it

2. **Log Retrieval**:
   - The client encrypts the log name to query the server
   - The client requests encrypted logs from the server
   - The client identifies the KEK version used for each log
   - The client uses the appropriate operational KEK to derive the log key
   - The client decrypts the logs locally
   - The server never sees the plaintext logs

### Search Flow

1. **Search Query**:
   - The client encrypts the log name to query the server
   - The client generates search tokens for each KEK version
   - Only search tokens are sent to the server
   - The server matches tokens against stored tokens
   - The server returns matching encrypted logs
   - The client identifies the KEK version used for each log
   - The client uses the appropriate operational KEK to derive the log key
   - The client decrypts the logs locally

## Security Guarantees

The TypeScript Client SDK provides several critical security guarantees:

1. **Breach Immunity**: Even if the entire server infrastructure is compromised, attackers cannot access plaintext logs without recovery phrases or KEK blobs.

2. **No Trust Required**: Users don't need to trust the service provider with their sensitive data.

3. **Cryptographic Isolation**: Each tenant's data is encrypted with different keys, providing strong isolation.

4. **Key Rotation**: KEK versioning allows for secure key rotation without re-encrypting existing data.

5. **Access Control**: Users can be granted or denied access to specific KEK versions, providing fine-grained access control.

6. **Forward Secrecy**: New KEK versions can be created that are not derivable from old versions, providing forward secrecy.

7. **Verifiable Security**: The client-side nature of the SDK allows for independent security verification.

## Implementation Guidelines

1. **TypeScript First**: Implement all cryptographic operations in TypeScript first, then port to other languages.

2. **Standard Libraries**: Use well-vetted cryptographic libraries like Web Crypto API.

3. **No Custom Crypto**: Avoid implementing custom cryptographic algorithms.

4. **Comprehensive Testing**: Implement thorough testing of all cryptographic operations.

5. **Regular Audits**: Conduct regular security audits of the SDK.

6. **Clear Documentation**: Provide clear documentation of the security model.

7. **Secure Defaults**: Provide secure default configurations.

## Conclusion

The TypeScript Client SDK is the cornerstone of NeuralLog's zero-knowledge architecture. By implementing all cryptographic operations client-side, it ensures that sensitive data never leaves the client unencrypted. This approach provides unprecedented security and privacy while still enabling powerful features like searchable encryption.

All other components of the NeuralLog system are built around this cornerstone, ensuring a consistent and secure zero-knowledge architecture throughout the platform.
