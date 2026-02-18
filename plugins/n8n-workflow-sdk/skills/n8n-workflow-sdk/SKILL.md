---
name: n8n-workflow-sdk
description: "Builds, tests, validates, and manages n8n workflows programmatically using the @n8n/workflow-sdk. Activates when the user wants to create n8n workflows with code, convert between JSON and code, validate workflows, generate test/pin data, build AI agent workflows, or work with the n8n workflow SDK in any capacity. Also triggers on mentions of workflow-sdk, workflow builder, n8n workflow code, workflow JSON, workflow validation, code generation, or programmatic workflow creation."
---

# n8n Workflow SDK

Build, test, validate, and manage n8n workflows programmatically using the `@n8n/workflow-sdk`. This skill enables code-based workflow construction with full validation, JSON round-tripping, and testing support.

## When You Need More Detail

This skill uses progressive disclosure. The SKILL.md covers the full workflow, decision-making, and quick-reference API. For complete patterns and examples, read these reference files:

- `references/workflow-building.md` — Workflow creation, settings, JSON import/export, and complete building patterns
- `references/nodes-and-connections.md` — All node factories, subnodes (AI/LangChain), connection patterns, and credentials
- `references/control-flow.md` — IF/Else, Switch/Case, Split in Batches, Merge, error handling, and branching
- `references/expressions-and-code.md` — Expression system, Code node helpers, fromAi, and expression context
- `references/validation-and-testing.md` — Workflow validation, pin data, test data generation, and testing strategies
- `references/code-generation.md` — JSON-to-code, code-to-JSON, parseWorkflowCode, and the generation pipeline
- `references/plugins-and-advanced.md` — Plugin system, type generation, Zod schemas, and extensibility

Read the appropriate reference file before writing any code.

## Project Setup

Before writing SDK code, the project needs `@n8n/workflow-sdk` and TypeScript tooling installed. If the project already has these, skip this section.

**For a new project:**

```bash
mkdir my-workflow-project && cd my-workflow-project
npm init -y
npm install @n8n/workflow-sdk
npm install --save-dev typescript tsx @types/node
```

**For an existing project:**

```bash
npm install @n8n/workflow-sdk
npm install --save-dev typescript tsx @types/node
```

**Running workflow scripts:**

```bash
npx tsx src/my-workflow.ts
```

The SDK is a pure TypeScript/JavaScript library — no build step is required. `tsx` runs `.ts` files directly. If the project already uses `ts-node` or another TypeScript runner, that works too.

## CRITICAL: Node Type Lookup — Never Guess Node Types

**DO NOT invent or guess node type identifiers.** n8n has hundreds of nodes, each with a specific `type` string (e.g., `n8n-nodes-base.slack`). Using a wrong or made-up type produces a workflow that fails in n8n.

**Always look up the real node type** from the official n8n node registry before using it:

### Official Nodes Registry

```
GET https://api.n8n.io/api/nodes
```

Returns all built-in n8n nodes. Each entry has:
- `attributes.name` — The **node type identifier** to use in `node()` / `trigger()` (e.g., `"n8n-nodes-base.slack"`, `"@n8n/n8n-nodes-langchain.agent"`)
- `attributes.displayName` — Human-readable name
- `attributes.version` — Current version number
- `attributes.description` — What the node does
- `attributes.group` — `"trigger"` or other classification

**How to find a node:** Fetch the registry and search for the node by display name or description. For example, to find the Slack node, search for entries where `attributes.displayName` or `attributes.name` contains "Slack" or "slack".

### Community Nodes Registry

```
GET https://api.n8n.io/api/community-nodes
```

Returns community-contributed nodes. Each entry has:
- `attributes.nodeDescription.name` — The **node type identifier**
- `attributes.packageName` — The **npm package** the user must install (e.g., `"@mendable/n8n-nodes-firecrawl"`)
- `attributes.nodeDescription.displayName` — Human-readable name
- `attributes.nodeDescription.version` — Version number
- `attributes.isOfficialNode` — Whether verified by n8n

**When using a community node**, the user must install the npm package in their n8n instance first. **Always add a `sticky()` note** to the workflow warning about the required community node package:

```typescript
const installNote = sticky(
  '⚠️ Required Community Node: Install the "@mendable/n8n-nodes-firecrawl" package in your n8n instance (Settings → Community Nodes → Install) before using this workflow.',
  [firecrawlNode],
  { color: 5 }
)
```

