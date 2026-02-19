# Validation and Testing Reference

Complete reference for workflow validation, pin data generation, testing strategies, and error resolution in the `@n8n/workflow-sdk`.

## Table of Contents

- [Workflow Validation](#workflow-validation)
- [All Validation Error Codes](#all-validation-error-codes)
- [Pin Data and Test Data](#pin-data-and-test-data)
- [Testing Strategies](#testing-strategies)
- [Validation with Schema Support](#validation-with-schema-support)
- [Creating Custom Validation](#creating-custom-validation)
- [Complete Testing Example](#complete-testing-example)

## Workflow Validation

### Basic Validation

```typescript
import { validateWorkflow } from '@n8n/workflow-sdk'

// Validate a WorkflowBuilder
const result = validateWorkflow(wf)

// Validate workflow JSON directly
const result = validateWorkflow(workflowJSON)

// Check results
if (result.valid) {
  console.log('Workflow is valid!')
} else {
  for (const error of result.errors) {
    console.error(`ERROR [${error.code}]: ${error.message}`)
    if (error.nodeName) console.error(`  Node: ${error.nodeName}`)
    if (error.parameterName) console.error(`  Parameter: ${error.parameterName}`)
  }
}

for (const warning of result.warnings) {
  console.warn(`WARNING [${warning.code}]: ${warning.message}`)
}
```

### Validation on the Builder

```typescript
const wf = workflow('id', 'name').add(trigger).to(node1)

// Same as validateWorkflow(wf) but called on the builder
const result = wf.validate()
const result = wf.validate({ strictMode: true })
```

### Validation Options

```typescript
const result = validateWorkflow(wf, {
  allowDisconnectedNodes: false,   // Allow nodes not connected to flow
  allowNoTrigger: false,           // Allow workflows without a trigger
  validateSchema: true,            // Validate node parameters against schemas
  strictMode: false,               // Enable strict validation rules
  nodeTypesProvider: provider       // Optional: INodeTypes for schema validation
})
```

| Option | Default | Description |
|--------|---------|-------------|
| `allowDisconnectedNodes` | `false` | If `true`, disconnected nodes don't produce errors |
| `allowNoTrigger` | `false` | If `true`, missing trigger doesn't produce errors |
| `validateSchema` | `true` | Validate node parameters against registered schemas |
| `strictMode` | `false` | Enable stricter validation rules |
| `nodeTypesProvider` | `undefined` | `INodeTypes` from n8n-workflow for schema lookups |

### ValidationResult

```typescript
interface ValidationResult {
  valid: boolean                    // true if no errors (warnings are OK)
  errors: ValidationError[]         // Fatal issues that prevent execution
  warnings: ValidationWarning[]     // Non-fatal issues and best practice violations
}
```

### ValidationError

```typescript
class ValidationError {
  code: ValidationErrorCode          // Error code (e.g., 'MISSING_TRIGGER')
  message: string                    // Human-readable error message
  nodeName?: string                  // Name of the node with the error
  parameterName?: string             // Name of the problematic parameter
  violationLevel?: 'critical' | 'major' | 'minor'
}
```

### ValidationWarning

```typescript
class ValidationWarning {
  code: ValidationErrorCode          // Warning code
  message: string                    // Human-readable warning message
  nodeName?: string                  // Name of the node with the warning
  parameterPath?: string             // Path to the problematic parameter
  originalName?: string              // Original node name (if auto-renamed)
  violationLevel?: 'critical' | 'major' | 'minor'
}
```

## All Validation Error Codes

### Structure Errors

| Code | Severity | Description | Resolution |
|------|----------|-------------|------------|
| `NO_NODES` | Critical | Workflow has no nodes | Add at least one node |
| `MISSING_TRIGGER` | Major | No trigger node found | Add a trigger (manual, webhook, schedule, etc.) |
| `DISCONNECTED_NODE` | Major | Node not connected to any flow | Connect or remove the node |
| `CIRCULAR_REFERENCE` | Critical | Circular connection detected | Break the cycle (except in SplitInBatches loops) |
| `MAX_NODES_EXCEEDED` | Major | Too many nodes in workflow | Reduce node count or split into sub-workflows |

### Connection Errors

| Code | Severity | Description | Resolution |
|------|----------|-------------|------------|
| `INVALID_CONNECTION` | Major | Invalid connection between nodes | Fix connection types or indices |
| `INVALID_INPUT_INDEX` | Major | Input index doesn't exist on target | Use a valid input index |
| `MERGE_SINGLE_INPUT` | Minor | Merge node has only one input | Connect a second input or use a different node |

### Parameter Errors

| Code | Severity | Description | Resolution |
|------|----------|-------------|------------|
| `MISSING_PARAMETER` | Major | Required parameter not set | Set the required parameter |
| `INVALID_PARAMETER` | Major | Parameter value is invalid | Fix the parameter value |
| `MISSING_EXPRESSION_PREFIX` | Minor | Expression missing `=` prefix | Add `=` prefix: `'={{ ... }}'` |
| `HARDCODED_CREDENTIALS` | Major | Credentials hardcoded in parameters | Use `credentials` config instead |
| `SET_CREDENTIAL_FIELD` | Minor | Credential set as field value | Move to credentials config |

### Expression Errors

| Code | Severity | Description | Resolution |
|------|----------|-------------|------------|
| `INVALID_EXPRESSION` | Major | Malformed expression | Fix expression syntax |
| `INVALID_EXPRESSION_PATH` | Minor | Invalid path in expression | Fix the property path |
| `PARTIAL_EXPRESSION_PATH` | Minor | Incomplete expression path | Complete the property path |
| `INVALID_DATE_METHOD` | Minor | Invalid date method in expression | Use a valid date method |

### AI/Agent Errors

| Code | Severity | Description | Resolution |
|------|----------|-------------|------------|
| `AGENT_STATIC_PROMPT` | Minor | AI agent has a static prompt | Use expressions for dynamic prompts |
| `AGENT_NO_SYSTEM_MESSAGE` | Minor | AI agent missing system message | Add a system message |
| `TOOL_NO_PARAMETERS` | Minor | Tool has no AI-driven parameters | Add `fromAi()` parameters |
| `FROM_AI_IN_NON_TOOL` | Major | `fromAi()` used outside tool node | Only use in tool nodes |

### Subnode Errors

| Code | Severity | Description | Resolution |
|------|----------|-------------|------------|
| `SUBNODE_NOT_CONNECTED` | Major | Subnode not connected to parent | Connect via `subnodes` config |
| `SUBNODE_PARAMETER_MISMATCH` | Minor | Subnode parameter doesn't match parent | Fix subnode parameters |
| `UNSUPPORTED_SUBNODE_INPUT` | Major | Parent doesn't support this subnode type | Use a compatible subnode type |

## Pin Data and Test Data

### What is Pin Data?

Pin data is mock output data attached to nodes. When present, n8n uses the pinned data instead of actually executing the node. This enables:

1. **Testing** — Run workflows without real API calls
2. **Development** — Work on downstream nodes with predictable data
3. **Debugging** — Isolate issues by controlling node outputs

### Declaring Output Shapes

Add `output` to node configs to declare expected output:

```typescript
const httpNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    name: 'Get Users',
    parameters: { url: 'https://api.example.com/users', method: 'GET' },
    output: [
      { json: { id: 1, name: 'Alice', email: 'alice@example.com', active: true } },
      { json: { id: 2, name: 'Bob', email: 'bob@example.com', active: false } }
    ]
  }
})
```

### Generating Pin Data

```typescript
const wf = workflow('id', 'Test Workflow')
  .add(trigger)
  .to(httpNode)
  .to(transformNode)
  .generatePinData()  // Converts all output declarations to pinData

const json = wf.toJSON()
// json.pinData = {
//   'Get Users': [
//     { json: { id: 1, name: 'Alice', ... } },
//     { json: { id: 2, name: 'Bob', ... } }
//   ],
//   'Transform': [...]
// }
```

### Generate Pin Data for New Nodes Only

When modifying an existing workflow, only generate pin data for newly added nodes:

```typescript
const existingJSON = { /* existing workflow JSON */ }
const wf = workflow.fromJSON(existingJSON)

// ... add new nodes ...

wf.generatePinData({ beforeWorkflow: existingJSON })
// Only generates pinData for nodes not in existingJSON
```

### Manual Pin Data

You can also set pinData directly on node config:

```typescript
const httpNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    name: 'Get Users',
    parameters: { url: '...', method: 'GET' },
    pinData: [
      { json: { id: 1, name: 'Alice' } },
      { json: { id: 2, name: 'Bob' } }
    ]
  }
})
```

The difference between `pinData` and `output`:
- `pinData` — Directly sets mock data on the node (appears in JSON output)
- `output` — Declares expected output shape; converted to `pinData` by `generatePinData()`

## Testing Strategies

### Strategy 1: Build → Validate → Assert

```typescript
import { workflow, node, trigger, validateWorkflow } from '@n8n/workflow-sdk'

// Build the workflow
const wf = workflow('test-1', 'Test Workflow')
  .add(trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: {} }))
  .to(node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: {
    parameters: { url: 'https://api.example.com', method: 'GET' }
  }}))

// Validate
const result = validateWorkflow(wf)

// Assert
console.assert(result.valid === true, 'Workflow should be valid')
console.assert(result.errors.length === 0, 'Should have no errors')
```

### Strategy 2: Build → Pin Data → Export → Verify JSON

```typescript
// Build with output declarations
const wf = workflow('test-2', 'Test Workflow')
  .add(trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: {} }))
  .to(node({
    type: 'n8n-nodes-base.httpRequest', version: 4.4,
    config: {
      name: 'Fetch Data',
      parameters: { url: 'https://api.example.com', method: 'GET' },
      output: [{ json: { id: 1, status: 'active' } }]
    }
  }))
  .generatePinData()

// Export and verify
const json = wf.toJSON()

console.assert(json.pinData !== undefined, 'Should have pin data')
console.assert(json.pinData['Fetch Data'] !== undefined, 'Should have pin data for Fetch Data')
console.assert(json.pinData['Fetch Data'][0].json.id === 1, 'Pin data should match output declaration')
```

### Strategy 3: JSON → Code → JSON Round-Trip

```typescript
import { generateWorkflowCode, parseWorkflowCode } from '@n8n/workflow-sdk'

// Start with JSON
const originalJSON = wf.toJSON()

// Convert to code
const code = generateWorkflowCode(originalJSON)

// Parse back to JSON
const roundTrippedJSON = parseWorkflowCode(code)

// Verify round-trip
console.assert(
  roundTrippedJSON.nodes.length === originalJSON.nodes.length,
  'Node count should match'
)
```

### Strategy 4: Validate → Fix → Re-Validate

```typescript
// Build a workflow that might have issues
const wf = workflow('test-3', 'Test Workflow')
  .add(node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: {
    parameters: { url: 'https://api.example.com' }
  }}))

// First validation — expect errors
const result1 = validateWorkflow(wf)
console.assert(!result1.valid, 'Should have validation errors')
console.assert(
  result1.errors.some(e => e.code === 'MISSING_TRIGGER'),
  'Should warn about missing trigger'
)

// Fix: add a trigger
const fixedWf = workflow('test-3-fixed', 'Fixed Workflow')
  .add(trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: {} }))
  .to(node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: {
    parameters: { url: 'https://api.example.com' }
  }}))

// Re-validate
const result2 = validateWorkflow(fixedWf)
console.assert(result2.valid, 'Fixed workflow should be valid')
```

### Strategy 5: Code → Builder → Validate → JSON

```typescript
import { parseWorkflowCodeToBuilder, validateWorkflow } from '@n8n/workflow-sdk'

// Parse code into a builder (allows validation)
const builder = parseWorkflowCodeToBuilder(sdkCode)

// Validate before exporting
const result = validateWorkflow(builder)
if (!result.valid) {
  throw new Error(`Validation failed: ${result.errors.map(e => e.message).join(', ')}`)
}

// Safe to export
const json = builder.toJSON()
```

## Validation with Schema Support

### Setting Schema Base Directories

```typescript
import { setSchemaBaseDirs, validateWorkflow } from '@n8n/workflow-sdk'

// Tell the validator where to find node schemas
setSchemaBaseDirs(['/path/to/n8n/node-schemas'])

// Now validation can check parameters against schemas
const result = validateWorkflow(wf, { validateSchema: true })
```

### Using a NodeTypesProvider

```typescript
const result = validateWorkflow(wf, {
  validateSchema: true,
  nodeTypesProvider: myNodeTypesInstance  // INodeTypes from n8n-workflow
})
```

## Creating Custom Validation

Use the plugin system to add custom validators:

```typescript
import { PluginRegistry, workflow } from '@n8n/workflow-sdk'

const registry = new PluginRegistry()

registry.registerValidator({
  id: 'my-custom-validator',
  name: 'Custom Workflow Validator',
  priority: 10,
  validateNode(node, graphNode, ctx) {
    const issues = []
    // Custom validation logic
    if (node.type === 'n8n-nodes-base.httpRequest' && !node.parameters?.url) {
      issues.push({
        code: 'MISSING_PARAMETER',
        message: 'HTTP Request node must have a URL',
        severity: 'error',
        nodeName: node.name
      })
    }
    return issues
  },
  validateWorkflow(ctx) {
    const issues = []
    // Workflow-level validation
    if (ctx.nodes.size > 50) {
      issues.push({
        code: 'MAX_NODES_EXCEEDED',
        message: 'Workflow has too many nodes (max 50)',
        severity: 'warning'
      })
    }
    return issues
  }
})

const wf = workflow('id', 'name', { registry })
// Custom validators run during validation
```

## Complete Testing Example

```typescript
import {
  workflow, node, trigger, merge,
  languageModel, tool, fromAi,
  validateWorkflow, generateWorkflowCode, parseWorkflowCode
} from '@n8n/workflow-sdk'

// ===== TEST: Build and validate a complete AI workflow =====

const model = languageModel({
  type: '@n8n/n8n-nodes-langchain.lmChatOpenAi', version: 1.3,
  config: {
    parameters: {
      model: { __rl: true, mode: 'list', value: 'gpt-4o', cachedResultName: 'gpt-4o' },
      options: {}
    },
    credentials: { openAiApi: { name: 'OpenAI', id: 'cred-123' } }
  }
})

const searchTool = tool({
  type: 'n8n-nodes-base.httpRequestTool', version: 1,
  config: {
    name: 'Search API',
    parameters: {
      url: 'https://api.example.com/search',
      queryParameters: {
        parameters: [{ name: 'q', value: fromAi('query', 'Search query') }]
      }
    },
    output: [{ json: { results: [{ title: 'Result 1' }] } }]
  }
})

const agent = node({
  type: '@n8n/n8n-nodes-langchain.agent', version: 3.1,
  config: {
    name: 'Research Agent',
    parameters: {
      promptType: 'define',
      text: '={{ $json.chatInput }}',
      options: { systemMessage: 'You are a research assistant.' }
    },
    subnodes: { model, tools: [searchTool] }
  }
})

const wf = workflow('ai-test', 'AI Test Workflow')
  .add(trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: {} }))
  .to(agent)
  .generatePinData()

// TEST 1: Validation
const result = validateWorkflow(wf)
console.assert(result.valid, `Expected valid, got errors: ${JSON.stringify(result.errors)}`)

// TEST 2: JSON export
const json = wf.toJSON()
console.assert(json.nodes.length >= 3, 'Should have trigger + agent + model + tool nodes')
console.assert(json.pinData !== undefined, 'Should have pin data')

// TEST 3: Round-trip
const code = generateWorkflowCode(json)
console.assert(code.includes('workflow'), 'Generated code should contain workflow builder')
const roundTripped = parseWorkflowCode(code)
console.assert(roundTripped.nodes.length === json.nodes.length, 'Node count should match')

// TEST 4: Validate round-tripped
const result2 = validateWorkflow(roundTripped)
console.assert(result2.valid, 'Round-tripped workflow should be valid')

console.log('All tests passed!')
```
