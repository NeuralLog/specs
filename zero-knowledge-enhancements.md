# Zero-Knowledge Enhancements

## Encrypted Log Names

### Problem Statement

In the current implementation, log names are stored and transmitted in plaintext. This means the server knows what logs a user has created, which is a potential privacy leak in an otherwise zero-knowledge system.

### Proposed Solution

Encrypt log names using a key derived from the master key, ensuring that only users with the appropriate keys can determine the actual names of logs.

### Technical Approach

1. **Key Derivation**:
   - Derive a specific key for log name encryption from the master key
   - Use HKDF with a specific info parameter ("log_name_encryption")

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

Encrypt all log metadata using keys derived from the master key, ensuring complete privacy of log information.

### Technical Approach

1. **Metadata Encryption**:
   - Define a structured format for log metadata
   - Encrypt the entire metadata structure using AES-GCM
   - Store only the encrypted blob on the server

2. **Searchable Metadata**:
   - For metadata that needs to be searchable, generate search tokens similar to log content
   - Allow searching by metadata fields without revealing the actual values

### Security Benefits

1. **Complete Metadata Privacy**: No log metadata is visible to the server
2. **Consistent Security Model**: All sensitive information is protected with the same level of security

### Future Considerations

This enhancement will be implemented after the encrypted log names feature is complete and stable.
