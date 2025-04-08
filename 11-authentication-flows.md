# NeuralLog Authentication Flows Specification

## Overview

This specification details the authentication flows supported by NeuralLog. It covers user authentication, service-to-service authentication, and integration with identity providers to ensure secure access to the platform.

## Authentication Methods

NeuralLog supports multiple authentication methods to accommodate different use cases:

1. **Username/Password Authentication**: Traditional authentication with email/password
2. **OAuth 2.0 / OpenID Connect**: Integration with external identity providers
3. **API Key Authentication**: For programmatic access
4. **JWT-based Authentication**: For stateless authentication
5. **Multi-Factor Authentication (MFA)**: Additional security layer

## User Authentication Flows

### 1. Username/Password Authentication

The basic flow for username/password authentication:

```
┌──────────┐      ┌───────────┐      ┌─────────────┐
│  User    │      │  Frontend │      │  Auth       │
│  Browser │      │  App      │      │  Service    │
└────┬─────┘      └─────┬─────┘      └──────┬──────┘
     │                  │                    │
     │  Login Form      │                    │
     │─────────────────>│                    │
     │                  │                    │
     │                  │  Login Request     │
     │                  │  (username/password)
     │                  │───────────────────>│
     │                  │                    │
     │                  │                    │ Validate Credentials
     │                  │                    │ Generate Tokens
     │                  │                    │
     │                  │  Access Token +    │
     │                  │  Refresh Token     │
     │                  │<───────────────────│
     │                  │                    │
     │  Login Success   │                    │
     │  (Store Tokens)  │                    │
     │<─────────────────│                    │
     │                  │                    │
```

#### Implementation Details:

```typescript
// Login request
interface LoginRequest {
  username: string;
  password: string;
  tenantId?: string; // Optional for multi-tenant setup
}

// Login response
interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;
  user: {
    id: string;
    name: string;
    email: string;
    roles: string[];
  };
}

// Server-side password verification
async function verifyPassword(storedHash: string, providedPassword: string): Promise<boolean> {
  // Use Argon2id for password verification
  return await argon2.verify(storedHash, providedPassword);
}
```

### 2. OAuth 2.0 / OpenID Connect

Authentication flow with external identity providers:

```
┌──────────┐      ┌───────────┐      ┌─────────────┐     ┌─────────────┐
│  User    │      │  Frontend │      │  Auth       │     │  Identity   │
│  Browser │      │  App      │      │  Service    │     │  Provider   │
└────┬─────┘      └─────┬─────┘      └──────┬──────┘     └──────┬──────┘
     │                  │                    │                   │
     │  Login with      │                    │                   │
     │  Identity Provider                    │                   │
     │─────────────────>│                    │                   │
     │                  │                    │                   │
     │                  │  Initiate OAuth    │                   │
     │                  │───────────────────>│                   │
     │                  │                    │                   │
     │                  │  Redirect to       │                   │
     │                  │  Identity Provider │                   │
     │<─────────────────│                    │                   │
     │                  │                    │                   │
     │  Redirect to     │                    │                   │
     │  Identity Provider                    │                   │
     │─────────────────────────────────────────────────────────>│
     │                  │                    │                   │
     │  Authentication  │                    │                   │
     │  at IdP          │                    │                   │
     │<─────────────────────────────────────────────────────────│
     │                  │                    │                   │
     │  Redirect with   │                    │                   │
     │  Authorization Code                   │                   │
     │<─────────────────────────────────────────────────────────│
     │                  │                    │                   │
     │  Authorization   │                    │                   │
     │  Code            │                    │                   │
     │─────────────────>│                    │                   │
     │                  │                    │                   │
     │                  │  Exchange Code     │                   │
     │                  │  for Tokens        │                   │
     │                  │───────────────────>│                   │
     │                  │                    │                   │
     │                  │                    │  Verify Code      │
     │                  │                    │─────────────────>│
     │                  │                    │                   │
     │                  │                    │  ID Token +       │
     │                  │                    │  Access Token     │
     │                  │                    │<─────────────────│
     │                  │                    │                   │
     │                  │                    │ Create Session    │
     │                  │                    │ Generate Tokens   │
     │                  │                    │                   │
     │                  │  NeuralLog Tokens  │                   │
     │                  │<───────────────────│                   │
     │                  │                    │                   │
     │  Login Success   │                    │                   │
     │  (Store Tokens)  │                    │                   │
     │<─────────────────│                    │                   │
     │                  │                    │                   │
```