### Lookup Workflow

1. **User asks for a specific integration** (e.g., "add a Slack node")
2. **Fetch `https://api.n8n.io/api/nodes`** and search for the matching node
3. **If not found in official nodes**, fetch `https://api.n8n.io/api/community-nodes` and search there
4. **Use the exact `type` and `version`** from the registry in your `node()` / `trigger()` call
5. **If using a community node**, add a `sticky()` note listing the required npm package
6. **If no matching node exists**, tell the user — do not invent a type

### Quick Reference: Core Utility Nodes

These fundamental utility nodes are always safe to use without a registry lookup:

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
| `n8n-nodes-base.noOp` | No operation (passthrough) |
| `n8n-nodes-base.stickyNote` | Canvas annotation |
| `n8n-nodes-base.respondToWebhook` | Respond to webhook |
| `n8n-nodes-base.filter` | Filter items |
| `n8n-nodes-base.executeWorkflow` | Execute sub-workflow |
| `@n8n/n8n-nodes-langchain.agent` | AI Agent |

**For ANY integration node not in this list** (Slack, Gmail, Notion, Airtable, Google Sheets, Postgres, etc.), you MUST look up the correct `type` and `version` from the registry API before using it.

## Core Concepts

The SDK provides a **fluent, chainable API** for building n8n workflows in TypeScript/JavaScript. Instead of hand-crafting JSON, you construct workflows programmatically with full type safety, validation, and testing capabilities.

**Key capabilities:**
1. **Create workflows** — Fluent builder API with `workflow()`, `node()`, `trigger()`
2. **Import existing workflows** — `workflow.fromJSON(json)` loads any n8n workflow JSON
3. **Export to JSON** — `.toJSON()` produces n8n-compatible workflow JSON
4. **Convert JSON to code** — `generateWorkflowCode(json)` produces readable SDK code
5. **Convert code to JSON** — `parseWorkflowCode(code)` parses SDK code back to JSON
6. **Validate** — `validateWorkflow()` checks structure, connections, expressions, and best practices
7. **Test with pin data** — `.generatePinData()` creates mock data from output declarations
8. **Build AI workflows** — Full support for LangChain subnodes (models, tools, memory, etc.)

## Common Workflows

### Pattern 1: Create a New Workflow from Scratch

```typescript
import { workflow, node, trigger, validateWorkflow } from '@n8n/workflow-sdk'

const myTrigger = trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: {} })
const httpNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 5,
  config: {
    parameters: { url: 'https://api.example.com/data', method: 'GET' },
    output: [{ json: { id: 1, name: 'Example' } }]
  }
})

const wf = workflow('my-workflow', 'My Workflow')
  .add(myTrigger)
  .to(httpNode)
  .generatePinData()

const validation = validateWorkflow(wf)
if (validation.valid) {
  const json = wf.toJSON()  // Ready for n8n
}
```

### Pattern 2: Load Existing JSON, Modify, Test, Export

```typescript
import { workflow, node, generateWorkflowCode, validateWorkflow } from '@n8n/workflow-sdk'

// 1. Load from JSON (user provides their workflow JSON)
const wf = workflow.fromJSON(existingWorkflowJSON)

// 2. Convert to code to understand it
const code = generateWorkflowCode(existingWorkflowJSON)

// 3. Modify — add a new node
const newNode = node({
  type: 'n8n-nodes-base.set', version: 3.4,
  config: { name: 'Transform', parameters: { mode: 'manual', fields: { values: [] } } }
})
// Rebuild with modifications using the SDK

// 4. Validate
const result = validateWorkflow(wf)
console.log(result.errors, result.warnings)

// 5. Export back to JSON
const updatedJSON = wf.toJSON()
```

### Pattern 3: Convert JSON to Code, Modify, Convert Back

```typescript
import { generateWorkflowCode, parseWorkflowCode, validateWorkflow } from '@n8n/workflow-sdk'

// JSON → Code (for reading/understanding)
const code = generateWorkflowCode(workflowJSON)

// Modify the code as needed...

// Code → JSON (for importing back to n8n)
const newJSON = parseWorkflowCode(modifiedCode)

// Validate before deploying
const result = validateWorkflow(newJSON)
```

