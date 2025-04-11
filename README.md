# NeuralLog

NeuralLog is a distributed system designed for logging and monitoring AI model interactions.

## Components

NeuralLog consists of several independent components:

- **server**: The logs server implementation
- **web**: The web application frontend
- **auth**: The authentication and authorization service
- **shared**: Common types and utilities
- **typescript**: TypeScript SDK for client applications
- **specs**: Project specifications and GitHub issues
- **docs**: Project documentation
- **infra**: Infrastructure configuration

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

## SDK

NeuralLog provides a TypeScript SDK for client applications. To install the SDK:

```powershell
# Configure npm to use the private registry for @neurallog scope
npm config set @neurallog:registry http://localhost:4873

# Install the SDK
npm install @neurallog/sdk --registry http://localhost:4873
```

Basic usage:

```typescript
import { NeuralLog, LogLevel } from '@neurallog/sdk';

// Create a logger
const logger = NeuralLog.Log('my-app');

// Log messages
logger.info('Hello, world!');
logger.error('Something went wrong', { error: 'Error details' });
```

For more information, see the [SDK documentation](docs/NeuralLog%20Docs/docs/components/sdk.md).

## Documentation

The documentation is available in the `docs` directory. To run the documentation site locally:

```powershell
cd docs/NeuralLog\ Docs
npm install
npm start
```

## License

ISC
