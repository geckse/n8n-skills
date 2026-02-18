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
  version: 5,                            // Node version number
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
  version: 2,
  config: {
    name: 'Webhook',
    parameters: { path: 'my-webhook', httpMethod: 'POST' }
  }
})

const scheduleTrigger = trigger({
  type: 'n8n-nodes-base.scheduleTrigger',
  version: 1.2,
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
  type: 'n8n-nodes-base.httpRequest', version: 5,
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
  type: 'n8n-nodes-base.httpRequest', version: 5,
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
  version: 1.2,
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
  version: 1.2,
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
  version: 1.2,
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
  type: 'n8n-nodes-base.gmailTool',
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
  version: 1.1,
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
  version: 1.2,
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
  version: 1.7,
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
const mergeNode = merge({ version: 3, config: { name: 'Combine' } })

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
const fetchA = node({ type: 'n8n-nodes-base.httpRequest', version: 5, config: { name: 'Fetch A', parameters: { url: 'https://a.api' } } })
const fetchB = node({ type: 'n8n-nodes-base.httpRequest', version: 5, config: { name: 'Fetch B', parameters: { url: 'https://b.api' } } })
const combiner = merge({ version: 3, config: { name: 'Combine', parameters: { mode: 'append' } } })
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

**NEVER guess or invent node type strings.** Always look up the real type and version from the n8n registry.

### Official Nodes: `GET https://api.n8n.io/api/nodes`

Returns all built-in n8n nodes. Use `attributes.name` as the `type` and `attributes.version` as the `version` in `node()` / `trigger()`.

**Response structure:**
```json
{
  "data": [
    {
      "id": 1242,
      "attributes": {
        "name": "n8n-nodes-base.slack",        // ← Use this as `type`
        "displayName": "Slack",
        "version": 2.2,                         // ← Use this as `version`
        "description": "Send messages to Slack",
        "group": "transform"
      }
    }
  ]
}
```

**How to search:** Fetch the full list and filter by `attributes.displayName` or `attributes.name` containing the service name.

### Community Nodes: `GET https://api.n8n.io/api/community-nodes`

Returns community-contributed nodes. Use `attributes.nodeDescription.name` as the `type`.

**Response structure:**
```json
{
  "data": [
    {
      "id": 456,
      "attributes": {
        "packageName": "@mendable/n8n-nodes-firecrawl",  // ← User must install this
        "nodeDescription": {
          "name": "@mendable/n8n-nodes-firecrawl.firecrawl",  // ← Use this as `type`
          "displayName": "Firecrawl",
          "version": 2,                                        // ← Use this as `version`
          "description": "Scrape websites using Firecrawl API"
        },
        "isOfficialNode": true
      }
    }
  ]
}
```

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
2. Fetch `https://api.n8n.io/api/nodes` → search by name
3. If found → use `attributes.name` and `attributes.version`
4. If NOT found → fetch `https://api.n8n.io/api/community-nodes` → search by name
5. If found in community → use the type + add a `sticky()` note with the `packageName`
6. If NOT found anywhere → tell the user the node doesn't exist, do not invent one

### Core Utility Nodes (Safe Without Lookup)

These fundamental nodes are always available and don't need a registry lookup:

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

**For ANY integration node not in this list** (Slack, Gmail, Notion, Airtable, Google Sheets, Postgres, Stripe, etc.), you MUST look up the correct `type` and `version` from the registry API.