### Pattern 4: Build an AI Agent Workflow

```typescript
import { workflow, node, trigger, languageModel, tool, memory, fromAi } from '@n8n/workflow-sdk'

const model = languageModel({
  type: '@n8n/n8n-nodes-langchain.lmChatOpenAi', version: 1.2,
  config: {
    parameters: { model: 'gpt-4o' },
    credentials: { openAiApi: { name: 'OpenAI', id: 'cred-123' } }
  }
})

const emailTool = tool({
  type: 'n8n-nodes-base.gmailTool', version: 1,
  config: {
    parameters: {
      recipient: fromAi('recipient', 'Email recipient address'),
      subject: fromAi('subject', 'Email subject line')
    }
  }
})

const agent = node({
  type: '@n8n/n8n-nodes-langchain.agent', version: 1.7,
  config: {
    name: 'AI Agent',
    subnodes: { model, tools: [emailTool], memory: memoryNode }
  }
})

const wf = workflow('ai-workflow', 'AI Agent Workflow')
  .add(trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: {} }))
  .to(agent)
```

## SDK API Quick Reference

### Factory Functions

| Function | Purpose | Reference |
|----------|---------|-----------|
| `workflow(id, name, options?)` | Create workflow builder | `references/workflow-building.md` |
| `workflow.fromJSON(json)` | Import from n8n JSON | `references/workflow-building.md` |
| `node(input)` | Create a regular node | `references/nodes-and-connections.md` |
| `trigger(input)` | Create a trigger node | `references/nodes-and-connections.md` |
| `sticky(content, nodes?, config?)` | Create a sticky note | `references/nodes-and-connections.md` |
| `placeholder(hint)` | Create a placeholder value | `references/nodes-and-connections.md` |
| `newCredential(name)` | Mark credential as new | `references/nodes-and-connections.md` |
| `ifElse(config)` | Create IF node | `references/control-flow.md` |
| `switchCase(config)` | Create Switch node | `references/control-flow.md` |
| `merge(config)` | Create Merge node | `references/control-flow.md` |
| `splitInBatches(config)` | Create Split In Batches | `references/control-flow.md` |
| `nextBatch(sib)` | Loop-back for SIB | `references/control-flow.md` |

### Subnode Factories (AI/LangChain)

| Function | Purpose |
|----------|---------|
| `languageModel(input)` | Language model (OpenAI, Anthropic, etc.) |
| `memory(input)` | Memory (Buffer Window, etc.) |
| `tool(input)` | Tool (Calculator, Code, Gmail, etc.) |
| `outputParser(input)` | Output parser |
| `embedding(input)` / `embeddings(input)` | Embedding model |
| `vectorStore(input)` | Vector store (Pinecone, Qdrant, etc.) |
| `retriever(input)` | Retriever |
| `documentLoader(input)` | Document loader |
| `textSplitter(input)` | Text splitter |
| `fromAi(key, description?, type?, defaultValue?)` | AI-driven parameter |

### Expression Utilities

| Function | Purpose |
|----------|---------|
| `serializeExpression(fn)` | `$ => $.json.name` → `={{ $json.name }}` |
| `parseExpression(expr)` | `={{ $json.name }}` → `$json.name` |
| `isExpression(value)` | Check if string is an expression |
| `expr(expression)` | Mark string as expression (adds `=` prefix) |

### Code Helpers

| Function | Purpose |
|----------|---------|
| `runOnceForAllItems(fn)` | Code node: process all items at once |
| `runOnceForEachItem(fn)` | Code node: process one item at a time |

### Validation & Testing

| Function | Purpose |
|----------|---------|
| `validateWorkflow(wf, options?)` | Validate workflow structure |
| `.generatePinData(options?)` | Generate pin/test data from outputs |
| `.validate(options?)` | Validate on the builder directly |

### Code Generation

| Function | Purpose |
|----------|---------|
| `generateWorkflowCode(json)` | JSON → TypeScript SDK code |
| `parseWorkflowCode(code)` | SDK code → JSON |
| `parseWorkflowCodeToBuilder(code)` | SDK code → WorkflowBuilder |

### WorkflowBuilder Methods

