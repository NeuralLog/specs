# NeuralLog

NeuralLog is a distributed system designed for logging and monitoring AI model interactions.

## Components

NeuralLog consists of several independent components:

- **typescript-client-sdk**: The cornerstone of NeuralLog's zero-knowledge architecture, handling all client-side encryption, decryption, and key management
- **server**: The logs server implementation for storing encrypted logs
- **web**: The web application frontend that uses the client SDK for all cryptographic operations
- **auth**: The authentication and authorization service
- **shared**: Common types and utilities
- **typescript**: TypeScript SDK for client applications, built on the client SDK
- **specs**: Project specifications and GitHub issues
- **docs**: Project documentation
- **infra**: Infrastructure configuration

See [TypeScript Client SDK: The Cornerstone of NeuralLog's Zero-Knowledge Architecture](typescript-client-sdk-cornerstone.md) for details on how the client SDK implements the zero-knowledge architecture.

## Getting Started

### Prerequisites

- Node.js 22 or later
- Docker and Docker Compose
- Git
- PowerShell

### Setup

1. Clone the repositories:

```powershell
git clone https://github.com/yourusername/neurallog-server.git server
git clone https://github.com/yourusername/neurallog-web.git web
git clone https://github.com/yourusername/neurallog-auth.git auth
git clone https://github.com/yourusername/neurallog-shared.git shared
git clone https://github.com/yourusername/neurallog-typescript.git typescript
git clone https://github.com/yourusername/neurallog-specs.git specs
git clone https://github.com/yourusername/neurallog-docs.git docs
git clone https://github.com/yourusername/neurallog-infra.git infra
```

2. Start the infrastructure components:

```powershell
cd infra
./scripts/Start-All.ps1
```

3. Run the web application locally:

```powershell
cd web
npm install
npx next dev
```

## Utility Scripts

NeuralLog includes several utility scripts in the `infra/scripts` directory to help manage the repositories:

- **Repo-Status.ps1**: Check the status of all repositories
- **Pull-All.ps1**: Pull the latest changes for all repositories
- **Push-All.ps1**: Commit and push changes for all repositories
- **Publish-Shared.ps1**: Build and publish the shared package
- **Update-Shared.ps1**: Update the shared package in all repositories
- **Publish-SDK.ps1**: Build and publish the TypeScript SDK
- **Start-All.ps1**: Start all components using Docker
- **Stop-All.ps1**: Stop all components

## Zero-Knowledge Client SDK

NeuralLog's TypeScript Client SDK is the cornerstone of our zero-knowledge architecture. It handles all encryption, decryption, and key management client-side, ensuring that sensitive data never leaves the client unencrypted.

To install the SDK:

```powershell
# Configure npm to use the private registry for @neurallog scope
npm config set @neurallog:registry http://localhost:4873

# Install the client SDK
npm install @neurallog/client-sdk --registry http://localhost:4873
```

Basic usage:

```typescript
import { NeuralLogClient } from '@neurallog/client-sdk';

// Create a client
const client = new NeuralLogClient({
  tenantId: 'your-tenant-id'
});

// Authenticate
await client.authenticateWithApiKey('your-api-key');

// Log encrypted data
await client.log('application-logs', {
  level: 'info',
  message: 'Hello, world!',
  timestamp: new Date().toISOString(),
  metadata: { user: 'user123' }
});

// Retrieve and decrypt logs
const logs = await client.getLogs('application-logs');
console.log(logs);
```

For more information, see the [TypeScript Client SDK documentation](typescript-client-sdk-cornerstone.md).

## Documentation

The documentation is available in the `docs` directory. To run the documentation site locally:

```powershell
cd docs/NeuralLog\ Docs
npm install
npm start
```

## License

ISC
