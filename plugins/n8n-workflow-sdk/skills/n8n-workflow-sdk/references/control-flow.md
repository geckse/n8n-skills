# Control Flow Reference

Complete reference for IF/Else, Switch/Case, Split in Batches, Merge, and error handling patterns in the `@n8n/workflow-sdk`.

## Table of Contents

- [IF/Else Branching](#ifelse-branching)
- [Switch/Case Branching](#switchcase-branching)
- [Merge Node](#merge-node)
- [Split In Batches](#split-in-batches)
- [Error Handling](#error-handling)
- [Combined Control Flow Example](#combined-control-flow-example)
- [Nested Control Flow](#nested-control-flow)

## IF/Else Branching

### Using the Fluent API (Recommended)

```typescript
import { node, workflow } from '@n8n/workflow-sdk'

const ifNode = node({
  type: 'n8n-nodes-base.if',
  version: 2.3,
  config: {
    name: 'Check Status',
    parameters: {
      conditions: {
        options: { caseSensitive: true, leftValue: '', typeValidation: 'loose', version: 2 },
        combinator: 'and',
        conditions: [{
          id: 'status-check',
          leftValue: '={{ $json.status }}',
          rightValue: 'active',
          operator: { type: 'string', operation: 'equals' }
        }]
      },
      options: {}
    }
  }
})

const trueNode = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Active Path' } })
const falseNode = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Inactive Path' } })
const endNode = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Continue' } })

// Fluent API: .onTrue() and .onFalse() on the IF node
const wf = workflow('id', 'IF Example')
  .add(triggerNode)
  .to(ifNode.onTrue(trueNode).onFalse(falseNode))
  .to(endNode)  // Both branches converge here
```

### Branch Targets

Targets for `.onTrue()`, `.onFalse()`, and `.onCase()` can be:

```typescript
// null — no connection
ifNode.onTrue(null).onFalse(falseNode)

// Single node
ifNode.onTrue(nodeA)

// Node chain
ifNode.onTrue(nodeA.to(nodeB).to(nodeC))

// Array (fan-out to parallel nodes)
ifNode.onTrue([nodeA, nodeB])

// Nested builders (IF inside IF)
ifNode.onTrue(innerIf.onTrue(deepTrue).onFalse(deepFalse))
```

### Using the Factory Function

```typescript
import { ifElse } from '@n8n/workflow-sdk'

// ifElse() creates the IF node directly
const ifComposite = ifElse({
  version: 2.3,
  config: {
    name: 'Check',
    parameters: { /* conditions */ }
  }
})

// Then use fluent API
ifComposite.onTrue(trueNode).onFalse(falseNode)
```

### IfElseBuilder Properties and Methods

| Property/Method | Type | Description |
|----------------|------|-------------|
| `_isIfElseBuilder` | `true` | Identifier marker |
| `ifNode` | `NodeInstance` | The underlying IF node |
| `trueBranch` | `IfElseTarget` | Current true branch target |
| `falseBranch` | `IfElseTarget` | Current false branch target |
| `onTrue(target)` | `IfElseBuilder` | Set true branch (output 0) |
| `onFalse(target)` | `IfElseBuilder` | Set false branch (output 1) |
| `to(target)` | `NodeChain` | Chain after both branches converge |

## Switch/Case Branching

### Using the Fluent API (Recommended)

```typescript
import { node, workflow } from '@n8n/workflow-sdk'

const switchNode = node({
  type: 'n8n-nodes-base.switch',
  version: 3.4,
  config: {
    name: 'Route by Type',
    parameters: {
      rules: {
        values: [
          {
            outputKey: 'typeA',
            renameOutput: true,
            conditions: {
              options: { caseSensitive: true, leftValue: '', typeValidation: 'strict', version: 2 },
              combinator: 'and',
              conditions: [{ id: 'rule-a', leftValue: '={{ $json.type }}', rightValue: 'A', operator: { type: 'string', operation: 'equals' } }]
            }
          },
          {
            outputKey: 'typeB',
            renameOutput: true,
            conditions: {
              options: { caseSensitive: true, leftValue: '', typeValidation: 'strict', version: 2 },
              combinator: 'and',
              conditions: [{ id: 'rule-b', leftValue: '={{ $json.type }}', rightValue: 'B', operator: { type: 'string', operation: 'equals' } }]
            }
          },
          {
            outputKey: 'typeC',
            renameOutput: true,
            conditions: {
              options: { caseSensitive: true, leftValue: '', typeValidation: 'strict', version: 2 },
              combinator: 'and',
              conditions: [{ id: 'rule-c', leftValue: '={{ $json.type }}', rightValue: 'C', operator: { type: 'string', operation: 'equals' } }]
            }
          }
        ]
      },
      options: { fallbackOutput: 'extra' }  // 'extra' adds a fallback output, 'none' drops unmatched
    }
  }
})

const caseA = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Handle A' } })
const caseB = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Handle B' } })
const caseC = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Handle C' } })
const converge = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Continue' } })

const wf = workflow('id', 'Switch Example')
  .add(triggerNode)
  .to(switchNode.onCase(0, caseA).onCase(1, caseB).onCase(2, caseC))
  .to(converge)
```

### Using the Factory Function

```typescript
import { switchCase } from '@n8n/workflow-sdk'

const sw = switchCase({
  version: 3.4,
  config: { name: 'Router', parameters: { /* rules */ } }
})

sw.onCase(0, handlerA).onCase(1, handlerB)
```

### SwitchCaseBuilder Properties and Methods

| Property/Method | Type | Description |
|----------------|------|-------------|
| `_isSwitchCaseBuilder` | `true` | Identifier marker |
| `switchNode` | `NodeInstance` | The underlying Switch node |
| `caseMapping` | `Map<number, target>` | Map from output index to target |
| `onCase(index, target)` | `SwitchCaseBuilder` | Set case target (0-based) |
| `to(target)` | `NodeChain` | Chain after all cases converge |

## Merge Node

Combines multiple input branches into a single flow.

### Using the Factory Function

```typescript
import { merge, workflow } from '@n8n/workflow-sdk'

const mergeNode = merge({
  version: 3.2,
  config: {
    name: 'Combine Results',
    parameters: { mode: 'append' }  // 'append' | 'combine' | 'chooseBranch'
  }
})
```

### Multi-Input Connections

```typescript
const wf = workflow('id', 'Merge Example')
  .add(sourceA)
  .to(mergeNode.input(0))       // sourceA → merge input 0
  .add(sourceB)
  .to(mergeNode.input(1))       // sourceB → merge input 1
  .add(mergeNode)
  .to(outputNode)
```

### With Explicit Connect

```typescript
const wf = workflow('id', 'Merge Example')
  .add(sourceA)
  .add(sourceB)
  .add(mergeNode)
  .connect(sourceA, 0, mergeNode, 0)
  .connect(sourceB, 0, mergeNode, 1)
  .add(mergeNode)
  .to(outputNode)
```

### Three-Way Merge

```typescript
const wf = workflow('id', 'Three-Way Merge')
  .add(sourceA).to(mergeNode.input(0))
  .add(sourceB).to(mergeNode.input(1))
  .add(sourceC).to(mergeNode.input(2))
  .add(mergeNode).to(outputNode)
```

## Split In Batches

Processes items in batches with a loop pattern.

### Using the Factory Function

```typescript
import { splitInBatches, nextBatch, workflow, node } from '@n8n/workflow-sdk'

const sib = splitInBatches({
  version: 3,
  config: {
    name: 'Process Batches',
    parameters: { batchSize: 10 }
  }
})

const processNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: { name: 'Process Batch', parameters: { url: 'https://api.example.com/batch' } }
})

const finalNode = node({
  type: 'n8n-nodes-base.set', version: 3.4,
  config: { name: 'Finalize' }
})

// Build the loop
const sibBuilder = sib
  .onEachBatch(processNode.to(nextBatch(sib)))  // Loop back after processing
  .onDone(finalNode)                              // Execute when all batches done

const wf = workflow('id', 'Batch Processing')
  .add(triggerNode)
  .to(sibBuilder)
```

### SplitInBatchesBuilder Methods

| Method | Description |
|--------|-------------|
| `onEachBatch(target)` | Set the "each batch" branch (output 1). Must loop back to SIB |
| `onDone(target)` | Set the "done" branch (output 0). Runs after all batches |

### nextBatch() Helper

`nextBatch(sib)` is a helper that returns the SIB node instance for creating the loop-back connection:

```typescript
import { nextBatch } from '@n8n/workflow-sdk'

// These are equivalent:
processNode.to(nextBatch(sib))
processNode.to(sib.sibNode)  // Direct access
```

### Complex Batch Processing

```typescript
const sib = splitInBatches({ version: 3, config: { parameters: { batchSize: 5 } } })

const fetch = node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: { name: 'Fetch', parameters: { url: '...', options: {} } } })
const transform = node({ type: 'n8n-nodes-base.code', version: 2, config: { name: 'Transform', parameters: { jsCode: 'return items.map(item => ({ json: { ...item.json, processed: true } }))' } } })
const save = node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: { name: 'Save', parameters: { url: '...', method: 'POST', sendBody: true, specifyBody: 'json', jsonBody: '={{ JSON.stringify($json) }}', options: {} } } })
const report = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Report' } })

const sibBuilder = sib
  .onEachBatch(
    fetch.to(transform).to(save).to(nextBatch(sib))
  )
  .onDone(report)

const wf = workflow('id', 'Complex Batch')
  .add(triggerNode)
  .to(sibBuilder)
```

## Error Handling

### Node-Level Error Handling

```typescript
const riskyNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 4.4,
  config: {
    name: 'Risky API Call',
    parameters: { url: 'https://unreliable-api.com' },
    onError: 'continueErrorOutput'  // Route errors to error output
  }
})

const errorHandler = node({
  type: 'n8n-nodes-base.set', version: 3.4,
  config: {
    name: 'Handle Error',
    parameters: { mode: 'manual', assignments: { assignments: [{ name: 'error', value: true, type: 'boolean' }] }, options: {} }
  }
})

// Connect error handler
riskyNode.onError(errorHandler)

const wf = workflow('id', 'Error Handling')
  .add(triggerNode)
  .to(riskyNode)
  .to(successNode)        // Main flow continues here
  .add(errorHandler)       // Error handler must also be added
  .to(notifyNode)          // Error flow continues here
```

### onError Options

| Value | Behavior |
|-------|----------|
| `'stopWorkflow'` | Stop execution on error (default) |
| `'continueRegularOutput'` | Continue to regular output, ignore error |
| `'continueErrorOutput'` | Route to error output (use with `.onError()`) |

## Combined Control Flow Example

```typescript
import {
  workflow, node, trigger, merge, splitInBatches, nextBatch,
  validateWorkflow
} from '@n8n/workflow-sdk'

const start = trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: {} })

// IF branching
const checkType = node({
  type: 'n8n-nodes-base.if', version: 2.3,
  config: {
    name: 'Is Bulk?',
    parameters: {
      conditions: {
        options: { caseSensitive: true, leftValue: '', typeValidation: 'loose', version: 2 },
        combinator: 'and',
        conditions: [{
          id: 'bulk-check',
          leftValue: '={{ $json.items.length }}',
          rightValue: '10',
          operator: { type: 'number', operation: 'gt' }
        }]
      },
      options: {}
    }
  }
})

// Bulk path: batch processing
const sib = splitInBatches({ version: 3, config: { parameters: { batchSize: 5 } } })
const processBatch = node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: { name: 'Process Batch', parameters: { url: '...' } } })
const batchDone = node({ type: 'n8n-nodes-base.noOp', version: 1, config: { name: 'Batch Complete' } })
const sibBuilder = sib
  .onEachBatch(processBatch.to(nextBatch(sib)))
  .onDone(batchDone)

// Single path: direct processing
const processSingle = node({ type: 'n8n-nodes-base.httpRequest', version: 4.4, config: { name: 'Process Single', parameters: { url: '...' } } })

// Merge results
const combiner = merge({ version: 3.2, config: { name: 'Combine' } })
const output = node({ type: 'n8n-nodes-base.respondToWebhook', version: 1.5, config: { name: 'Respond' } })

const wf = workflow('complex-flow', 'Complex Control Flow')
  .add(start)
  .to(checkType.onTrue(sibBuilder).onFalse(processSingle))
  .to(combiner)
  .to(output)

const result = validateWorkflow(wf)
```

## Nested Control Flow

IF inside IF, Switch inside IF, etc.:

```typescript
const outerIf = node({ type: 'n8n-nodes-base.if', version: 2.3, config: { name: 'Outer Check' } })
const innerIf = node({ type: 'n8n-nodes-base.if', version: 2.3, config: { name: 'Inner Check' } })

// Nested: outer true → inner IF → branches
outerIf
  .onTrue(
    innerIf.onTrue(deepTrueNode).onFalse(deepFalseNode)
  )
  .onFalse(outerFalseNode)
```

Switch inside IF:

```typescript
const ifNode = node({ type: 'n8n-nodes-base.if', version: 2.3, config: { name: 'Check' } })
const switchNode = node({ type: 'n8n-nodes-base.switch', version: 3.4, config: { name: 'Route' } })

ifNode
  .onTrue(switchNode.onCase(0, caseA).onCase(1, caseB))
  .onFalse(fallbackNode)
```