| Method | Purpose |
|--------|---------|
| `.add(node)` | Add node to workflow |
| `.to(target)` | Connect current node to target |
| `.connect(src, srcOut, tgt, tgtIn)` | Explicit indexed connection |
| `.settings(settings)` | Set workflow settings |
| `.getNode(name)` | Get node by name |
| `.validate(options?)` | Validate the workflow |
| `.toJSON()` | Export as n8n JSON |
| `.toFormat(format)` | Serialize with plugin |
| `.generatePinData(options?)` | Generate test data |
| `.regenerateNodeIds()` | Regenerate deterministic IDs |

### NodeInstance Methods

| Method | Purpose |
|--------|---------|
| `.to(target, outputIndex?)` | Connect to next node(s) |
| `.input(index)` | Create input target (for Merge) |
| `.output(index)` | Select specific output index |
| `.onTrue(target)` | IF node: true branch |
| `.onFalse(target)` | IF node: false branch |
| `.onCase(index, target)` | Switch node: case branch |
| `.onError(handler)` | Set error handler |
| `.update(config)` | Create updated copy |
| `.getConnections()` | Get declared connections |

## Decision Guide

### When to Use Each Pattern

**Creating a brand-new workflow:**
1. **Look up node types** — Fetch `https://api.n8n.io/api/nodes` (and `/community-nodes` if needed) to get the correct `type` and `version` for every integration node
2. Design the flow (trigger → processing → output)
3. Create nodes with `node()` and `trigger()` using the real types from the registry
4. If using community nodes, add `sticky()` notes listing required npm packages
5. Chain with `.add()` and `.to()`
6. Add output declarations for testing
7. Validate with `validateWorkflow()`
8. Export with `.toJSON()`

**Modifying an existing n8n workflow (JSON):**
1. Load with `workflow.fromJSON(json)`
2. Optionally convert to code with `generateWorkflowCode(json)` to understand it
3. Build the modified version using the SDK
4. Validate the new version
5. Export with `.toJSON()`

**Understanding a complex workflow:**
1. Convert with `generateWorkflowCode(json)` — produces readable TypeScript
2. Read the generated code to understand the flow

**Testing/verifying a workflow:**
1. Build or load the workflow
2. Add `output` declarations to nodes (expected output shapes)
3. Call `.generatePinData()` to create test data
4. Call `validateWorkflow()` to check for errors
5. Review validation errors and warnings

**Round-tripping (code ↔ JSON):**
- JSON → Code: `generateWorkflowCode(json)`
- Code → JSON: `parseWorkflowCode(code)`
- Code → Builder: `parseWorkflowCodeToBuilder(code)` (allows validation before JSON export)

## Connection Patterns Summary

```typescript
// Sequential: A → B → C
workflow('id', 'name').add(a).to(b).to(c)

// Fan-out: A → [B, C, D] (parallel branches, output indices 0, 1, 2)
workflow('id', 'name').add(a).to([b, c, d])

// Multi-input (Merge): A → merge.input(0), B → merge.input(1)
workflow('id', 'name')
  .add(a).to(merge.input(0))
  .add(b).to(merge.input(1))

// Explicit indexed: source output 0 → target input 1
workflow('id', 'name').connect(source, 0, target, 1)

// Output selection: use specific output of a multi-output node
nodeA.output(0).to(nodeB)
nodeA.output(1).to(nodeC)

// IF branching
ifNode.onTrue(trueNode).onFalse(falseNode)

// Switch branching
switchNode.onCase(0, caseA).onCase(1, caseB).onCase(2, caseC)

// Error handling
sourceNode.onError(errorHandler)

// Split in Batches loop
sib.onEachBatch(process.to(nextBatch(sib))).onDone(finalNode)
```

## Validation Error Codes

The SDK validates for 23+ error conditions. Key ones to watch for:

| Code | Meaning |
|------|---------|
| `NO_NODES` | Workflow has no nodes |
| `MISSING_TRIGGER` | No trigger node found |
| `DISCONNECTED_NODE` | Node not connected to flow |
| `INVALID_CONNECTION` | Invalid connection between nodes |
| `MISSING_PARAMETER` | Required parameter missing |
| `CIRCULAR_REFERENCE` | Circular connection detected |
| `INVALID_EXPRESSION` | Malformed expression |
| `AGENT_STATIC_PROMPT` | AI agent has static prompt |
| `HARDCODED_CREDENTIALS` | Credentials hardcoded in parameters |
| `MERGE_SINGLE_INPUT` | Merge node has only one input |
| `TOOL_NO_PARAMETERS` | Tool has no AI-driven parameters |
| `FROM_AI_IN_NON_TOOL` | `fromAi()` used outside a tool node |
| `SUBNODE_NOT_CONNECTED` | Subnode not connected to parent |

