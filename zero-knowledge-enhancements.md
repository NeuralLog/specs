# Zero-Knowledge Enhancements

## Key Encryption Key (KEK) Versioning

### Problem Statement

The current implementation lacks a mechanism for securely rotating encryption keys without requiring re-encryption of all existing data. Additionally, there's no way to provide fine-grained access control to specific sets of logs based on when they were created.

### Proposed Solution

Implement a KEK versioning system that allows for the creation of new encryption keys without requiring re-encryption of existing data. Each log will be encrypted with a specific KEK version, and users will have access to one or more KEK versions.

### Technical Approach

1. **Three-Tier Key Hierarchy**:
   - **Master Secret**: Derived from tenant ID and recovery phrase, never stored
   - **Master KEK**: Derived from Master Secret, used to encrypt/decrypt Operational KEKs
   - **Operational KEKs**: Versioned keys used for actual data encryption/decryption

2. **KEK Versions**:
   - **Active**: The current version used for encryption and decryption
   - **Decrypt-Only**: A previous version that can be used for decryption but not for encryption
   - **Deprecated**: A version that is no longer used and should be phased out

3. **KEK Blobs**:
   - Encrypted packages containing an Operational KEK
   - Encrypted with user-specific keys
   - Stored on the server for distribution to authorized users

4. **Redis Storage**:
   - Store KEK versions and blobs in Redis for efficient retrieval
   - Use Redis transactions for atomic operations
   - Use Redis sets for efficient indexing

5. **API Changes**:
   - Add endpoints for creating, rotating, and managing KEK versions
   - Add endpoints for provisioning KEK blobs to users
   - Update log encryption/decryption to include KEK version information

### Security Benefits

1. **Secure Key Rotation**: New KEK versions can be created without re-encrypting existing data
2. **Fine-Grained Access Control**: Users can be granted or denied access to specific KEK versions
3. **Forward Secrecy**: New KEK versions can be created that are not derivable from old versions
4. **Backward Compatibility**: Old logs can still be decrypted with the appropriate KEK version

### Implementation Timeline

- Design and specification: 2-3 days
- Core implementation: 5-7 days
- API updates: 2-3 days
- UI integration: 3-4 days
- Testing: 3-4 days
- Documentation: 2 days

Total: Approximately 17-23 days of development work

## Encrypted Log Names

### Problem Statement

In the current implementation, log names are stored and transmitted in plaintext. This means the server knows what logs a user has created, which is a potential privacy leak in an otherwise zero-knowledge system.

### Proposed Solution

Encrypt log names using a key derived from the operational KEK, ensuring that only users with access to the appropriate KEK version can determine the actual names of logs.

### Technical Approach

1. **Key Derivation**:
   - Derive a specific key for log name encryption from the operational KEK
   - Use HKDF with a specific info parameter ("log-names")
   - Include KEK version information with the encrypted log name

2. **Encryption Algorithm**:
   - Use AES-GCM with a 256-bit key and 96-bit random IV
   - Format: Base64(IV || Ciphertext || AuthTag)

3. **API Changes**:
   - All API endpoints that work with log names will accept and return encrypted log names
   - The client-sdk will handle encryption/decryption transparently

4. **Database Changes**:
   - Change `logName` to `encryptedLogName` in the database schema
   - Update indexes and queries to work with encrypted names

5. **Migration**:
   - Provide a client-side migration tool to encrypt existing log names
   - Support both encrypted and unencrypted names during a transition period

### Security Benefits

1. **Complete Metadata Privacy**: The server learns nothing about the purpose or content of logs
2. **Reduced Information Leakage**: Even the number and naming patterns of logs are hidden
3. **Enhanced Zero-Knowledge**: The system becomes truly zero-knowledge for both content and metadata

### Implementation Timeline

- Design and specification: 1-2 days
- Core implementation: 2-3 days
- API updates: 1-2 days
- UI integration: 1-2 days
- Testing: 2-3 days
- Migration tools: 1-2 days
- Documentation: 1 day

Total: Approximately 9-15 days of development work

## Encrypted Log Metadata

### Problem Statement

In addition to log names, other metadata such as creation time, update time, and tags are currently stored in plaintext, potentially revealing sensitive information.

### Proposed Solution

Encrypt all log metadata using keys derived from the operational KEK, ensuring complete privacy of log information. Include KEK version information with the encrypted metadata to support key rotation.

### Technical Approach

1. **Metadata Encryption**:
   - Define a structured format for log metadata
   - Encrypt the entire metadata structure using AES-GCM
   - Include KEK version information with the encrypted metadata
   - Store only the encrypted blob and KEK version on the server

2. **Searchable Metadata**:
   - For metadata that needs to be searchable, generate search tokens similar to log content
   - Allow searching by metadata fields without revealing the actual values

### Security Benefits

1. **Complete Metadata Privacy**: No log metadata is visible to the server
2. **Consistent Security Model**: All sensitive information is protected with the same level of security

### Future Considerations

This enhancement will be implemented after the KEK versioning and encrypted log names features are complete and stable.

## Enhanced Recovery Mechanisms

### Problem Statement

The current implementation lacks robust recovery mechanisms for lost or compromised keys. Additionally, there's no way for administrators to securely share access to tenant-wide keys.

### Proposed Solution

Implement multiple recovery mechanisms including BIP-39 mnemonic phrases and Shamir's Secret Sharing to provide flexibility for different security requirements.

### Technical Approach

1. **BIP-39 Mnemonic Phrases**:
   - Support 12-24 word phrases that are easy to write down and remember
   - Implement verification steps that quiz users on random words before continuing
   - Use separate input boxes with autocomplete for each word

2. **Shamir's Secret Sharing**:
   - Split the master secret into multiple shares
   - Require M of N shares to reconstruct the secret
   - Implement secure channels for admins to exchange shares

3. **Admin Promotion**:
   - Allow existing admins to promote new admins using Shamir's Secret Sharing
   - Implement threshold cryptography where M=1 allows automatic promotion

### Security Benefits

1. **Redundancy**: Prevents loss of access due to a single point of failure
2. **Flexibility**: Supports different security requirements
3. **Secure Sharing**: Allows administrators to securely share access to tenant-wide keys

### Implementation Timeline

- Design and specification: 2-3 days
- Core implementation: 4-5 days
- UI integration: 2-3 days
- Testing: 2-3 days
- Documentation: 1-2 days

Total: Approximately 11-16 days of development work
