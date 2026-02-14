---
name: building-n8n-nodes
description: "Builds custom community nodes for n8n, the workflow automation platform. Activates when the user wants to create, scaffold, develop, test, lint, or publish an n8n node — including both declarative (REST API) and programmatic styles. Also triggers when the user mentions n8n nodes, n8n-cli, n8n-node, community nodes, node credentials, or anything related to extending n8n with custom integrations. Encodes all official best practices from n8n's documentation."
---

# n8n Node Builder

Build production-ready custom nodes for n8n using the official `n8n-node` CLI tool and n8n's best practices.

## When You Need More Detail

This skill uses progressive disclosure. The SKILL.md covers the full workflow and decision-making. For complete code templates, read these reference files:

- `references/declarative-node.md` — Full declarative node template with routing, credentials, and codex file
- `references/programmatic-node.md` — Full programmatic node template with execute method, error handling, item linking, and trigger patterns
- `references/credentials.md` — All credential/auth patterns (API key, Bearer, OAuth2, Basic, Custom, testedBy)
- `references/publishing.md` — Linting, testing, releasing, and verification checklist
- `references/common-mistakes.md` — Error catalog with 24 numbered mistake patterns and fixes

Read the appropriate reference file before writing any code.

## Workflow Overview

Building an n8n node follows this sequence:

1. **Decide** on the node style (declarative vs programmatic)
2. **Scaffold** the project with the `n8n-node` CLI
3. **Implement** the node base file, credentials file, and codex file
4. **Test** locally with `npm run dev`
5. **Lint** with `npm run lint`
6. **Publish** to npm and optionally submit for verification

## Step 1: Choose Your Node Style

n8n has two node-building styles. Picking the right one up front saves significant rework.

### Declarative Style (preferred for REST APIs)

Use declarative when the integration is a straightforward REST API wrapper. It's JSON-based, simpler, more future-proof, and faster to get approved for n8n Cloud.

The declarative style handles data flow through a `routing` key inside the operations object. There's no `execute()` method — n8n constructs HTTP requests from the JSON description automatically.

**Choose declarative when:**
- The API is REST-based
- You don't need to transform response data in complex ways
- You want a simpler, lower-risk codebase

### Programmatic Style (required for advanced use cases)

Use programmatic when you need full control over execution. It requires an `execute()` method that reads inputs, builds requests, and returns results manually.

**You must use programmatic for:**
- Trigger nodes (webhook, polling, or other event-driven)
- GraphQL APIs
- Non-REST protocols
- Nodes that transform incoming data
- Full versioning (separate version directories)
- Complex multi-step logic (pagination, chaining calls, conditional branching)

### Quick Decision

Ask: "Is this a simple REST API wrapper with no triggers?" If yes → declarative. Otherwise → programmatic.

## Step 2: Scaffold with the n8n-node CLI

The CLI sets up the correct project structure, dependencies, linter config, and build scripts automatically.

### Option A: Without installing (recommended)

```bash
npm create @n8n/node@latest n8n-nodes-<YOUR_NODE_NAME> -- --template <template>
```

Templates:
- `declarative/github-issues` — Demo with multiple operations and credentials (good for learning)
- `declarative/custom` — Blank declarative starting point (prompts for base URL, auth type)
- `programmatic/example` — Programmatic with full flexibility

### Option B: Install globally

```bash
npm install --global @n8n/node-cli
n8n-node new n8n-nodes-<YOUR_NODE_NAME> --template <template>
```

### Option C: Clone the n8n-nodes-starter repo

```bash
git clone https://github.com/n8n-io/n8n-nodes-starter.git n8n-nodes-<YOUR_NODE_NAME>
cd n8n-nodes-<YOUR_NODE_NAME>
rm -rf .git && git init
npm install
```

The starter provides pre-configured TypeScript, ESLint, build scripts, and example files. After cloning, rename/replace the example node and credential files with your own and update `package.json`.

### Naming Rules

Package names must follow one of these formats:
- `n8n-nodes-<NAME>` (e.g., `n8n-nodes-acme`)
- `@<ORG>/n8n-nodes-<NAME>` (e.g., `@myorg/n8n-nodes-acme`)

After scaffolding, the project looks like:

```
n8n-nodes-<name>/
├── package.json          # Must contain "n8n" attribute listing nodes and credentials
├── tsconfig.json
├── .eslintrc.js          # Don't edit — contains n8n linter config
├── nodes/
│   └── <NodeName>/
│       ├── <NodeName>.node.ts      # Base file — the node's core logic
│       ├── <NodeName>.node.json    # Codex file — metadata for n8n's node panel
│       └── <NodeName>.svg          # Icon — square SVG recommended
├── credentials/
│   └── <NodeName>Api.credentials.ts  # Credential file
└── dist/                 # Built output (generated by build command)
```

