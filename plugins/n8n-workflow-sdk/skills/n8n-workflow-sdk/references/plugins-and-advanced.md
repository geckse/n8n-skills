# Plugins and Advanced Features Reference

Complete reference for the plugin system, type generation, Zod schema generation, and extensibility in the `@n8n/workflow-sdk`.

## Table of Contents

- [Plugin System](#plugin-system)
- [Validator Plugins](#validator-plugins)
- [Composite Handler Plugins](#composite-handler-plugins)
- [Serializer Plugins](#serializer-plugins)
- [Plugin Utility Functions](#plugin-utility-functions)
- [Type Generation](#type-generation)
- [Zod Schema Generation](#zod-schema-generation)
- [Advanced Patterns](#advanced-patterns)

## Plugin System

The SDK's plugin system provides extensibility through three plugin types:
1. **Validators** — Custom validation rules for nodes and workflows
2. **Composite Handlers** — Custom handling for composite node structures
3. **Serializers** — Custom output format serialization

### PluginRegistry

```typescript
import { PluginRegistry, pluginRegistry, registerDefaultPlugins } from '@n8n/workflow-sdk'

// Global singleton (pre-configured with defaults)
pluginRegistry

// Create a fresh registry
const registry = new PluginRegistry()

// Register defaults (IF, Switch, Merge, SIB handlers + built-in validators)
registerDefaultPlugins(registry)

// Use with workflow builder
const wf = workflow('id', 'name', { registry })
```

### PluginRegistry Methods

| Method | Description |
|--------|-------------|
| `registerValidator(plugin)` | Register a validator plugin |
| `unregisterValidator(id)` | Remove a validator by ID |
| `getValidators()` | Get all validators (sorted by priority) |
| `getValidatorsForNodeType(type)` | Get validators for a specific node type |
| `registerCompositeHandler(plugin)` | Register a composite handler |
| `unregisterCompositeHandler(id)` | Remove a composite handler by ID |
| `getCompositeHandlers()` | Get all composite handlers (sorted by priority) |
| `findCompositeHandler(input)` | Find handler that can process input |
| `isCompositeType(target)` | Check if target is a registered composite |
| `resolveCompositeHeadName(target, nameMapping?)` | Get head node name for composite |
| `registerSerializer(plugin)` | Register a serializer plugin |
| `unregisterSerializer(id)` | Remove a serializer by ID |
| `getSerializer(format)` | Get serializer by format string |
| `clearAll()` | Remove all plugins (useful for testing) |

## Validator Plugins

Custom rules that check nodes and workflows during validation.

### ValidatorPlugin Interface

```typescript
interface ValidatorPlugin {
  id: string                          // Unique identifier
  name: string                        // Human-readable name
  nodeTypes?: string[]                // Node types to validate (empty = all)
  priority?: number                   // Higher = runs first (default: 0)
  validateNode(
    node: NodeJSON,
    graphNode: GraphNode,
    ctx: PluginContext
  ): ValidationIssue[]
  validateWorkflow?(
    ctx: PluginContext
  ): ValidationIssue[]
}
```

### ValidationIssue

```typescript
interface ValidationIssue {
  code: string                         // Error/warning code
  message: string                      // Human-readable message
  severity: 'error' | 'warning'        // error = fatal, warning = non-fatal
  violationLevel?: 'critical' | 'major' | 'minor'
  nodeName?: string                    // Related node name
  parameterPath?: string               // Related parameter path
  originalName?: string                // Original name if auto-renamed
}
```

### Example: Custom Validator

```typescript
const noEmptyNamesValidator: ValidatorPlugin = {
  id: 'no-empty-names',
  name: 'No Empty Node Names',
  priority: 5,

  validateNode(node, graphNode, ctx) {
    const issues: ValidationIssue[] = []
    if (!node.name || node.name.trim() === '') {
      issues.push({
        code: 'EMPTY_NODE_NAME',
        message: `Node of type ${node.type} has an empty name`,
        severity: 'warning',
        nodeName: node.name
      })
    }
    return issues
  }
}

registry.registerValidator(noEmptyNamesValidator)
```

### Example: Node-Type-Specific Validator

```typescript
const httpUrlValidator: ValidatorPlugin = {
  id: 'http-url-required',
  name: 'HTTP URL Required',
  nodeTypes: ['n8n-nodes-base.httpRequest'],  // Only runs for HTTP nodes
  priority: 10,

  validateNode(node, graphNode, ctx) {
    const issues: ValidationIssue[] = []
    if (!node.parameters?.url) {
      issues.push({
        code: 'MISSING_URL',
        message: `HTTP Request "${node.name}" is missing a URL`,
        severity: 'error',
        nodeName: node.name,
        parameterPath: 'parameters.url'
      })
    }
    return issues
  }
}
```

### Example: Workflow-Level Validator

```typescript
const maxNodesValidator: ValidatorPlugin = {
  id: 'max-nodes-check',
  name: 'Maximum Nodes Check',
  priority: 1,

  validateNode(node, graphNode, ctx) {
    return []  // No per-node checks
  },

  validateWorkflow(ctx) {
    const issues: ValidationIssue[] = []
    if (ctx.nodes.size > 100) {
      issues.push({
        code: 'TOO_MANY_NODES',
        message: `Workflow has ${ctx.nodes.size} nodes (recommended max: 100)`,
        severity: 'warning'
      })
    }
    return issues
  }
}
```

### PluginContext

Read-only context passed to validators:

```typescript
interface PluginContext {
  nodes: ReadonlyMap<string, GraphNode>  // All nodes in the workflow
  workflowId: string                     // Workflow ID
  workflowName: string                   // Workflow name
  settings: WorkflowSettings             // Workflow settings
  pinData?: Record<string, IDataObject[]>  // Pin data
  validationOptions?: ValidationOptions    // Validation options
}
```

## Composite Handler Plugins

Handle custom composite node structures (like IF/Else, Switch, Merge).

### CompositeHandlerPlugin Interface

```typescript
interface CompositeHandlerPlugin<TInput = unknown> {
  id: string
  name: string
  priority?: number

  // Detect if input is a composite this handler manages
  canHandle(input: unknown): input is TInput

  // Add the composite's nodes to the workflow graph
  addNodes(input: TInput, ctx: MutablePluginContext): string  // Returns head node name

  // Optional: handle "then" chaining after composite
  handleThen?(input: TInput, targets: unknown[], ctx: MutablePluginContext): void

  // Optional: get the head node name without full processing
  getHeadNodeName?(input: TInput): string | { name: string; id: string }

  // Optional: collect pin data from the composite
  collectPinData?(input: TInput, collector: (node: NodeInstance, data: IDataObject[]) => void): void
}
```

### MutablePluginContext

Extended context for composite handlers:

```typescript
interface MutablePluginContext extends PluginContext {
  nodes: Map<string, GraphNode>                    // Mutable node map
  addNodeWithSubnodes(node: NodeInstance): void     // Add node + its subnodes
  addBranchToGraph(branch: NodeInstance | NodeChain): void  // Add a branch
  nameMapping?: Map<string, string>                 // Node name mapping
  trackRename?(nodeId: string, actualKey: string): void     // Track renames
}
```

### Example: Custom Composite Handler

```typescript
// Example: A custom "retry" composite that wraps a node with retry logic
interface RetryComposite {
  _isRetryComposite: true
  targetNode: NodeInstance
  maxRetries: number
}

const retryHandler: CompositeHandlerPlugin<RetryComposite> = {
  id: 'retry-composite',
  name: 'Retry Composite Handler',
  priority: 5,

  canHandle(input: unknown): input is RetryComposite {
    return typeof input === 'object' && input !== null && '_isRetryComposite' in input
  },

  addNodes(input: RetryComposite, ctx: MutablePluginContext): string {
    ctx.addNodeWithSubnodes(input.targetNode)
    return input.targetNode.name
  },

  getHeadNodeName(input: RetryComposite) {
    return input.targetNode.name
  }
}

registry.registerCompositeHandler(retryHandler)
```

## Serializer Plugins

Custom output format serialization.

### SerializerPlugin Interface

```typescript
interface SerializerPlugin<TOutput = unknown> {
  id: string
  name: string
  format: string                 // Format identifier (must be unique)
  serialize(ctx: SerializerContext): TOutput
}
```

### SerializerContext

```typescript
interface SerializerContext extends PluginContext {
  resolveTargetNodeName(target: unknown): string | undefined
  meta?: Record<string, unknown>
}
```

### Example: Custom Serializer

```typescript
// Serialize workflow as a Mermaid diagram
const mermaidSerializer: SerializerPlugin<string> = {
  id: 'mermaid-serializer',
  name: 'Mermaid Diagram Serializer',
  format: 'mermaid',

  serialize(ctx: SerializerContext): string {
    let diagram = 'graph TD\n'
    for (const [name, graphNode] of ctx.nodes) {
      const sanitized = name.replace(/[^a-zA-Z0-9]/g, '_')
      diagram += `  ${sanitized}["${name}"]\n`

      for (const [connType, outputs] of graphNode.connections) {
        for (const [outputIdx, targets] of outputs) {
          for (const target of targets) {
            const targetSanitized = target.node.replace(/[^a-zA-Z0-9]/g, '_')
            diagram += `  ${sanitized} --> ${targetSanitized}\n`
          }
        }
      }
    }
    return diagram
  }
}

registry.registerSerializer(mermaidSerializer)

// Usage:
const wf = workflow('id', 'name', { registry })
  .add(trigger).to(node1).to(node2)

const mermaid = wf.toFormat<string>('mermaid')
```

## Plugin Utility Functions

Helper functions for plugin authors:

```typescript
import { findMapKey, isAutoRenamed, formatNodeRef } from '@n8n/workflow-sdk'

// Find the map key for a graph node
const key = findMapKey(graphNode, ctx)

// Check if a node was auto-renamed
isAutoRenamed('HTTP Request 1', 'HTTP Request')  // true
isAutoRenamed('HTTP Request', 'HTTP Request')     // false

// Format a node reference for warning messages
formatNodeRef('HTTP Request 1', 'HTTP Request', 'n8n-nodes-base.httpRequest')
// Returns: 'HTTP Request 1 (originally "HTTP Request", type: n8n-nodes-base.httpRequest)'
```

## Type Generation

The SDK can generate TypeScript types from n8n node definitions. This is primarily used internally but available for advanced use cases.

### Loading Node Types

```typescript
import { loadNodeTypes } from '@n8n/workflow-sdk'

const nodeTypes = await loadNodeTypes('/path/to/n8n/node-types')
// Returns: NodeTypeDescription[]
```

### Generating Types

```typescript
import { generateTypes, orchestrateGeneration } from '@n8n/workflow-sdk'

// Simple generation
await generateTypes()

// With options
const result = await orchestrateGeneration({
  // generation options
})
```

### Type Generation Utilities

| Function | Description |
|----------|-------------|
| `mapPropertyType(prop, context)` | Map node property to TypeScript type |
| `extractDiscriminatorCombinations(node)` | Extract resource/operation patterns |
| `getPropertiesForCombination(combo, node)` | Get properties for a combination |
| `propertyAppliesToVersion(prop, version)` | Check version applicability |
| `filterPropertiesForVersion(props, version)` | Filter by version |
| `generateDiscriminatedUnion(node)` | Generate discriminated union type |
| `buildDiscriminatorTree(nodes)` | Build discriminator tree |
| `hasDiscriminatorPattern(node)` | Check for resource/operation pattern |
| `generatePropertyJSDoc(prop)` | Generate JSDoc for property |
| `generateNodeJSDoc(node)` | Generate JSDoc for node |
| `generatePropertyLine(prop, optional)` | Generate TS property line |
| `groupVersionsByProperties(nodes)` | Group versions by properties |
| `getHighestVersion(version)` | Get highest version number |
| `versionToTypeName(version)` | Convert version to type name |
| `versionToFileName(version)` | Convert version to file name |
| `nodeNameToFileName(nodeName)` | Convert node name to file name |
| `getPackageName(nodeName)` | Extract package name |
| `generateSingleVersionTypeFile(...)` | Generate single version type file |
| `generateVersionIndexFile(...)` | Generate version index file |
| `generateNodeTypeFile(...)` | Generate node type file |
| `generateIndexFile(...)` | Generate main index file |
| `planSplitVersionFiles(...)` | Plan split-version file generation |
| `extractOutputTypes(...)` | Extract output types |
| `groupNodesByOutputType(...)` | Group by output type |
| `generateSubnodeUnionTypes(...)` | Generate subnode union types |
| `generateSubnodesFile(...)` | Generate subnodes file |
| `getSubnodeOutputType(...)` | Get subnode output type |

### Output Schema Discovery

```typescript
import { discoverSchemasForNode, jsonSchemaToTypeScript, findSchemaForOperation } from '@n8n/workflow-sdk'

// Discover schemas from __schema__ directory
const schemas = discoverSchemasForNode(nodeTypeDescription)

// Convert JSON Schema to TypeScript
const tsType = jsonSchemaToTypeScript(jsonSchema, 2)

// Find schema for specific operation
const schema = findSchemaForOperation(nodeTypeDescription, 'create')
```

## Zod Schema Generation

Generate Zod validation schemas from node definitions.

### Zod Schema Utilities

```typescript
import {
  mapPropertyToZodSchema,
  generateSchemaPropertyLine,
  generateSingleVersionSchemaFile,
  generateSchemaIndexFile,
  generateDiscriminatorSchemaFile,
  planSplitVersionSchemaFiles
} from '@n8n/workflow-sdk'
```

### Zod Helpers (Runtime)

Used in generated Zod schema files:

```typescript
import {
  expressionPattern,           // RegExp: /^={{.*}}$/s
  expressionSchema,            // z.ZodString for expressions
  stringOrExpression,          // z.string() (covers both)
  numberOrExpression,          // z.union([z.number(), expressionSchema])
  booleanOrExpression,         // z.union([z.boolean(), expressionSchema])
  resourceLocatorValueSchema,  // Resource locator value schema
  filterValueSchema,           // Filter value schema
  filterConditionSchema,       // Filter condition schema
  filterOperatorSchema,        // Filter operator schema
  assignmentCollectionValueSchema, // Assignment collection schema
  assignmentSchema,            // Single assignment schema
  iDataObjectSchema,           // Generic data object schema
  literalUnion,                // Create literal union from values
  optionsWithExpression,       // Options that also accept expressions
  multiOptionsSchema           // Multi-select options array
} from '@n8n/workflow-sdk'
```

### Examples

```typescript
// Create a literal union for allowed values
const statusSchema = literalUnion(['active', 'inactive', 'pending'])

// Options that also accept expressions
const modeSchema = optionsWithExpression(['auto', 'manual'])
// Accepts: 'auto', 'manual', or '={{ $json.mode }}'

// Multi-select options
const tagsSchema = multiOptionsSchema(['urgent', 'important', 'low'])
// Accepts: ['urgent', 'important'] etc.

// Resource locator values
// Validates: { __rl: true, mode: 'list', value: '123' }
// Or expression strings
```

## Advanced Patterns

### Custom Registry with All Plugin Types

```typescript
import { PluginRegistry, registerDefaultPlugins, workflow } from '@n8n/workflow-sdk'

const registry = new PluginRegistry()
registerDefaultPlugins(registry)

// Add custom validator
registry.registerValidator({
  id: 'my-validator',
  name: 'My Validator',
  validateNode(node, graphNode, ctx) { return [] },
  validateWorkflow(ctx) { return [] }
})

// Add custom serializer
registry.registerSerializer({
  id: 'my-serializer',
  name: 'My Serializer',
  format: 'custom',
  serialize(ctx) { return { /* custom format */ } }
})

// Build workflow with custom registry
const wf = workflow('id', 'name', { registry })
  .add(trigger).to(node1)

// Validation uses custom validators
const result = wf.validate()

// Custom serialization
const custom = wf.toFormat('custom')
```

### Inspecting the Code Generation Pipeline

```typescript
import {
  buildSemanticGraph, annotateGraph, buildCompositeTree, generateCode
} from '@n8n/workflow-sdk'

const json = wf.toJSON()

// Step through the pipeline
const graph = buildSemanticGraph(json)
console.log('Semantic graph nodes:', [...graph.nodes.keys()])

annotateGraph(graph)
console.log('Annotated graph:', graph)

const tree = buildCompositeTree(graph)
console.log('Composite tree:', tree)

const code = generateCode(tree, json, graph)
console.log('Generated code:', code)
```

### Schema Validation Setup

```typescript
import { setSchemaBaseDirs, validateWorkflow } from '@n8n/workflow-sdk'

// Point to n8n's built-in node schemas
setSchemaBaseDirs([
  '/path/to/n8n/packages/nodes-base/dist/schemas',
  '/path/to/n8n-nodes-langchain/dist/schemas'
])

// Now validation checks parameters against schemas
const result = validateWorkflow(wf, { validateSchema: true })
```