#### Implementation Details:

```typescript
// OAuth configuration
interface OAuthConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  authorizationEndpoint: string;
  tokenEndpoint: string;
  userInfoEndpoint: string;
  scope: string;
  responseType: string;
}

// OAuth providers configuration
const oauthProviders = {
  google: {
    clientId: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    redirectUri: `${process.env.APP_URL}/auth/callback/google`,
    authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
    userInfoEndpoint: 'https://openidconnect.googleapis.com/v1/userinfo',
    scope: 'openid profile email',
    responseType: 'code'
  },
  github: {
    clientId: process.env.GITHUB_CLIENT_ID,
    clientSecret: process.env.GITHUB_CLIENT_SECRET,
    redirectUri: `${process.env.APP_URL}/auth/callback/github`,
    authorizationEndpoint: 'https://github.com/login/oauth/authorize',
    tokenEndpoint: 'https://github.com/login/oauth/access_token',
    userInfoEndpoint: 'https://api.github.com/user',
    scope: 'user:email',
    responseType: 'code'
  }
};
```

### 3. Multi-Factor Authentication (MFA)

Flow for multi-factor authentication:

```
┌──────────┐      ┌───────────┐      ┌─────────────┐
│  User    │      │  Frontend │      │  Auth       │
│  Browser │      │  App      │      │  Service    │
└────┬─────┘      └─────┬─────┘      └──────┬──────┘
     │                  │                    │
     │  Login with      │                    │
     │  Username/Password                    │
     │─────────────────>│                    │
     │                  │                    │
     │                  │  Login Request     │
     │                  │───────────────────>│
     │                  │                    │
     │                  │                    │ Validate Credentials
     │                  │                    │ Check MFA Required
     │                  │                    │
     │                  │  MFA Required      │
     │                  │  (Challenge)       │
     │                  │<───────────────────│
     │                  │                    │
     │  MFA Challenge   │                    │
     │  (TOTP, SMS, etc.)                    │
     │<─────────────────│                    │
     │                  │                    │
     │  MFA Code        │                    │
     │─────────────────>│                    │
     │                  │                    │
     │                  │  Verify MFA Code   │
     │                  │───────────────────>│
     │                  │                    │
     │                  │                    │ Validate MFA Code
     │                  │                    │ Generate Tokens
     │                  │                    │
     │                  │  Access Token +    │
     │                  │  Refresh Token     │
     │                  │<───────────────────│
     │                  │                    │
     │  Login Success   │                    │
     │  (Store Tokens)  │                    │
     │<─────────────────│                    │
     │                  │                    │
```

#### Implementation Details:

```typescript
// MFA methods
enum MFAMethod {
  TOTP = 'totp',
  SMS = 'sms',
  EMAIL = 'email',
  WEBAUTHN = 'webauthn'
}

// MFA challenge response
interface MFAChallenge {
  challengeId: string;
  method: MFAMethod;
  destination?: string; // Masked phone/email for SMS/Email
  expiresAt: string;
}

// MFA verification request
interface MFAVerificationRequest {
  challengeId: string;
  code: string;
}

// TOTP verification
async function verifyTOTP(secret: string, token: string): Promise<boolean> {
  return speakeasy.totp.verify({
    secret,
    encoding: 'base32',
    token,
    window: 1 // Allow 30 seconds before/after
  });
}
```

## API Key Authentication

### 1. API Key Generation

Flow for generating API keys:

```
┌──────────┐      ┌───────────┐      ┌─────────────┐
│  User    │      │  Frontend │      │  Auth       │
│  Browser │      │  App      │      │  Service    │
└────┬─────┘      └─────┬─────┘      └──────┬──────┘
     │                  │                    │
     │  Request New     │                    │
     │  API Key         │                    │
     │─────────────────>│                    │
     │                  │                    │
     │                  │  Generate API Key  │
     │                  │  Request           │
     │                  │───────────────────>│
     │                  │                    │
     │                  │                    │ Authenticate User
     │                  │                    │ Generate API Key
     │                  │                    │ Store Hashed Key
     │                  │                    │
     │                  │  API Key           │
     │                  │  (Only shown once) │
     │                  │<───────────────────│
     │                  │                    │
     │  Display API Key │                    │
     │<─────────────────│                    │
     │                  │                    │
```

#### Implementation Details:

```typescript
// API key generation
async function generateApiKey(userId: string, name: string, permissions: string[]): Promise<string> {
  // Generate a random API key
  const apiKey = crypto.randomBytes(32).toString('hex');
  
  // Hash the API key for storage
  const hashedKey = await bcrypt.hash(apiKey, 10);
  
  // Store the hashed key in the database
  await db.apiKeys.create({
    userId,
    name,
    hashedKey,
    permissions,
    createdAt: new Date(),
    lastUsedAt: null
  });
  
  // Return the original API key (only shown once)
  return apiKey;
}
```

### 2. API Key Authentication

Flow for authenticating with API keys:

```
┌──────────┐                              ┌─────────────┐
│  Client  │                              │  API        │
│  Service │                              │  Gateway    │
└────┬─────┘                              └──────┬──────┘
     │                                           │
     │  API Request                              │
     │  (API Key in Header)                      │
     │───────────────────────────────────────────>
     │                                           │
     │                                           │ Validate API Key
     │                                           │ Check Permissions
     │                                           │
     │  API Response                             │
     │<───────────────────────────────────────────
     │                                           │
```

#### Implementation Details:

```typescript
// API key authentication middleware
async function authenticateApiKey(req, res, next) {
  // Get API key from header
  const apiKey = req.headers['x-api-key'];
  
  if (!apiKey) {
    return res.status(401).json({ error: 'API key required' });
  }
  
  try {
    // Find API key in database
    const apiKeyRecord = await db.apiKeys.findAll();
    
    // Check if API key exists and is valid
    const validKey = apiKeyRecord.find(record => 
      bcrypt.compareSync(apiKey, record.hashedKey)
    );
    
    if (!validKey) {
      return res.status(401).json({ error: 'Invalid API key' });
    }
    
    // Check if API key is not expired
    if (validKey.expiresAt && new Date(validKey.expiresAt) < new Date()) {
      return res.status(401).json({ error: 'Expired API key' });
    }
    
    // Update last used timestamp
    await db.apiKeys.update(
      { lastUsedAt: new Date() },
      { where: { id: validKey.id } }
    );
    
    // Set user and permissions context
    req.user = {
      id: validKey.userId,
      type: 'api',
      permissions: validKey.permissions
    };
    
    next();
  } catch (error) {
    console.error('API key authentication error:', error);
    return res.status(500).json({ error: 'Authentication error' });
  }
}
```

## JWT-based Authentication

### 1. JWT Structure

NeuralLog uses JWTs with the following structure:

```json
// JWT Header
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "key-id-1"
}

// JWT Payload
{
  "iss": "https://auth.neurallog.com",
  "sub": "user-123",
  "aud": "https://api.neurallog.com",
  "iat": 1617230400,
  "exp": 1617234000,
  "jti": "jwt-id-456",
  "tenant_id": "tenant-789",
  "org_id": "org-012",
  "roles": ["admin", "developer"],
  "permissions": ["logs:read", "logs:write", "rules:read"],
  "session_id": "session-345"
}
```

### 2. Token Issuance

Flow for issuing JWT tokens:

```typescript
// Token generation
async function generateTokens(user: User, sessionId: string): Promise<TokenPair> {
  // Access token payload
  const accessTokenPayload = {
    iss: config.jwt.issuer,
    sub: user.id,
    aud: config.jwt.audience,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + config.jwt.accessTokenTTL,
    jti: uuidv4(),
    tenant_id: user.tenantId,
    org_id: user.orgId,
    roles: user.roles,
    permissions: user.permissions,
    session_id: sessionId
  };
  
  // Refresh token payload
  const refreshTokenPayload = {
    iss: config.jwt.issuer,
    sub: user.id,
    aud: config.jwt.audience,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + config.jwt.refreshTokenTTL,
    jti: uuidv4(),
    tenant_id: user.tenantId,
    org_id: user.orgId,
    session_id: sessionId,
    token_type: 'refresh'
  };
  
  // Sign tokens
  const accessToken = jwt.sign(
    accessTokenPayload,
    config.jwt.privateKey,
    { algorithm: 'RS256', keyid: config.jwt.keyId }
  );
  
  const refreshToken = jwt.sign(
    refreshTokenPayload,
    config.jwt.privateKey,
    { algorithm: 'RS256', keyid: config.jwt.keyId }
  );
  
  // Store refresh token hash in database for revocation
  await db.refreshTokens.create({
    id: refreshTokenPayload.jti,
    userId: user.id,
    hashedToken: await bcrypt.hash(refreshToken, 10),
    expiresAt: new Date(refreshTokenPayload.exp * 1000),
    sessionId
  });
  
  return {
    accessToken,
    refreshToken,
    expiresIn: config.jwt.accessTokenTTL,
    tokenType: 'Bearer'
  };
}
```

### 3. Token Validation

Flow for validating JWT tokens:

```typescript
// Token validation
async function validateToken(token: string): Promise<DecodedToken> {
  try {
    // Verify token signature and expiration
    const decoded = jwt.verify(token, config.jwt.publicKey, {
      algorithms: ['RS256'],
      issuer: config.jwt.issuer,
      audience: config.jwt.audience
    });
    
    // Check if token is in blacklist (for revoked tokens)
    const isBlacklisted = await tokenBlacklist.check(decoded.jti);
    if (isBlacklisted) {
      throw new Error('Token has been revoked');
    }
    
    return decoded;
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new AuthError('Token has expired', 'token_expired');
    } else if (error.name === 'JsonWebTokenError') {
      throw new AuthError('Invalid token', 'invalid_token');
    } else {
      throw new AuthError(`Token validation error: ${error.message}`, 'token_validation_error');
    }
  }
}
```

### 4. Token Refresh

Flow for refreshing JWT tokens:

```
┌──────────┐      ┌───────────┐      ┌─────────────┐
│  Client  │      │  Frontend │      │  Auth       │
│          │      │  App      │      │  Service    │
└────┬─────┘      └─────┬─────┘      └──────┬──────┘
     │                  │                    │
     │  Access Token    │                    │
     │  Expired         │                    │
     │                  │                    │
     │  Refresh Token   │                    │
     │  Request         │                    │
     │─────────────────>│                    │
     │                  │                    │
     │                  │  Refresh Token     │
     │                  │  Request           │
     │                  │───────────────────>│
     │                  │                    │
     │                  │                    │ Validate Refresh Token
     │                  │                    │ Generate New Tokens
     │                  │                    │ Invalidate Old Refresh Token
     │                  │                    │
     │                  │  New Access Token +│
     │                  │  New Refresh Token │
     │                  │<───────────────────│
     │                  │                    │
     │  New Tokens      │                    │
     │<─────────────────│                    │
     │                  │                    │
```

#### Implementation Details:

```typescript
// Token refresh
async function refreshTokens(refreshToken: string): Promise<TokenPair> {
  try {
    // Verify refresh token
    const decoded = jwt.verify(refreshToken, config.jwt.publicKey, {
      algorithms: ['RS256'],
      issuer: config.jwt.issuer,
      audience: config.jwt.audience
    });
    
    // Check if token is a refresh token
    if (decoded.token_type !== 'refresh') {
      throw new Error('Invalid token type');
    }
    
    // Find refresh token in database
    const storedToken = await db.refreshTokens.findOne({
      where: { id: decoded.jti }
    });
    
    if (!storedToken) {
      throw new Error('Refresh token not found');
    }
    
    // Verify token hasn't been used (prevent replay attacks)
    if (storedToken.used) {
      // Potential token reuse - invalidate all user sessions
      await invalidateUserSessions(decoded.sub);
      throw new Error('Refresh token reuse detected');
    }
    
    // Mark token as used
    await db.refreshTokens.update(
      { used: true },
      { where: { id: decoded.jti } }
    );
    
    // Get user
    const user = await db.users.findOne({
      where: { id: decoded.sub }
    });
    
    if (!user) {
      throw new Error('User not found');
    }
    
    // Generate new token pair
    return await generateTokens(user, decoded.session_id);
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new AuthError('Refresh token has expired', 'token_expired');
    } else {
      throw new AuthError(`Token refresh error: ${error.message}`, 'token_refresh_error');
    }
  }
}
```

