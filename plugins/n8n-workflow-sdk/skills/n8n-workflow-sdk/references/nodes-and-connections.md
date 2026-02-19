# Nodes and Connections Reference

Complete reference for node factories, subnodes, connection patterns, and credentials in the `@n8n/workflow-sdk`.

## Table of Contents

- [Node Factory: `node()`](#node-factory-node)
- [Trigger Factory: `trigger()`](#trigger-factory-trigger)
- [Sticky Notes: `sticky()`](#sticky-notes-sticky)
- [Placeholders: `placeholder()`](#placeholders-placeholder)
- [New Credentials: `newCredential()`](#new-credentials-newcredential)
- [Subnode Factories (AI / LangChain)](#subnode-factories-ai--langchain)
- [fromAi() — AI-Driven Parameters](#fromai--ai-driven-parameters)
- [Connection Patterns](#connection-patterns)
- [Common Node Types](#common-node-types)

## Node Factory: `node()`

Creates a regular (non-trigger) node.

```typescript
import { node } from '@n8n/workflow-sdk'

const myNode = node({
  type: 'n8n-nodes-base.httpRequest',   // Node type identifier
  version: 4.4,                          // Node version number
  config: {
    name: 'My HTTP Request',             // Display name (auto-generated if omitted)
    parameters: {                        // Node-specific parameters
      url: 'https://api.example.com',
      method: 'GET',
      authentication: 'none'
    },
    position: [300, 200],                // [x, y] canvas position
    disabled: false,                     // Disable execution
    notes: 'Fetches data from API',      // Developer notes
    notesInFlow: false,                  // Show notes in UI
    executeOnce: false,                  // Execute once (don't iterate)
    retryOnFail: false,                  // Auto-retry on failure
    alwaysOutputData: false,             // Always produce output
    onError: 'stopWorkflow',             // 'stopWorkflow' | 'continueRegularOutput' | 'continueErrorOutput'
    credentials: {                       // Credential references
      httpBasicAuth: { name: 'My Auth', id: 'cred-uuid' }
    },
    pinData: [{ json: { mock: true } }], // Mock data for testing
    output: [{ json: { id: 1 } }],       // Declared output shape (for generatePinData)
    subnodes: {}                         // AI subnode configuration
  }
})
```

### NodeInstance Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | `string` | Node type (e.g., `'n8n-nodes-base.httpRequest'`) |
| `version` | `string` | Node version |
| `config` | `NodeConfig` | Node configuration |
| `id` | `string` | Auto-generated UUID |
| `name` | `string` | Display name |

### NodeInstance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `to(target, outputIndex?)` | `NodeChain` | Connect to target node(s) |
| `input(index)` | `InputTarget` | Create input target for specific input |
| `output(index)` | `OutputSelector` | Select specific output index |
| `onTrue(target)` | `IfElseBuilder` | IF node: set true branch |
| `onFalse(target)` | `IfElseBuilder` | IF node: set false branch |
| `onCase(index, target)` | `SwitchCaseBuilder` | Switch node: set case branch |
| `onError(handler)` | `this` | Set error handler node |
| `update(config)` | `NodeInstance` | Create copy with updated config |
| `getConnections()` | `DeclaredConnection[]` | Get declared connections |

### Updating a Node

`update()` creates a **new** node instance (immutable pattern):

```typescript
const updated = myNode.update({
  parameters: { url: 'https://new-api.example.com' }
})
// myNode is unchanged, updated is a new instance
```

## Trigger Factory: `trigger()`

Creates a trigger node. Triggers have no inputs and start workflow execution.

```typescript
import { trigger } from '@n8n/workflow-sdk'

const manualTrigger = trigger({
  type: 'n8n-nodes-base.manualTrigger',
  version: 1,
  config: { name: 'Start' }
})

const webhookTrigger = trigger({
  type: 'n8n-nodes-base.webhook',
  version: 2.1,
  config: {
    name: 'Webhook',
    parameters: { path: 'my-webhook', httpMethod: 'POST' }
  }
})

const scheduleTrigger = trigger({
  type: 'n8n-nodes-base.scheduleTrigger',
  version: 1.3,
  config: {
    name: 'Every Hour',
    parameters: { rule: { interval: [{ field: 'hours', hoursInterval: 1 }] } }
  }
})
```

`TriggerInstance` extends `NodeInstance` with `isTrigger: true`.

## Sticky Notes: `sticky()`

```typescript
import { sticky } from '@n8n/workflow-sdk'

// Simple sticky note
const note = sticky('This section handles authentication')

// Positioned around specific nodes (auto-calculates bounding box)
const note = sticky('Data Processing Pipeline', [httpNode, transformNode, filterNode])

// With manual configuration
const note = sticky('Important!', [], {
  color: 1,               // 1-7 color index
  position: [500, 200],   // [x, y]
  width: 300,
  height: 150,
  name: 'Auth Note'
})

// Combining nodes and config
const note = sticky('API Section', [node1, node2], { color: 3 })
```

## Placeholders: `placeholder()`

Mark values that the user must fill in:

```typescript
import { placeholder } from '@n8n/workflow-sdk'

const httpNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    parameters: {
      url: placeholder('Enter your API endpoint URL'),
      authentication: 'genericCredentialType'
    }
  }
})
```

## New Credentials: `newCredential()`

Mark credentials that need to be created (don't exist yet):

```typescript
import { newCredential } from '@n8n/workflow-sdk'

const httpNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    credentials: {
      httpHeaderAuth: newCredential('My API Key')
    }
  }
})
```

Versus existing credentials:

```typescript
config: {
  credentials: {
    httpHeaderAuth: { name: 'My API Key', id: 'existing-cred-uuid' }
  }
}
```

## Subnode Factories (AI / LangChain)

Subnodes are nodes that attach to a parent node (like an AI Agent) rather than connecting via the main data flow.

### Language Model: `languageModel()`

```typescript
import { languageModel } from '@n8n/workflow-sdk'

const openai = languageModel({
  type: '@n8n/n8n-nodes-langchain.lmChatOpenAi',
  version: 1.3,
  config: {
    parameters: {
      model: 'gpt-4o',
      temperature: 0.7,
      maxTokens: 2048
    },
    credentials: { openAiApi: { name: 'OpenAI', id: 'cred-123' } }
  }
})

const anthropic = languageModel({
  type: '@n8n/n8n-nodes-langchain.lmChatAnthropic',
  version: 1.3,
  config: {
    parameters: { model: 'claude-sonnet-4-5-20250929' },
    credentials: { anthropicApi: { name: 'Anthropic', id: 'cred-456' } }
  }
})
```

### Memory: `memory()`

```typescript
import { memory } from '@n8n/workflow-sdk'

const bufferMemory = memory({
  type: '@n8n/n8n-nodes-langchain.memoryBufferWindow',
  version: 1.3,
  config: {
    parameters: { contextWindowLength: 5 }
  }
})
```

### Tool: `tool()`

```typescript
import { tool, fromAi } from '@n8n/workflow-sdk'

// Simple tool
const calculator = tool({
  type: '@n8n/n8n-nodes-langchain.toolCalculator',
  version: 1,
  config: {}
})

// Tool with AI-driven parameters
const emailTool = tool({
  type: '@n8n/n8n-nodes-langchain.toolGmail',
  version: 1,
  config: {
    parameters: {
      recipient: fromAi('recipient', 'Email recipient address'),
      subject: fromAi('subject', 'Email subject line'),
      body: fromAi('body', 'Email body content')
    },
    credentials: { gmailOAuth2: { name: 'Gmail', id: 'cred-789' } }
  }
})

// Code tool
const codeTool = tool({
  type: '@n8n/n8n-nodes-langchain.toolCode',
  version: 1.3,
  config: {
    parameters: {
      name: 'lookup_user',
      description: 'Look up a user by their email address',
      jsCode: 'return { userId: "123" };'
    }
  }
})
```

### Output Parser: `outputParser()`

```typescript
import { outputParser } from '@n8n/workflow-sdk'

const structuredParser = outputParser({
  type: '@n8n/n8n-nodes-langchain.outputParserStructured',
  version: 1.3,
  config: {
    parameters: {
      schemaType: 'manual',
      inputSchema: JSON.stringify({
        type: 'object',
        properties: { answer: { type: 'string' }, confidence: { type: 'number' } }
      })
    }
  }
})
```

### Embedding: `embedding()` / `embeddings()`

```typescript
import { embedding } from '@n8n/workflow-sdk'

const openaiEmbed = embedding({
  type: '@n8n/n8n-nodes-langchain.embeddingsOpenAi',
  version: 1,
  config: {
    parameters: { model: 'text-embedding-3-small' },
    credentials: { openAiApi: { name: 'OpenAI', id: 'cred-123' } }
  }
})
```

`embeddings()` is an alias for `embedding()`.

### Vector Store: `vectorStore()`

```typescript
import { vectorStore } from '@n8n/workflow-sdk'

const pinecone = vectorStore({
  type: '@n8n/n8n-nodes-langchain.vectorStorePinecone',
  version: 1,
  config: {
    parameters: { indexName: 'my-index' },
    credentials: { pineconeApi: { name: 'Pinecone', id: 'cred-456' } }
  }
})
```

### Retriever: `retriever()`

```typescript
import { retriever } from '@n8n/workflow-sdk'

const myRetriever = retriever({
  type: '@n8n/n8n-nodes-langchain.retrieverVectorStore',
  version: 1,
  config: { parameters: { topK: 5 } }
})
```

### Document Loader: `documentLoader()`

```typescript
import { documentLoader } from '@n8n/workflow-sdk'

const loader = documentLoader({
  type: '@n8n/n8n-nodes-langchain.documentDefaultDataLoader',
  version: 1,
  config: { parameters: {} }
})
```

### Text Splitter: `textSplitter()`

```typescript
import { textSplitter } from '@n8n/workflow-sdk'

const splitter = textSplitter({
  type: '@n8n/n8n-nodes-langchain.textSplitterRecursiveCharacterTextSplitter',
  version: 1,
  config: {
    parameters: { chunkSize: 1000, chunkOverlap: 200 }
  }
})
```

### Attaching Subnodes to Parent Nodes

Subnodes are attached via the `subnodes` config property:

```typescript
const agent = node({
  type: '@n8n/n8n-nodes-langchain.agent',
  version: 3.1,
  config: {
    name: 'AI Agent',
    parameters: {
      promptType: 'define',
      text: 'You are a helpful assistant.'
    },
    subnodes: {
      model: openai,                        // Single subnode
      tools: [calculator, emailTool],       // Array of subnodes
      memory: bufferMemory,                 // Single subnode
      outputParser: structuredParser        // Single subnode
    }
  }
})
```

**Subnode config keys and their connection types:**

| Config Key | Connection Type | Accepts |
|-----------|----------------|---------|
| `model` | `ai_languageModel` | Single `LanguageModelInstance` |
| `memory` | `ai_memory` | Single `MemoryInstance` |
| `tools` | `ai_tool` | Array of `ToolInstance` |
| `outputParser` | `ai_outputParser` | Single `OutputParserInstance` |
| `embedding` | `ai_embedding` | Single `EmbeddingInstance` |
| `vectorStore` | `ai_vectorStore` | Single `VectorStoreInstance` |
| `retriever` | `ai_retriever` | Single `RetrieverInstance` |
| `documentLoader` | `ai_document` | Single `DocumentLoaderInstance` |
| `textSplitter` | `ai_textSplitter` | Single `TextSplitterInstance` |

## fromAi() — AI-Driven Parameters

Creates a `$fromAI` expression for tool nodes. The AI agent determines the value at runtime:

```typescript
import { fromAi } from '@n8n/workflow-sdk'

fromAi('key', 'description', 'type', defaultValue)
```

**Parameters:**
- `key` (string, required) — Parameter identifier
- `description` (string, optional) — Describes what the AI should provide
- `type` (optional) — `'string'` | `'number'` | `'boolean'` | `'json'`
- `defaultValue` (optional) — Default value if AI doesn't provide one

**Important:** Only use `fromAi()` in tool nodes. The validator catches `FROM_AI_IN_NON_TOOL` if used elsewhere.

```typescript
// Examples
fromAi('email', 'The email address to send to')
fromAi('count', 'Number of results', 'number', 10)
fromAi('include_details', 'Whether to include details', 'boolean', false)
fromAi('filters', 'Search filters as JSON', 'json')
```

## Connection Patterns

### Sequential Chaining

```typescript
// A → B → C
workflow('id', 'name')
  .add(nodeA)
  .to(nodeB)
  .to(nodeC)
```

### Fan-Out (Parallel Branches)

```typescript
// A → B (output 0), A → C (output 1), A → D (output 2)
workflow('id', 'name')
  .add(nodeA)
  .to([nodeB, nodeC, nodeD])
```

Each item in the array connects to the next output index (0, 1, 2, ...).

### Output Selection

For nodes with multiple outputs, use `.output(index)`:

```typescript
// Multi-output node
const multiOutput = node({ type: '...', version: 1, config: { /* ... */ } })

multiOutput.output(0).to(branchA)  // First output
multiOutput.output(1).to(branchB)  // Second output
```

### Input Selection (for Merge)

```typescript
const mergeNode = merge({ version: 3.2, config: { name: 'Combine' } })

workflow('id', 'name')
  .add(sourceA).to(mergeNode.input(0))   // → merge input 0
  .add(sourceB).to(mergeNode.input(1))   // → merge input 1
  .add(mergeNode).to(outputNode)
```

### Node Chains

Build reusable chains of nodes:

```typescript
const fetchAndTransform = httpNode.to(setNode).to(filterNode)

workflow('id', 'name')
  .add(triggerNode)
  .to(fetchAndTransform)   // Entire chain added
  .to(respondNode)
```

**NodeChain properties:**
- `head` — First node in chain
- `tail` — Last node in chain
- `allNodes` — All nodes in order
- `_isChain` — `true` (identifier)

### Error Handling

```typescript
const errorHandler = node({
  type: 'n8n-nodes-base.set', version: 3.4,
  config: { name: 'Handle Error', parameters: { /* ... */ } }
})

const riskyNode = node({ type: '...', version: 1, config: { /* ... */ } })
riskyNode.onError(errorHandler)

workflow('id', 'name')
  .add(triggerNode)
  .to(riskyNode)
  .to(nextNode)
  .add(errorHandler)  // Must also add the error handler to workflow
```

### Complex Multi-Branch Example

```typescript
import { workflow, node, trigger, merge } from '@n8n/workflow-sdk'

const start = trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: {} })
const fetchA = node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: { name: 'Fetch A', parameters: { url: 'https://a.api' } } })
const fetchB = node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: { name: 'Fetch B', parameters: { url: 'https://b.api' } } })
const combiner = merge({ version: 3.2, config: { name: 'Combine', parameters: { mode: 'append' } } })
const output = node({ type: 'n8n-nodes-base.set', version: 3.4, config: { name: 'Output' } })

const wf = workflow('multi-branch', 'Multi-Branch')
  .add(start)
  .to(fetchA)
  .to(combiner.input(0))
  .add(start)          // Re-add start to create second branch
  .to(fetchB)
  .to(combiner.input(1))
  .add(combiner)
  .to(output)
```

## Looking Up Node Types — CRITICAL

**NEVER guess or invent node type strings.** Always look up the real type and version from the cached node registry.

### Local Registry Cache (Primary Source)

This skill ships with cached copies of the n8n node registries. **Read these files to look up node types** — no network requests needed:

- **`references/node-registry-official.json`** — Index of all built-in n8n nodes (556+)
- **`references/node-registry-community.json`** — Index of community-contributed nodes (25+)
- **`references/node-registry-properties.jsonl`** — Full node properties/parameters (one JSON line per node)

#### Index files — for finding the right node

**Official node entry structure:**
```json
{
  "name": "n8n-nodes-base.slack",        // ← Use this as `type`
  "displayName": "Slack",
  "version": 2,                           // ← Use this as `version`
  "description": "Consume Slack API",
  "group": "[\"output\"]",
  "alias": ["message", "chat"],
  "categories": ["Communication", "HITL"]
}
```

**Community node entry structure:**
```json
{
  "name": "@mendable/n8n-nodes-preview-firecrawl.firecrawl",  // ← Use this as `type`
  "displayName": "Firecrawl",
  "packageName": "@mendable/n8n-nodes-firecrawl",              // ← User must install this
  "version": 1,
  "description": "Scrape websites using Firecrawl API",
  "isOfficialNode": true
}
```

**How to search:** Read the JSON index and search for nodes by `displayName`, `name`, `alias`, or `description`.

#### Properties file — for configuring a node correctly

Once you know the node `name` from the index, **grep the properties file** to get its available parameters:

```bash
grep 'n8n-nodes-base.slack' references/node-registry-properties.jsonl
```

Each line is a JSON object with this structure:
```json
{"node": "n8n-nodes-base.slack", "properties": [
  {"name": "resource", "type": "options", "default": "message", "options": [
    {"name": "Channel", "value": "channel"},
    {"name": "Message", "value": "message"}, ...
  ]},
  {"name": "operation", "type": "options", "default": "post", "displayOptions": {"show": {"resource": ["message"]}}, ...},
  {"name": "text", "type": "string", "required": true, "description": "The message text to post", ...},
  ...
]}
```

Property fields:
- `name` — Parameter name to use in `parameters: { ... }`
- `type` — `"string"`, `"options"`, `"boolean"`, `"number"`, `"collection"`, etc.
- `default` — Default value
- `required` — Whether the parameter is required
- `options` — Available choices for `"options"` type (each with `name` and `value`)
- `description` — What the parameter does
- `displayOptions` — Conditional visibility (`{"show": {"resource": ["message"]}}` means this param only applies when `resource` is `"message"`)

**CRITICAL: Use the option `value`, NOT the display `name`.** For `options`-type parameters, the `name` is a human-readable label shown in the n8n UI, while the `value` is what goes in the workflow JSON. These are often very different:

```
"options": [{"name": "Manual Mapping", "value": "manual"}, {"name": "JSON", "value": "raw"}]
                      ^^^^^^^^^^^^^^^^                ^^^^^^^^           ^^^^^^           ^^^^^
                      UI label                        Use THIS           UI label         Use THIS
```

Common traps where display name ≠ value: Set `mode` (`"JSON"` → `"raw"`), HTTP Request `contentType` (`"Form Urlencoded"` → `"form-urlencoded"`), Code `language` (`"Python"` → `"pythonNative"`), Webhook `responseMode` (`"Immediately"` → `"onReceived"`), Merge `mode` (`"SQL Query"` → `"combineBySql"`).

### Refreshing the Cache

If a node can't be found in the cached registries (they may be outdated), **run the refresh script** to pull the latest data:

```bash
bash scripts/refresh-node-registry.sh
```

This fetches from `https://api.n8n.io/api/nodes` and `https://api.n8n.io/api/community-nodes`, strips heavy fields, and updates all three cache files.

### Community Node Warning

**When using community nodes**, the user must install the npm package in their n8n instance first. **Always add a `sticky()` note** to the workflow:

```typescript
import { sticky } from '@n8n/workflow-sdk'

const installWarning = sticky(
  '⚠️ Required Community Node: Install "@mendable/n8n-nodes-firecrawl" in your n8n instance (Settings → Community Nodes → Install) before using this workflow.',
  [firecrawlNode],  // Position near the community node
  { color: 5 }
)

// Add the sticky to the workflow
workflow('id', 'name')
  .add(installWarning)
  .add(triggerNode)
  .to(firecrawlNode)
```

If the workflow uses **multiple community packages**, list them all in one sticky note or use separate notes per package.

### Lookup Order

1. User asks for a node (e.g., "Slack", "Notion", "Firecrawl")
2. Read `references/node-registry-official.json` → search by displayName/name
3. If found → use `name` and `version`
4. If NOT found → read `references/node-registry-community.json` → search by displayName/name
5. If found in community → use the type + add a `sticky()` note with the `packageName`
6. Grep `references/node-registry-properties.jsonl` for the node name → get its available parameters
7. If NOT found in cache → run `bash scripts/refresh-node-registry.sh` to update, then search again
8. If NOT found anywhere → tell the user the node doesn't exist, do not invent one

### Core Utility Nodes (Safe Without Lookup)

These fundamental node **type names** are always available. However, **always look up the correct `version`** from `references/node-registry-official.json` — do NOT copy version numbers from code examples, as they may be outdated:

| Type | Description |
|------|-------------|
| `n8n-nodes-base.manualTrigger` | Manual execution trigger |
| `n8n-nodes-base.webhook` | HTTP webhook trigger |
| `n8n-nodes-base.scheduleTrigger` | Cron/interval trigger |
| `n8n-nodes-base.httpRequest` | Generic HTTP request |
| `n8n-nodes-base.set` | Set/transform data fields |
| `n8n-nodes-base.code` | Custom JavaScript/Python code |
| `n8n-nodes-base.if` | Conditional branching |
| `n8n-nodes-base.switch` | Multi-branch routing |
| `n8n-nodes-base.merge` | Merge multiple inputs |
| `n8n-nodes-base.splitInBatches` | Batch processing loop |
| `n8n-nodes-base.respondToWebhook` | Respond to webhook |
| `n8n-nodes-base.noOp` | No operation (passthrough) |
| `n8n-nodes-base.filter` | Filter items |
| `n8n-nodes-base.splitOut` | Split arrays into items |
| `n8n-nodes-base.aggregate` | Aggregate items |
| `n8n-nodes-base.limit` | Limit number of items |
| `n8n-nodes-base.removeDuplicates` | Remove duplicate items |
| `n8n-nodes-base.sort` | Sort items |
| `n8n-nodes-base.wait` | Wait/delay |
| `n8n-nodes-base.executeWorkflow` | Execute sub-workflow |
| `n8n-nodes-base.stickyNote` | Canvas annotation |
| `@n8n/n8n-nodes-langchain.agent` | AI Agent |

**⚠️ IMPORTANT: Version numbers in code examples throughout this skill are illustrative and may be outdated.** The **only reliable source** for the current version of any node is `references/node-registry-official.json` (or `references/node-registry-community.json` for community nodes). Always read the registry cache to get the correct `version` before using any node.

**For ANY integration node not in this list** (Slack, Gmail, Notion, Airtable, Google Sheets, Postgres, Stripe, etc.), you MUST look up the correct `type` and `version` from the registry cache.

## Common Node Configuration Patterns

These examples show **properly configured** nodes with parameters. Always grep `references/node-registry-properties.jsonl` for the node name to discover all available parameters.

### Set / Edit Fields Node

The Set node (`n8n-nodes-base.set`) — displayed as "Edit Fields" in n8n — transforms data by setting, renaming, or removing fields.

**⚠️ CRITICAL: Set node v3.3+ uses `assignments`, NOT `fields`!** The parameter schema changed at v3.3. Version 3.4 (current) uses the `assignments` format shown below. The old `fields.values` / `stringValue` / `numberValue` format is for v3.0–3.2 only and **will not work** with v3.4.

**🚫 ANTI-PATTERN — NEVER generate these broken formats:**
```typescript
// ❌ WRONG — empty Set node, does nothing:
parameters: { options: {} }

// ❌ WRONG — old v3.0-3.2 format, does NOT work with v3.4:
parameters: { mode: 'manual', fields: { values: [{ name: 'x', type: 'stringValue', stringValue: 'y' }] } }
```

**✅ REQUIRED (v3.3+/3.4):** A Set node MUST always have EITHER:
- `mode: 'manual'` + `assignments.assignments` array with at least one entry, OR
- `mode: 'raw'` + `jsonOutput` string with the JSON to produce

If you don't know what fields to set, ask the user. Never output a Set node with `parameters: { options: {} }`.

```typescript
// Manual mode: set specific fields (v3.4 assignments format)
const setNode = node({
  type: 'n8n-nodes-base.set', version: 3.4,
  config: {
    name: 'Edit Fields',
    parameters: {
      mode: 'manual',
      assignments: {
        assignments: [
          { name: 'fullName', value: '={{ $json.firstName + " " + $json.lastName }}', type: 'string' },
          { name: 'isActive', value: true, type: 'boolean' },
          { name: 'score', value: 100, type: 'number' }
        ]
      },
      includeOtherFields: true,  // true = pass through all input fields alongside new ones
      options: {}
    }
  }
})

// JSON mode: output custom JSON directly
const setJsonNode = node({
  type: 'n8n-nodes-base.set', version: 3.4,
  config: {
    name: 'Custom Output',
    parameters: {
      mode: 'raw',
      jsonOutput: '{ "status": "processed", "timestamp": "={{ $now.toISOString() }}" }',
      options: {}
    }
  }
})

// Set fields WITHOUT passing through input fields (includeOtherFields defaults to false)
const onlyNewFieldsNode = node({
  type: 'n8n-nodes-base.set', version: 3.4,
  config: {
    name: 'Only New Fields',
    parameters: {
      mode: 'manual',
      assignments: {
        assignments: [
          { name: 'name', value: '={{ $json.name }}', type: 'string' },
          { name: 'email', value: '={{ $json.email }}', type: 'string' }
        ]
      },
      options: {}
    }
  }
})
```

**Assignment entry format (v3.4):**

Each entry in `assignments.assignments` has three fields:

| Property | Description | Example |
|----------|-------------|---------|
| `name` | Field name to set | `'fullName'` |
| `value` | The value (static or expression) | `'={{ $json.first }}'`, `42`, `true` |
| `type` | `'string'`, `'number'`, or `'boolean'` | `'string'` |

**Include behavior (v3.4):** Set `includeOtherFields: true` to pass through all input fields alongside the new/modified ones. When `false` (default), only the explicitly assigned fields appear in the output. When `includeOtherFields` is `true`, you can optionally add `include` (`'all'` | `'selected'` | `'except'`) with `includeFields` or `excludeFields` to fine-tune which input fields pass through.

### HTTP Request Node

```typescript
// GET request with headers
const getNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    name: 'Fetch Data',
    parameters: {
      url: 'https://api.example.com/users',
      method: 'GET',
      authentication: 'none',
      sendHeaders: true,
      headerParameters: {
        parameters: [
          { name: 'Accept', value: 'application/json' }
        ]
      }
    },
    output: [{ json: { id: 1, name: 'Alice' } }]
  }
})

// POST request with JSON body
const postNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    name: 'Create User',
    parameters: {
      url: 'https://api.example.com/users',
      method: 'POST',
      sendBody: true,
      bodyParameters: {
        parameters: [
          { name: 'name', value: '={{ $json.name }}' },
          { name: 'email', value: '={{ $json.email }}' }
        ]
      }
    }
  }
})
```

### IF Node

```typescript
const ifNode = node({
  type: 'n8n-nodes-base.if', version: 2.3,
  config: {
    name: 'Check Status',
    parameters: {
      conditions: {
        options: { caseSensitive: true, leftValue: '' },
        conditions: [{
          leftValue: '={{ $json.status }}',
          rightValue: 'active',
          operator: { type: 'string', operation: 'equals' }
        }]
      }
    }
  }
})
```

**Common operators:** `equals`, `notEquals`, `contains`, `notContains`, `startsWith`, `endsWith`, `gt`, `gte`, `lt`, `lte`, `regex`, `isEmpty`, `isNotEmpty`.