## Step 3: Implement the Node

Every node needs three files at minimum: the base file, the codex file, and the credentials file (unless no auth is needed).

### 3A: The Node Base File (`<Name>.node.ts`)

This is the heart of the node. It exports a class implementing `INodeType` with a `description` object.

**Critical rules:**
- The class name must match the filename (e.g., class `Acme` → file `Acme.node.ts`)
- Use `NodeConnectionType.Main` for inputs/outputs (imported from `n8n-workflow`). If your `n8n-workflow` version exports it as type-only, use the string `'main'` as fallback
- The `name` field in the description must be a camelCase unique identifier
- Use Title Case for `displayName` and all UI-facing strings
- Always set `noDataExpression: true` on Resource and Operation selectors
- Always include `action` on every operation option (e.g., `action: 'Create a contact'`)
- Use `import type` for symbols only used in type annotations (rule of thumb: if a symbol only appears in `: Type` annotations, function signatures, or `as Type` casts, use `import type`; if it's used as a value like `throw new NodeApiError(...)`, use regular import)
- Dynamic expressions in routing must start with `=` prefix: `'=/contacts/{{$parameter["id"]}}'`
- **Declarative nodes cannot have an `execute()` method** — if `requestDefaults` is present, n8n uses the routing engine and ignores `execute()`. Use one or the other
- The `execute()` method must return `[returnData]` — an array of arrays (one per output connector). Forgetting the outer array is a common error

**Standard description parameters** (same for both styles):

| Parameter | Type | Purpose |
|-----------|------|---------|
| `displayName` | string | Name shown in the UI |
| `name` | string | Internal camelCase identifier |
| `icon` | string | `'file:<name>.svg'` — reference the icon file |
| `group` | string[] | `['transform']` for action nodes, `['trigger']` for triggers |
| `version` | number or number[] | Start at `1`; use array for light versioning |
| `subtitle` | string | Template shown below node name, e.g. `'={{$parameter["operation"]}}'` |
| `description` | string | Short description for the node panel |
| `defaults` | object | `{ name: 'Display Name' }` |
| `inputs` | array | `[NodeConnectionType.Main]` |
| `outputs` | array | `[NodeConnectionType.Main]` |
| `usableAsTool` | boolean | `true` — enables use as an AI agent tool (recommended) |
| `credentials` | array | `[{ name: 'credName', required: true }]` |
| `properties` | array | Resource, operation, and field definitions |

**For declarative nodes**, also add:
- `requestDefaults: { baseURL: 'https://api.example.com', headers: { Accept: 'application/json' } }`
- Operations use a `routing` key to define HTTP method, URL, query strings, and body

**For programmatic nodes**, also add:
- An `async execute()` method
- Proper item looping with `this.getInputData()` and `pairedItem` linking

For complete templates, read the appropriate reference file before coding:
- Declarative → Read `references/declarative-node.md`
- Programmatic → Read `references/programmatic-node.md`

### 3B: The Resource → Operation Pattern

n8n nodes follow a consistent UI pattern: **Resource** (what entity) → **Operation** (what action).

Each resource gets a dropdown, each operation gets a dropdown filtered by the selected resource using `displayOptions.show`. Operations should map to CRUD verbs where applicable: Create, Create or Update (Upsert), Delete, Get, Get Many, Update. Use the `action` field on each operation option to provide a human-readable description (e.g., `action: 'Create a contact'`). For Upsert, use displayName "Create or Update" with description "Create a new record or update an existing one (upsert)".

**Important naming rule:** The linter enforces naming list operations **"Get Many"** (not "Get All"). The operation value should be `getAll` but the display name must be `Get Many`.

### Return All / Limit Pattern

For list ("Get Many") operations, always include a `returnAll` boolean toggle (default `false`, description `'Whether to return all results or only up to a given limit'`) paired with a conditional `limit` number field that only shows when `returnAll` is `false` (`displayOptions: { show: { returnAll: [false] } }`). This is the standard pattern used across all n8n built-in nodes. See both reference templates for complete examples.

### 3C: displayOptions and Conditional Fields

Use `displayOptions.show` to conditionally display fields based on the selected resource, operation, or other parameter values (e.g., `show: { resource: ['contact'], operation: ['create'] }`). For version-specific fields, use `'@version'`: `displayOptions: { show: { '@version': [2] } }`.

### 3D: Additional Fields (Optional Parameters)

Group optional parameters under a collection named "Additional Fields":

```typescript
{
  displayName: 'Additional Fields',
  name: 'additionalFields',
  type: 'collection',
  placeholder: 'Add Field',
  default: {},
  displayOptions: {
    show: { resource: ['contact'], operation: ['create'] },
  },
  options: [
    // Individual optional fields here
  ],
}
```

### 3E: The Codex File (`<Name>.node.json`)

Metadata controlling how the node appears in n8n's node discovery panel:

```json
{
  "node": "n8n-nodes-<package>.<nodeName>",
  "nodeVersion": "1.0",
  "codexVersion": "1.0",
  "categories": ["Miscellaneous"],
  "resources": {
    "credentialDocumentation": [{ "url": "" }],
    "primaryDocumentation": [{ "url": "" }]
  }
}
```

The `node` field format is `<npm-package-name>.<node-internal-name>` (e.g., `n8n-nodes-acme.acmeService`).

Categories: Analytics, Communication, Data & Storage, Development, Finance & Accounting, Marketing & Content, Miscellaneous, Productivity, Sales, Utility.

### 3F: Credentials

Read `references/credentials.md` for complete patterns. Key points:
- File: `credentials/<Name>Api.credentials.ts`
- Class implements `ICredentialType`
- `name` must match the node's `credentials[].name`
- Use `authenticate: IAuthenticateGeneric` for header/body/query auth
- Use `test: ICredentialTestRequest` to validate credentials (or `testedBy` in the node for complex validation)
- Always use `$credentials` (plural) in expressions — `$credential` (singular) is wrong
- The linter requires an `icon` property using `Icon` type from n8n-workflow

### 3G: The Icon

SVG is recommended (square aspect ratio). PNG alternative: 60×60px. Place alongside the `.node.ts` file. Reference with `icon: 'file:<name>.svg'`. For light/dark variants: `icon: { light: 'file:icon.svg', dark: 'file:icon.dark.svg' }`. Don't reference Font Awesome — download and embed.

## Step 4: Error Handling (Programmatic Nodes)

Use `NodeApiError` for API errors and `NodeOperationError` for validation errors (both from `n8n-workflow`). Wrap each item's processing in `try/catch` and support `continueOnFail()` so users can choose to keep going on errors — push `{ json: { error: message }, pairedItem: { item: i } }` on failure. See `references/programmatic-node.md` → "Error Handling Patterns" for full examples including HTTP status-specific handling.

## Step 5: Item Linking (pairedItem / constructExecutionMetaData)

Every output item in a programmatic node must link back to its source input. There are two approaches:

**Modern approach (recommended):** Use `constructExecutionMetaData`:
```typescript
const executionData = this.helpers.constructExecutionMetaData(
  this.helpers.returnJsonArray(responseData),
  { itemData: { item: i } },
);
returnData.push(...executionData);
```

**Manual approach:** Set `pairedItem` directly:
```typescript
returnData.push({
  json: responseData,
  pairedItem: { item: i },
});
```

Without item linking, n8n can't trace data flow between nodes.

## Step 6: HTTP Helpers

Use n8n's built-in helpers — no external HTTP libraries:

```typescript
// Without auth:
const response = await this.helpers.httpRequest(options);

// With auth (handles credential injection automatically):
const response = await this.helpers.httpRequestWithAuthentication.call(
  this, 'credentialTypeName', options
);
```

**Deprecation warning:** `this.helpers.requestWithAuthentication` and `IRequestOptions` are **deprecated**. Always use `httpRequestWithAuthentication` with `IHttpRequestOptions`. The new interface uses `url` (not `uri`) and defaults to JSON parsing.

### GenericFunctions.ts Pattern

For programmatic nodes, create a `GenericFunctions.ts` helper to centralize HTTP logic. Include `IHookFunctions`, `IWebhookFunctions`, and `IPollFunctions` in the `this` type union for trigger node compatibility. See `references/programmatic-node.md` → "GenericFunctions.ts Pattern" for the full template with pagination variants.

### Dynamic Options (loadOptionsMethod)

Use `loadOptionsMethod` for dropdowns that fetch values from an API at runtime. Define a `methods.loadOptions` object in the node class, with each method returning `Array<{ name: string, value: string }>`. See `references/programmatic-node.md` for the complete pattern.

## Step 7: Node Versioning

**Light versioning** (all node types): Change `version` to an array `[1, 2]` and use `displayOptions: { show: { '@version': [2] } }`.

**Full versioning** (programmatic only): Extend `NodeVersionedType` with separate `v1/`, `v2/` directories. See the Mattermost node on GitHub for a real example.

## Step 8: Test, Lint, Publish

```bash
npm run dev              # Live-reload local n8n with your node
npm run lint             # Check against n8n standards
npm run lint -- --fix    # Auto-fix what's possible
n8n-node release         # Publish to npm (uses release-it)
```

Read `references/publishing.md` for the full publishing and verification checklist.

## Code Standards Summary

- Write in TypeScript; use `import type` for type-only imports (if a symbol only appears in `: Type` annotations or `as Type` casts, use `import type`)
- Use `httpRequestWithAuthentication` (not the deprecated `requestWithAuthentication`); use `url` not `uri` in `IHttpRequestOptions`
- Never mutate incoming data — clone with spread or `structuredClone()`
- No external runtime dependencies for verified nodes — use built-in helpers only
- `n8n-workflow` should be a peer dependency, not bundled
- Follow Resource → Operation pattern with `noDataExpression: true` on selectors
- Always include `action` on every operation option
- Use `constructExecutionMetaData` with `itemData` for proper item linking
- Implement `continueOnFail()` in every execute loop
- The `execute()` method returns `[returnData]` — don't forget the outer array wrapper
- Create `GenericFunctions.ts` for shared API request helpers (include `IHookFunctions` and `IWebhookFunctions` in the `this` type for trigger node compatibility)
- Add `usableAsTool: true` to node descriptions for AI agent compatibility
- Name list operations **"Get Many"** (not "Get All") — the linter enforces this
- Use `returnAll` / `limit` pair for list operations
- Use `displayOptions` for progressive field disclosure
- Optional params go in "Additional Fields" collections
- Title Case for UI text; Sentence case for descriptions/hints
- Trigger nodes: `inputs: []`, `group: ['trigger']`, "Trigger" suffix in `displayName` and class name
- Reuse internal parameter `value` names across operations
- Set `"strict": true` in the `n8n` config of `package.json`
- Use `$credentials` (plural) in credential expressions — `$credential` (singular) won't resolve
- Dynamic expressions in routing need the `=` prefix: `'=/path/{{$parameter.id}}'`
- Declarative nodes cannot have `execute()` — use routing OR execute, not both
- Pass the linter before publishing — see `references/common-mistakes.md` for the full error catalog

## UX Patterns (Verification Requirements)

These patterns are required for verified community nodes and recommended for all nodes:

**Delete operation output:** Always return `{ deleted: true }` (not `{ success: true }`) from Delete operations. This confirms the deletion and triggers the following node.

**Simplify toggle:** When an endpoint returns data with more than 10 fields, add a "Simplify" boolean parameter that returns a curated subset of max 10 fields. Use displayName `Simplify` and description `Whether to return a simplified version of the response instead of the raw data`. Flatten nested fields in simplified mode.

**AI Tool Output parameter:** For nodes used as AI agent tools, add an "Output" options parameter with three modes: Simplified (same as Simplify above), Raw (all fields), and Selected Fields (user picks which fields to send to the AI agent). This prevents context window overflow.

**Resource Locator:** Use `type: 'resourceLocator'` instead of a plain string input whenever a user needs to select a single item (e.g., a specific document, board, or channel). It offers ID, URL, and "From list" modes. Default to "From list" when available. See the Trello and Google Drive nodes for examples.

**Sorting options for Get Many:** Enhance list operations by providing sorting options in a dedicated collection below the main "Options" collection.

**Binary data naming:** Don't use "binary data" or "binary property" in field names. Instead use "Input Data Field Name" / "Output Data Field Name".

**Upsert:** When the API supports it, include "Create or Update" as a separate operation alongside Create and Update.

## Trigger Nodes

Triggers are always programmatic. Four patterns:

| Type | Method | Use When | Example |
|------|--------|----------|---------|
| Webhook (auto) | `webhook()` + `webhookMethods` | Service supports API-based webhook registration | Stripe Trigger |
| Webhook (manual) | `webhook()` only | User pastes webhook URL into external service | Generic Webhook |
| Polling | `poll()` | No webhook support; check for new data on a schedule | Gmail Trigger |
| Event/Stream | `trigger()` | Long-running connection (WebSocket, SSE, message queue) | AMQP Trigger |

**Key differences from action nodes:**
- Set `group: ['trigger']` and suffix the `displayName` with "Trigger"
- Trigger nodes have `inputs: []` — they have NO inputs
- Class names and filenames get the `Trigger` suffix (e.g., `MyServiceTrigger`)
- Use `getWorkflowStaticData('node')` to persist state (webhook IDs, last-checked timestamps) between calls

For complete trigger templates with full code examples, read `references/programmatic-node.md` → "Trigger Node Patterns".

## Modular Structure (Complex Nodes)

For many resources/operations, split into modules:

```
nodes/MyNode/
├── MyNode.node.ts           # Main entry
├── GenericFunctions.ts      # Shared API request helpers
├── actions/                 # One dir per resource
│   ├── contact/
│   │   ├── create.ts
│   │   ├── get.ts
│   │   └── index.ts
│   └── deal/
│       └── index.ts
├── methods/                 # loadOptions, etc.
└── transport/               # Shared HTTP helpers
```

## n8n Data Structure

Data flows between nodes as arrays of items. Each item has `json` (required) and optionally `binary`. The `execute()` method returns `Promise<INodeExecutionData[][]>` — an array of arrays (one per output). Use `this.helpers.returnJsonArray(responseData)` to wrap raw data, and remember to return `[returnData]` (nested array).