### 5. Token Revocation

Flow for revoking JWT tokens:

```typescript
// Token revocation
async function revokeToken(token: string, type: 'access' | 'refresh'): Promise<void> {
  try {
    // Verify token without checking expiration
    const decoded = jwt.verify(token, config.jwt.publicKey, {
      algorithms: ['RS256'],
      issuer: config.jwt.issuer,
      audience: config.jwt.audience,
      ignoreExpiration: true
    });
    
    if (type === 'refresh') {
      // Delete refresh token from database
      await db.refreshTokens.destroy({
        where: { id: decoded.jti }
      });
    } else {
      // Add access token to blacklist until expiration
      const ttl = decoded.exp - Math.floor(Date.now() / 1000);
      if (ttl > 0) {
        await tokenBlacklist.add(decoded.jti, ttl);
      }
    }
    
    // Optionally invalidate the entire session
    if (decoded.session_id) {
      await db.sessions.update(
        { active: false },
        { where: { id: decoded.session_id } }
      );
    }
  } catch (error) {
    throw new AuthError(`Token revocation error: ${error.message}`, 'token_revocation_error');
  }
}
```

## Session Management

### 1. Session Creation

Flow for creating user sessions:

```typescript
// Session creation
async function createSession(userId: string, metadata: SessionMetadata): Promise<Session> {
  const session = await db.sessions.create({
    id: uuidv4(),
    userId,
    active: true,
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + config.session.maxAge),
    lastActivityAt: new Date(),
    ipAddress: metadata.ipAddress,
    userAgent: metadata.userAgent,
    device: metadata.device,
    location: metadata.location
  });
  
  return session;
}
```

### 2. Session Validation

Flow for validating user sessions:

```typescript
// Session validation
async function validateSession(sessionId: string): Promise<Session> {
  const session = await db.sessions.findOne({
    where: { id: sessionId }
  });
  
  if (!session) {
    throw new AuthError('Session not found', 'session_not_found');
  }
  
  if (!session.active) {
    throw new AuthError('Session is inactive', 'session_inactive');
  }
  
  if (session.expiresAt < new Date()) {
    // Update session status
    await db.sessions.update(
      { active: false },
      { where: { id: sessionId } }
    );
    throw new AuthError('Session has expired', 'session_expired');
  }
  
  // Update last activity
  await db.sessions.update(
    { lastActivityAt: new Date() },
    { where: { id: sessionId } }
  );
  
  return session;
}
```

### 3. Session Termination

Flow for terminating user sessions:

```typescript
// Session termination
async function terminateSession(sessionId: string): Promise<void> {
  await db.sessions.update(
    { active: false },
    { where: { id: sessionId } }
  );
  
  // Revoke all tokens associated with this session
  const refreshTokens = await db.refreshTokens.findAll({
    where: { sessionId }
  });
  
  for (const token of refreshTokens) {
    await db.refreshTokens.update(
      { used: true },
      { where: { id: token.id } }
    );
  }
}
```

## Integration with Identity Providers

### 1. Auth0 Integration

Configuration for Auth0 integration:

```typescript
// Auth0 configuration
const auth0Config = {
  domain: process.env.AUTH0_DOMAIN,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  callbackUrl: `${process.env.APP_URL}/auth/callback/auth0`,
  audience: process.env.AUTH0_AUDIENCE,
  scope: 'openid profile email'
};

// Auth0 user profile mapping
function mapAuth0UserToNeuralLogUser(auth0User: Auth0User): UserProfile {
  return {
    id: auth0User.sub,
    email: auth0User.email,
    name: auth0User.name,
    picture: auth0User.picture,
    emailVerified: auth0User.email_verified,
    metadata: {
      auth0Id: auth0User.sub,
      lastLogin: auth0User.updated_at
    }
  };
}
```

