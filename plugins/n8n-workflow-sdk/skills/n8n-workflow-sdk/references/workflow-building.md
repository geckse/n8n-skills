# Workflow Building Reference

Complete patterns for creating, importing, exporting, and configuring workflows with the `@n8n/workflow-sdk`.

## Creating a Workflow

### Basic Creation

```typescript
import { workflow, node, trigger } from '@n8n/workflow-sdk'

const wf = workflow('workflow-id', 'My Workflow Name')
```

**Parameters:**
- `id` (string) — Unique workflow identifier
- `name` (string) — Human-readable workflow name
- `options` (optional) — `WorkflowSettings` or `WorkflowBuilderOptions`

### With Options

```typescript
import { workflow, PluginRegistry } from '@n8n/workflow-sdk'

// With settings directly
const wf = workflow('id', 'name', {
  timezone: 'America/New_York',
  executionOrder: 'v1'
})

// With full options (settings + plugin registry)
const registry = new PluginRegistry()
const wf = workflow('id', 'name', {
  settings: { timezone: 'UTC' },
  registry
})
```

## Importing from JSON

```typescript
import { workflow } from '@n8n/workflow-sdk'

// From a JavaScript object
const wf = workflow.fromJSON(workflowJSON)

// From a string (parse first)
const wf = workflow.fromJSON(JSON.parse(jsonString))
```

The `fromJSON` method accepts any valid n8n `WorkflowJSON` object:

```typescript
interface WorkflowJSON {
  id?: string
  name: string
  nodes: NodeJSON[]
  connections: IConnections
  settings?: WorkflowSettings
  pinData?: Record<string, IDataObject[]>
  meta?: { templateId?: string; instanceId?: string }
}
```

## Building the Workflow Graph

### Adding Nodes

```typescript
const wf = workflow('id', 'name')
  .add(triggerNode)    // Add the trigger
  .add(processNode)    // Add another node (unconnected)
```

`.add()` accepts:
- `NodeInstance` — A single node
- `TriggerInstance` — A trigger node
- `NodeChain` — A chain of pre-connected nodes
- `IfElseBuilder` — An IF/else composite
- `SwitchCaseBuilder` — A Switch/case composite

### Connecting Nodes

#### Sequential: `.to()`

```typescript
const wf = workflow('id', 'name')
  .add(triggerNode)
  .to(httpNode)        // trigger → http
  .to(setNode)         // http → set
  .to(respondNode)     // set → respond
```

#### Fan-Out: `.to(array)`

```typescript
const wf = workflow('id', 'name')
  .add(triggerNode)
  .to([branchA, branchB, branchC])
  // trigger output 0 → branchA
  // trigger output 1 → branchB
  // trigger output 2 → branchC
```

#### Multi-Input: `.input(index)`

```typescript
const mergeNode = merge({ version: 3.2, config: { name: 'Merge Results' } })

const wf = workflow('id', 'name')
  .add(sourceA)
  .to(mergeNode.input(0))   // sourceA → merge input 0
  .add(sourceB)
  .to(mergeNode.input(1))   // sourceB → merge input 1
  .add(mergeNode)
  .to(outputNode)
```

#### Explicit Indexed: `.connect()`

```typescript
const wf = workflow('id', 'name')
  .add(nodeA)
  .add(nodeB)
  .connect(nodeA, 0, nodeB, 0)  // nodeA output 0 → nodeB input 0
  .connect(nodeA, 1, nodeB, 1)  // nodeA output 1 → nodeB input 1
```

**Parameters:**
- `source` — Source NodeInstance
- `sourceOutput` — Output index on source (0-based)
- `target` — Target NodeInstance
- `targetInput` — Input index on target (0-based)

#### Pre-Built Chains

```typescript
// Build a chain first, add to workflow
const processingChain = httpNode.to(transformNode).to(filterNode)

const wf = workflow('id', 'name')
  .add(triggerNode)
  .to(processingChain)  // Adds entire chain
  .to(outputNode)
```

## Workflow Settings

```typescript
const wf = workflow('id', 'name')
  .settings({
    timezone: 'UTC',
    errorWorkflow: 'error-handler-workflow-id',
    saveDataErrorExecution: 'all',       // 'all' | 'none'
    saveDataSuccessExecution: 'all',      // 'all' | 'none'
    saveManualExecutions: true,
    saveExecutionProgress: true,
    executionTimeout: 3600000,            // ms
    executionOrder: 'v1',
    callerPolicy: 'any',                 // 'any' | 'none' | 'workflowsFromAList' | 'workflowsFromSameOwner'
    callerIds: 'id1,id2,id3'
  })
```

## Exporting

### To JSON