See `references/validation-and-testing.md` for the complete list and resolution strategies.

## Node Type Constants

```typescript
import { NODE_TYPES } from '@n8n/workflow-sdk'

NODE_TYPES.IF                  // 'n8n-nodes-base.if'
NODE_TYPES.SWITCH              // 'n8n-nodes-base.switch'
NODE_TYPES.MERGE               // 'n8n-nodes-base.merge'
NODE_TYPES.STICKY_NOTE         // 'n8n-nodes-base.stickyNote'
NODE_TYPES.SPLIT_IN_BATCHES    // 'n8n-nodes-base.splitInBatches'
NODE_TYPES.HTTP_REQUEST        // 'n8n-nodes-base.httpRequest'
NODE_TYPES.WEBHOOK             // 'n8n-nodes-base.webhook'
NODE_TYPES.DATA_TABLE          // 'n8n-nodes-base.dataTable'
```

## Type Guards

```typescript
import {
  isIfNodeType, isSwitchNodeType, isMergeNodeType,
  isStickyNoteType, isSplitInBatchesType, isHttpRequestType,
  isWebhookType, isDataTableType, isNodeChain, isNodeInstance
} from '@n8n/workflow-sdk'
```

## Scope

This skill is for **building and manipulating n8n workflows programmatically** using the `@n8n/workflow-sdk`. It covers workflow creation, JSON import/export, validation, code generation, pin data, and the full SDK API.

**This skill is NOT for:**
- Deploying workflows to n8n instances or managing n8n server configuration
- Building custom n8n community nodes (use the `n8n-node-builder` skill instead)
- Using the n8n UI or REST API directly
- Managing n8n credentials in a running instance

## Best Practices

1. **NEVER guess node types — always look them up** — Fetch `https://api.n8n.io/api/nodes` (official) or `https://api.n8n.io/api/community-nodes` (community) to get the real `type` and `version`. A made-up node type produces a broken workflow. See the "Node Type Lookup" section above.
2. **Flag community nodes with sticky notes** — If the workflow uses community nodes, add a `sticky()` note listing the npm packages the user must install in their n8n instance.
3. **Always validate before exporting** — Call `validateWorkflow()` before `.toJSON()`. The SDK catches 23+ error conditions that would silently produce broken workflows in n8n, so skipping validation means shipping bugs.
4. **Use output declarations for testing** — Add `output` to node configs, then call `generatePinData()`. Without output declarations, there's no way to generate test fixtures automatically, and downstream nodes can't be tested with realistic data shapes.
5. **Use `generateWorkflowCode()` to understand existing workflows** — Raw n8n JSON is verbose and hard to follow. The generated TypeScript code reveals the logical flow, branching, and node relationships at a glance.
6. **Use `parseWorkflowCode()` for round-tripping** — Code → JSON → Code round-trips cleanly, making it safe to convert, edit in code, and convert back without data loss.
7. **Use `parseWorkflowCodeToBuilder()` when you need validation** — Unlike `parseWorkflowCode()` which returns raw JSON, this returns a WorkflowBuilder so you can `.validate()` before `.toJSON()`, catching errors before they reach n8n.
8. **Use credentials objects, not hardcoded values** — Hardcoded API keys in parameters are a security risk and won't work across environments. The validator catches `HARDCODED_CREDENTIALS` to prevent this.
9. **Use `fromAi()` only in tool nodes** — `fromAi()` generates `$fromAI` expressions that only the AI Agent node can resolve. Using them in regular nodes produces expressions that will fail at runtime. The validator catches `FROM_AI_IN_NON_TOOL`.
10. **Use `expr()` for dynamic values** — Raw strings with `={{ }}` are error-prone (missing `=` prefix, unbalanced braces). `expr()` handles the prefix automatically and makes intent clear in code.
11. **Set `output` on nodes to enable pin data generation** — This is how you create test fixtures. Without declared outputs, `generatePinData()` has nothing to convert.
12. **Use `sticky()` for workflow documentation** — Auto-positions around given nodes, making it easy to annotate sections of complex workflows for other developers.