### 2. Okta Integration

Configuration for Okta integration:

```typescript
// Okta configuration
const oktaConfig = {
  orgUrl: process.env.OKTA_ORG_URL,
  clientId: process.env.OKTA_CLIENT_ID,
  clientSecret: process.env.OKTA_CLIENT_SECRET,
  callbackUrl: `${process.env.APP_URL}/auth/callback/okta`,
  scope: 'openid profile email'
};

// Okta user profile mapping
function mapOktaUserToNeuralLogUser(oktaUser: OktaUser): UserProfile {
  return {
    id: oktaUser.sub,
    email: oktaUser.email,
    name: `${oktaUser.given_name} ${oktaUser.family_name}`,
    picture: oktaUser.picture,
    emailVerified: oktaUser.email_verified,
    metadata: {
      oktaId: oktaUser.sub,
      groups: oktaUser.groups
    }
  };
}
```

### 3. SAML Integration

Configuration for SAML integration:

```typescript
// SAML configuration
const samlConfig = {
  entryPoint: process.env.SAML_ENTRY_POINT,
  issuer: process.env.SAML_ISSUER,
  cert: process.env.SAML_CERT,
  callbackUrl: `${process.env.APP_URL}/auth/callback/saml`,
  signatureAlgorithm: 'sha256',
  digestAlgorithm: 'sha256'
};

// SAML user profile mapping
function mapSamlUserToNeuralLogUser(samlUser: SAMLUser): UserProfile {
  return {
    id: samlUser.nameID,
    email: samlUser.email,
    name: samlUser.displayName || `${samlUser.firstName} ${samlUser.lastName}`,
    emailVerified: true, // Typically assumed verified from enterprise IdP
    metadata: {
      samlNameID: samlUser.nameID,
      groups: samlUser['http://schemas.xmlsoap.org/claims/Group'],
      roles: samlUser['http://schemas.microsoft.com/ws/2008/06/identity/claims/role']
    }
  };
}
```

## Security Considerations

### 1. Token Security

Best practices for token security:

- **Short-lived Access Tokens**: Access tokens should have a short lifetime (15-60 minutes)
- **Secure Storage**: Store tokens securely (HttpOnly cookies, secure storage)
- **HTTPS Only**: Transmit tokens only over HTTPS
- **Token Revocation**: Support for immediate token revocation
- **Signature Verification**: Always verify token signatures
- **Audience Validation**: Validate the token audience
- **Issuer Validation**: Validate the token issuer

### 2. Password Security

Best practices for password security:

- **Strong Hashing**: Use Argon2id for password hashing
- **Password Policies**: Enforce strong password policies
- **Breached Password Check**: Check against known breached passwords
- **Rate Limiting**: Implement rate limiting for login attempts
- **Account Lockout**: Temporary account lockout after failed attempts
- **Secure Reset**: Secure password reset process

### 3. MFA Security

Best practices for MFA security:

- **Multiple Methods**: Support multiple MFA methods
- **Secure Enrollment**: Secure MFA enrollment process
- **Backup Codes**: Provide backup codes for recovery
- **Rate Limiting**: Implement rate limiting for MFA attempts
- **Time-Limited Codes**: Short validity period for codes
- **Secure Delivery**: Secure delivery of MFA codes

## Implementation Guidelines

### 1. Authentication Service Implementation

Guidelines for implementing the authentication service:

- **Stateless Design**: Design for stateless operation
- **Microservice Architecture**: Separate authentication service
- **Caching**: Implement caching for performance
- **High Availability**: Design for high availability
- **Monitoring**: Comprehensive monitoring and alerting
- **Audit Logging**: Detailed audit logging

### 2. Client-Side Implementation

Guidelines for client-side authentication:

- **Token Management**: Secure token storage and management
- **Automatic Refresh**: Transparent token refresh
- **Logout Handling**: Proper logout procedure
- **Error Handling**: Graceful error handling
- **Session Expiry**: Clear UI for session expiry
- **Offline Support**: Support for offline authentication