```typescript
const json = wf.toJSON()
// Returns: WorkflowJSON object ready for n8n import

// As string
const jsonString = JSON.stringify(wf.toJSON(), null, 2)
```

### To String

```typescript
const str = wf.toString()
// Returns: JSON string representation
```

### To Custom Format (via plugins)

```typescript
const result = wf.toFormat<MyFormat>('myFormat')
// Uses a registered SerializerPlugin with format 'myFormat'
```

## Querying Nodes

```typescript
const myNode = wf.getNode('HTTP Request')
// Returns: NodeInstance | undefined
```

## Generating Test Data

```typescript
// Add output declarations to nodes
const httpNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    output: [
      { json: { id: 1, name: 'Item 1', status: 'active' } },
      { json: { id: 2, name: 'Item 2', status: 'inactive' } }
    ]
  }
})

// Generate pin data from all output declarations
const wf = workflow('id', 'name')
  .add(trigger).to(httpNode)
  .generatePinData()

// With options — only generate for new nodes
const wf2 = workflow('id', 'name')
  .add(trigger).to(httpNode)
  .generatePinData({ beforeWorkflow: existingWorkflowJSON })
```

## Regenerating Node IDs

```typescript
wf.regenerateNodeIds()
// Deterministically regenerates all node IDs using hashing
// Useful for reproducible builds
```

## Validation

```typescript
const result = wf.validate()
// or with options:
const result = wf.validate({
  allowDisconnectedNodes: false,
  allowNoTrigger: false,
  validateSchema: true,
  strictMode: false
})

if (!result.valid) {
  for (const error of result.errors) {
    console.error(`[${error.code}] ${error.message} (node: ${error.nodeName})`)
  }
}
for (const warning of result.warnings) {
  console.warn(`[${warning.code}] ${warning.message}`)
}
```

## Complete Workflow Example

```typescript
import {
  workflow, node, trigger, merge,
  languageModel, tool, fromAi,
  serializeExpression, expr, validateWorkflow
} from '@n8n/workflow-sdk'

// 1. Define trigger
const webhookTrigger = trigger({
  type: 'n8n-nodes-base.webhook', version: 2.1,
  config: {
    name: 'Webhook',
    parameters: { path: 'incoming', httpMethod: 'POST' }
  }
})

// 2. Define processing nodes
const getData = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    name: 'Fetch User',
    parameters: {
      url: serializeExpression($ => $('Webhook').json.userId),
      method: 'GET'
    },
    output: [{ json: { id: '123', name: 'John', email: 'john@example.com' } }]
  }
})

const transform = node({
  type: 'n8n-nodes-base.set', version: 3.4,
  config: {
    name: 'Format Response',
    parameters: {
      mode: 'manual',
      assignments: {
        assignments: [
          { name: 'greeting', value: expr('{{ "Hello " + $json.name }}'), type: 'string' }
        ]
      },
      options: {}
    },
    output: [{ json: { greeting: 'Hello John' } }]
  }
})

const respond = node({
  type: 'n8n-nodes-base.respondToWebhook', version: 1.5,
  config: {
    name: 'Respond',
    parameters: { respondWith: 'json' }
  }
})

// 3. Build workflow
const wf = workflow('webhook-flow', 'Webhook Handler')
  .settings({ timezone: 'UTC', executionOrder: 'v1' })
  .add(webhookTrigger)
  .to(getData)
  .to(transform)
  .to(respond)
  .generatePinData()

// 4. Validate
const validation = validateWorkflow(wf)
console.log('Valid:', validation.valid)
console.log('Errors:', validation.errors.length)
console.log('Warnings:', validation.warnings.length)

// 5. Export
const json = wf.toJSON()
```

## WorkflowJSON Structure

The JSON format produced by `.toJSON()` and consumed by `workflow.fromJSON()`:

```typescript
{
  id: 'workflow-id',
  name: 'Workflow Name',
  nodes: [
    {
      id: 'uuid-...',
      name: 'Webhook',
      type: 'n8n-nodes-base.webhook',
      typeVersion: 2,
      position: [250, 300],
      parameters: { path: 'incoming', httpMethod: 'POST' },
      credentials: {},
      // optional: disabled, notes, notesInFlow, executeOnce,
      //           retryOnFail, alwaysOutputData, onError
    }
  ],
  connections: {
    'Webhook': {
      main: [
        [{ node: 'Fetch User', type: 'main', index: 0 }]
      ]
    },
    'Fetch User': {
      main: [
        [{ node: 'Format Response', type: 'main', index: 0 }]
      ]
    }
  },
  settings: { timezone: 'UTC', executionOrder: 'v1' },
  pinData: {
    'Fetch User': [{ json: { id: '123', name: 'John', email: 'john@example.com' } }],
    'Format Response': [{ json: { greeting: 'Hello John' } }]
  }
}
```
