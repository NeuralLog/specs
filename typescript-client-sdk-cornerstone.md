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

### 1. Key Hierarchy

The Key Hierarchy component manages the deterministic derivation of encryption keys:

```typescript
class KeyHierarchy {
  // Derive master encryption key from API key
  async deriveMasterEncryptionKey(apiKey: string, tenantId: string): Promise<CryptoKey>;
  
  // Derive log encryption key for a specific log
  async deriveLogEncryptionKey(apiKey: string, tenantId: string, logName: string): Promise<CryptoKey>;
  
  // Derive log search key for a specific log
  async deriveLogSearchKey(apiKey: string, tenantId: string, logName: string): Promise<CryptoKey>;
}
```

### 2. Crypto Service

The Crypto Service handles all encryption and decryption operations:

```typescript
class CryptoService {
  // Encrypt log data using a derived key
  async encryptLogData(data: any, key: CryptoKey): Promise<EncryptedData>;
  
  // Decrypt log data using a derived key
  async decryptLogData(encryptedData: EncryptedData, key: CryptoKey): Promise<any>;
  
  // Generate search tokens for searchable encryption
  async generateSearchTokens(data: string, searchKey: CryptoKey): Promise<string[]>;
  
  // Derive master secret from username and password
  async deriveMasterSecret(username: string, password: string): Promise<ArrayBuffer>;
}
```

### 3. Auth Service

The Auth Service handles authentication and token management:

```typescript
class AuthService {
  // Authenticate with username and password
  async authenticateWithPassword(username: string, password: string): Promise<string>;
  
  // Authenticate with API key
  async authenticateWithApiKey(apiKey: string): Promise<string>;
  
  // Get resource token for accessing specific resources
  async getResourceToken(apiKey: string, tenantId: string, resource: string): Promise<string>;
  
  // Validate password without sending it to the server
  async validatePassword(username: string, verificationHash: string): Promise<boolean>;
}
```

### 4. Logs Service

The Logs Service handles log storage and retrieval:

```typescript
class LogsService {
  // Append encrypted log to the server
  async appendLog(logName: string, encryptedData: any, resourceToken: string, searchTokens?: string[]): Promise<string>;
  
  // Get encrypted logs from the server
  async getLogs(logName: string, resourceToken: string): Promise<EncryptedLog[]>;
  
  // Delete log from the server
  async deleteLog(logName: string, resourceToken: string): Promise<void>;
}
```

### 5. Search Service

The Search Service handles searchable encryption:

```typescript
class SearchService {
  // Generate search tokens for a query
  async generateSearchTokens(query: string, searchKey: CryptoKey): Promise<string[]>;
  
  // Search logs using tokens
  async searchLogs(logName: string, searchTokens: string[], resourceToken: string): Promise<EncryptedLog[]>;
}
```

## Zero-Knowledge Implementation

### Authentication Flow

1. **Password-Based Authentication**:
   - The client derives a master secret from username and password
   - Only a verification hash is sent to the server
   - The server verifies the hash without knowing the password
   - The client receives a JWT token for subsequent requests

2. **API Key Authentication**:
   - API keys contain cryptographic material for deriving encryption keys
   - The server only stores verification hashes of API keys
   - API keys are used to derive log encryption keys client-side

### Log Encryption Flow

1. **Log Creation**:
   - The client encrypts log name and data using derived keys
   - The client generates search tokens for searchable encryption
   - Only encrypted data and search tokens are sent to the server
   - The server stores the encrypted data without knowing its contents

2. **Log Retrieval**:
   - The client requests encrypted logs from the server
   - The client derives the appropriate decryption keys
   - The client decrypts the logs locally
   - The server never sees the plaintext logs

### Search Flow

1. **Search Query**:
   - The client generates search tokens from the query
   - Only search tokens are sent to the server
   - The server matches tokens against stored tokens
   - The server returns matching encrypted logs
   - The client decrypts the logs locally

## Security Guarantees

The TypeScript Client SDK provides several critical security guarantees:

1. **Breach Immunity**: Even if the entire server infrastructure is compromised, attackers cannot access plaintext logs without API keys or master secrets.

2. **No Trust Required**: Users don't need to trust the service provider with their sensitive data.

3. **Cryptographic Isolation**: Each tenant's data is encrypted with different keys, providing strong isolation.

4. **Forward Secrecy**: Key rotation can provide forward secrecy without re-encrypting existing data.

5. **Verifiable Security**: The client-side nature of the SDK allows for independent security verification.

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
