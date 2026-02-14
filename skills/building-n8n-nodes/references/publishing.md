# Publishing & Verification Reference

Complete checklist for linting, testing, publishing, and submitting your n8n node for verification.

## Table of Contents

1. [Pre-Publish Checklist](#pre-publish-checklist)
2. [Testing Locally](#testing-locally)
3. [Linting](#linting)
4. [Package.json Requirements](#packagejson-requirements)
5. [Publishing to npm](#publishing-to-npm)
6. [Verification Guidelines](#verification-guidelines)
7. [Submitting for Verification](#submitting-for-verification)
8. [Troubleshooting](#troubleshooting)

## Pre-Publish Checklist

Before publishing, confirm every item:

- [ ] Package name starts with `n8n-nodes-` or `@<scope>/n8n-nodes-`
- [ ] `package.json` has keyword `n8n-community-node-package`
- [ ] `package.json` has `n8n` attribute listing all nodes and credentials
- [ ] All node and credential files compile without TypeScript errors
- [ ] `npm run lint` passes with zero errors
- [ ] `npm run dev` loads the node in local n8n successfully
- [ ] Node appears in the nodes panel when searching by `displayName`
- [ ] All operations function correctly with real API calls
- [ ] Credential test (the "Test" button) succeeds with valid credentials
- [ ] Icon displays correctly (square, no clipping)
- [ ] Codex file (`*.node.json`) has appropriate categories

## Testing Locally

### Using the CLI (recommended)

```bash
npm run dev
```

This compiles and starts a local n8n instance at `http://localhost:5678` with your node loaded. It watches for changes and auto-rebuilds.

### Manual method

```bash
# Step 1: Build your node
npm run build

# Step 2: Create a symlink
npm link

# Step 3: Link into n8n's custom directory
# If ~/.n8n/custom/ doesn't exist:
mkdir -p ~/.n8n/custom && cd ~/.n8n/custom && npm init -y

# Link your package:
cd ~/.n8n/custom
npm link <your-package-name>

# Step 4: Start n8n
n8n start
```

### Testing tips

- Search for the node by its `displayName`, not the package name
- If changes don't appear, stop n8n, rebuild, and restart
- For webhook triggers, use `n8n start --tunnel` to test with external services
- Test each operation with real API credentials
- Test error cases: invalid credentials, missing required fields, API errors

## Linting

The n8n linter (`eslint-plugin-n8n-nodes-base`) checks node files, credential files, and package.json.

```bash
# Check for issues:
npm run lint

# Auto-fix fixable issues:
npm run lint -- --fix
# or
npm run lintfix
```

### Common linter rules

The linter checks for:

**Node files (`*.node.ts`):**
- Correct class naming (matches filename)
- Required description fields
- Title Case for displayName, option names
- Sentence case for descriptions
- Correct use of `noDataExpression: true` on resource/operation
- `action` field required on all operation options
- List operations must be named **"Get Many"** (not "Get All")
- `usableAsTool: true` recommended for AI agent compatibility

**Credential files (`*.credentials.ts`):**
- Required fields (name, displayName, properties)
- Password type on sensitive fields
- Documentation URL
- Icon property required (`icon: Icon = 'file:name.svg'`)

**Package.json:**
- Correct package name format
- Required keywords
- n8n attribute with nodes and credentials arrays
- Correct file paths in n8n attribute

### VS Code integration

Install the ESLint VS Code extension. The linter runs in the background and highlights issues as you type. Hover over issues for descriptions and quick-fix options.

## Package.json Requirements

### Minimum required structure

```json
{
  "name": "n8n-nodes-myservice",
  "version": "0.1.0",
  "description": "n8n nodes to integrate with My Service",
  "keywords": [
    "n8n-community-node-package"
  ],
  "license": "MIT",
  "main": "index.js",
  "files": [
    "dist"
  ],
  "scripts": {
    "build": "tsc && gulp build:icons",
    "dev": "n8n-node dev",
    "lint": "n8n-node lint",
    "lintfix": "n8n-node lint --fix",
    "release": "n8n-node release"
  },
  "n8n": {
    "n8nNodesApiVersion": 1,
    "strict": true,
    "credentials": [
      "dist/credentials/MyServiceApi.credentials.js"
    ],
    "nodes": [
      "dist/nodes/MyService/MyService.node.js"
    ]
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "gulp": "^4.0.2",
    "n8n-workflow": "*",
    "typescript": "~5.0"
  },
  "peerDependencies": {
    "n8n-workflow": "*"
  }
}
```

Key points:
- The `n8n.credentials` and `n8n.nodes` arrays point to **compiled JS files** in `dist/`
- Every node and credential file must be listed here
- The `n8nNodesApiVersion` should be `1`
- Set `"strict": true` in the `n8n` config for community node linting compliance
- Include `"files": ["dist"]` to publish only compiled output (not source)
- Use `MIT` license for verified community nodes
- `n8n-workflow` should be a **peer dependency**, not bundled — n8n provides it at runtime
- Populate `author`, `repository`, `license`, and `homepage` fields

## Publishing to npm

### Using the CLI (recommended)

```bash
n8n-node release
# or
npm run release
```

This uses `release-it` under the hood to:
1. Clean the dist directory
2. Run linting checks
3. Build the project
4. Bump the version
5. Publish to npm
6. Create a git tag

### Manual publishing

**Important:** The n8n-nodes-starter includes a `prepublishOnly` script (`n8n-node prerelease`) that blocks direct `npm publish`. You have two options:

```bash
# Option 1: Remove prepublishOnly from package.json, then:
npm run build
npm publish --access public

# Option 2: Use the built-in release flow (recommended):
npm run release
```

### First-time setup

- Create an npm account at https://www.npmjs.com/signup
- Login: `npm login`
- For scoped packages: `npm publish --access public`

After publishing, users install your node via: **Settings → Community Nodes → Install → `n8n-nodes-myservice`**

## Verification Guidelines

To get your node **verified** (discoverable in the n8n nodes panel without manual installation):

### Technical requirements

- Must be built with the `n8n-node` CLI tool scaffolding
- **No runtime dependencies** — use only n8n's built-in helpers and the standard library
- No environment variable access
- No filesystem access
- Pass the linter with zero errors
- English-only UI text
- MIT license

### UX requirements

- Follow n8n's UI design guidelines:
  - Title Case for parameter names, dropdown values, node name
  - Sentence case for descriptions, hints, tooltips
  - Resource → Operation pattern for multi-endpoint nodes
  - Additional Fields for optional parameters
- Use the same terminology as the service's GUI (not its API)
- Include helpful descriptions and hints
- Icon should be SVG, square aspect ratio

### Code quality

- TypeScript throughout
- Proper error handling with NodeApiError/NodeOperationError
- continueOnFail() support
- pairedItem linking for all output items (programmatic)
- No data mutation — clone input items
- Credential testing via `test` property

## Submitting for Verification

1. Ensure your node meets all requirements above
2. Publish to npm
3. Go to [n8n Creator Portal](https://creators.n8n.io/nodes)
4. Sign up or log in
5. Submit your package name for review

n8n will review your node for code quality, UX compliance, and security. They may request changes before approving.

Note: n8n reserves the right to reject nodes that compete with paid enterprise features.

## Troubleshooting

### "Credentials of type X aren't known"

The credential `name` in the node file doesn't match the `name` property in the credentials class. Ensure they're identical.

### Node doesn't appear in the nodes panel

- Check that it's registered in `package.json` under `n8n.nodes`
- Verify the path points to the correct compiled file
- Rebuild: `npm run build`
- Restart n8n

### Node icon doesn't show

- Icon must be in the same directory as the `.node.ts` file
- Must be SVG or PNG format
- The `icon` property must include `file:` prefix and the extension
- SVG must have a square canvas

### "API-Server cannot be reached" error

- Class name, file name, and package.json path must all be consistent
- Check that `displayOptions` reference existing property names

### Changes don't show after refresh

Every time you change description properties:
1. Stop the n8n process (Ctrl+C)
2. Rebuild: `npm run build`
3. If using npm link: re-run `npm link`
4. Restart n8n

When using `npm run dev`, changes rebuild automatically, but you may still need to refresh the browser.
