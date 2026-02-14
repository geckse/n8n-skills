# Credentials Reference

Complete patterns for all n8n credential types.

## Table of Contents

1. [Credential File Structure](#credential-file-structure)
2. [API Key Authentication](#api-key-authentication)
3. [Bearer Token Authentication](#bearer-token-authentication)
4. [Basic Auth Authentication](#basic-auth-authentication)
5. [OAuth2 Authentication](#oauth2-authentication)
6. [Custom Authentication](#custom-authentication)
7. [Credential Testing](#credential-testing)
8. [Multiple Auth Methods](#multiple-auth-methods)

## Credential File Structure

Every credential file lives in `credentials/<Name>Api.credentials.ts` and exports a class implementing `ICredentialType`.

```typescript
import type {
  IAuthenticateGeneric,
  ICredentialTestRequest,
  ICredentialType,
  INodeProperties,
  Icon,
} from 'n8n-workflow';

export class MyServiceApi implements ICredentialType {
  // Internal name — must match the node's credentials[].name
  name = 'myServiceApi';

  // Display name shown in the credentials UI
  displayName = 'My Service API';

  // URL to the service's API docs (shown as help link)
  documentationUrl = 'https://docs.myservice.com/api';

  // Icon shown in the credentials list (REQUIRED by linter)
  // Place a copy of your SVG icon in the credentials/ folder
  icon: Icon = 'file:myService.svg';

  // User-facing input fields
  properties: INodeProperties[] = [
    {
      displayName: 'API Key',
      name: 'apiKey',
      type: 'string',
      typeOptions: { password: true },
      default: '',
    },
  ];

  // How n8n injects credentials into requests
  authenticate: IAuthenticateGeneric = {
    type: 'generic',
    properties: {
      headers: {
        Authorization: '=Bearer {{$credentials.apiKey}}',
      },
    },
  };

  // Lightweight test request to validate credentials
  test: ICredentialTestRequest = {
    request: {
      baseURL: 'https://api.myservice.com/v1',
      url: '/me',
    },
  };
}
```

## API Key Authentication

### Via Header

```typescript
properties: INodeProperties[] = [
  {
    displayName: 'API Key',
    name: 'apiKey',
    type: 'string',
    typeOptions: { password: true },
    default: '',
  },
];

authenticate: IAuthenticateGeneric = {
  type: 'generic',
  properties: {
    headers: {
      'X-API-Key': '={{$credentials.apiKey}}',
    },
  },
};
```

### Via Query String

```typescript
authenticate: IAuthenticateGeneric = {
  type: 'generic',
  properties: {
    qs: {
      api_key: '={{$credentials.apiKey}}',
    },
  },
};
```

### Via Request Body

```typescript
authenticate: IAuthenticateGeneric = {
  type: 'generic',
  properties: {
    body: {
      apiKey: '={{$credentials.apiKey}}',
    },
  },
};
```

## Bearer Token Authentication

```typescript
properties: INodeProperties[] = [
  {
    displayName: 'Access Token',
    name: 'accessToken',
    type: 'string',
    typeOptions: { password: true },
    default: '',
  },
];

authenticate: IAuthenticateGeneric = {
  type: 'generic',
  properties: {
    headers: {
      Authorization: '=Bearer {{$credentials.accessToken}}',
    },
  },
};
```

## Basic Auth Authentication

```typescript
properties: INodeProperties[] = [
  {
    displayName: 'Username',
    name: 'username',
    type: 'string',
    default: '',
  },
  {
    displayName: 'Password',
    name: 'password',
    type: 'string',
    typeOptions: { password: true },
    default: '',
  },
];

authenticate: IAuthenticateGeneric = {
  type: 'generic',
  properties: {
    auth: {
      username: '={{$credentials.username}}',
      password: '={{$credentials.password}}',
    },
  },
};
```

## OAuth2 Authentication

```typescript
import type {
  ICredentialType,
  INodeProperties,
  Icon,
} from 'n8n-workflow';

export class MyServiceOAuth2Api implements ICredentialType {
  name = 'myServiceOAuth2Api';
  displayName = 'My Service OAuth2 API';
  icon: Icon = 'file:myService.svg';

  // Extend the built-in OAuth2 credential type
  extends = ['oAuth2Api'];

  documentationUrl = 'https://docs.myservice.com/oauth2';

  properties: INodeProperties[] = [
    {
      displayName: 'Grant Type',
      name: 'grantType',
      type: 'hidden',
      default: 'authorizationCode',
    },
    {
      displayName: 'Authorization URL',
      name: 'authUrl',
      type: 'hidden',
      default: 'https://myservice.com/oauth/authorize',
    },
    {
      displayName: 'Access Token URL',
      name: 'accessTokenUrl',
      type: 'hidden',
      default: 'https://myservice.com/oauth/token',
    },
    {
      displayName: 'Scope',
      name: 'scope',
      type: 'hidden',
      default: 'read write',
    },
    {
      displayName: 'Auth URI Query Parameters',
      name: 'authQueryParameters',
      type: 'hidden',
      default: '',
    },
    {
      displayName: 'Authentication',
      name: 'authentication',
      type: 'hidden',
      default: 'header',
    },
  ];
}
```

In the node's credential reference:
```typescript
credentials: [
  {
    name: 'myServiceOAuth2Api',
    required: true,
  },
],
```

## Custom Authentication

For non-standard auth flows where you need full control:

```typescript
import type {
  ICredentialType,
  INodeProperties,
  ICredentialDataDecryptedObject,
  IHttpRequestOptions,
  Icon,
} from 'n8n-workflow';

export class MyServiceApi implements ICredentialType {
  name = 'myServiceApi';
  displayName = 'My Service API';
  icon: Icon = 'file:myService.svg';

  properties: INodeProperties[] = [
    {
      displayName: 'Domain',
      name: 'domain',
      type: 'string',
      default: '',
      placeholder: 'https://yourcompany.myservice.com',
    },
    {
      displayName: 'API Token',
      name: 'apiToken',
      type: 'string',
      typeOptions: { password: true },
      default: '',
    },
  ];

  // Custom authenticate method
  async authenticate(
    credentials: ICredentialDataDecryptedObject,
    requestOptions: IHttpRequestOptions,
  ): Promise<IHttpRequestOptions> {
    requestOptions.headers = requestOptions.headers || {};
    requestOptions.headers['Authorization'] = `Token ${credentials.apiToken}`;
    requestOptions.headers['X-Tenant'] = credentials.domain as string;
    return requestOptions;
  }

  test: ICredentialTestRequest = {
    request: {
      baseURL: '={{$credentials?.domain}}',
      url: '/api/v1/verify',
    },
  };
}
```

## Credential Testing

The `test` property sends a lightweight request to verify credentials work. It runs when the user clicks "Test" in the credentials dialog.

```typescript
// Simple test against a known endpoint:
test: ICredentialTestRequest = {
  request: {
    baseURL: 'https://api.myservice.com/v1',
    url: '/me',
  },
};

// Test with dynamic base URL from credentials:
test: ICredentialTestRequest = {
  request: {
    baseURL: '={{$credentials?.domain}}',
    url: '/api/v1/ping',
  },
};
```

If the request returns a 2xx status, credentials pass. Any error response means failure.

## Multiple Auth Methods

A node can support multiple credential types. Users choose which one to use:

```typescript
// In the node file:
credentials: [
  {
    name: 'myServiceApi',
    required: true,
    displayOptions: {
      show: {
        authentication: ['apiKey'],
      },
    },
  },
  {
    name: 'myServiceOAuth2Api',
    required: true,
    displayOptions: {
      show: {
        authentication: ['oAuth2'],
      },
    },
  },
],
properties: [
  {
    displayName: 'Authentication',
    name: 'authentication',
    type: 'options',
    options: [
      { name: 'API Key', value: 'apiKey' },
      { name: 'OAuth2', value: 'oAuth2' },
    ],
    default: 'apiKey',
  },
  // ... rest of properties
],
```

## Package.json Registration

Credentials must be registered in `package.json` under the `n8n` attribute:

```json
{
  "n8n": {
    "n8nNodesApiVersion": 1,
    "strict": true,
    "credentials": [
      "dist/credentials/MyServiceApi.credentials.js"
    ],
    "nodes": [
      "dist/nodes/MyService/MyService.node.js"
    ]
  }
}
```

Paths point to the compiled JavaScript files in `dist/`, not the TypeScript source.

## Domain/URL Credentials

When the API base URL varies per customer (self-hosted services):

```typescript
properties: INodeProperties[] = [
  {
    displayName: 'Domain',
    name: 'domain',
    type: 'string',
    default: 'https://myinstance.myservice.com',
    placeholder: 'https://your-instance.myservice.com',
  },
  {
    displayName: 'API Key',
    name: 'apiKey',
    type: 'string',
    typeOptions: { password: true },
    default: '',
  },
];
test: ICredentialTestRequest = {
  request: {
    baseURL: '={{$credentials.domain}}',
    url: '/api/v1/me',
  },
};
```

## Custom Credential Test (testedBy)

For complex validation not suited to a simple HTTP request, use `testedBy` instead of the `test` property:

```typescript
// In credential file: (no test property — use testedBy instead)

// In node file, reference it:
credentials: [
  { name: 'myServiceApi', required: true, testedBy: 'myServiceApiTest' },
],

// Also in node file, add test method:
methods = {
  credentialTest: {
    async myServiceApiTest(
      this: ICredentialTestFunctions,
      credential: ICredentialsDecrypted,
    ): Promise<INodeCredentialTestResult> {
      try {
        // Custom validation logic
        return { status: 'OK', message: 'Connection successful' };
      } catch (error) {
        return { status: 'Error', message: error.message };
      }
    },
  },
};
```

## Injection Locations

The `authenticate.properties` object supports these locations:

| Location | Where it's injected | Example |
|----------|-------------------|---------|
| `headers` | HTTP headers | `Authorization: Bearer ...` |
| `qs` | URL query parameters | `?api_key=...` |
| `body` | Request body | `{ "token": "..." }` |
| `auth` | Basic auth (username/password) | `{ username, password }` |

**Expression syntax:** Always use `'={{$credentials.fieldName}}'` to reference credential values. Note the plural `$credentials` — using singular `$credential` is a common mistake.

## Common Credential Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `icon` property on credential | Add `icon: Icon = 'file:myservice.svg'` and place SVG in credentials/ |
| Missing `typeOptions: { password: true }` on secrets | Always mask API keys, tokens, passwords |
| Wrong expression: `$credential.apiKey` | Use `$credentials.apiKey` (plural) |
| Forgot to list credential in `package.json` | Add to `n8n.credentials` array |
| Test endpoint requires auth but `authenticate` not set | `test.request` auto-uses the `authenticate` config |
| OAuth2 showing editable URL fields | Use `type: 'hidden'` for auth/token URLs |

## Best Practices

- Always use `typeOptions: { password: true }` for secret fields (API keys, tokens, passwords)
- Add `icon` property with `Icon` type to credential classes (required by linter)
- Include a `documentationUrl` pointing to the service's auth documentation
- Always implement a `test` request or use `testedBy` to allow users to validate their credentials
- For OAuth2, extend `oAuth2Api` and set authorization/token URLs as hidden fields
- Place a copy of your SVG icon in the `credentials/` folder and reference as `'file:name.svg'`
