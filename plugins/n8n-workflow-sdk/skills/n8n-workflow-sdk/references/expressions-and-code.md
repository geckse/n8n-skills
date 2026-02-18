# Expressions and Code Helpers Reference

Complete reference for the expression system, Code node helpers, and the expression context in the `@n8n/workflow-sdk`.

## Table of Contents

- [Expression Utilities](#expression-utilities)
- [Expression Context](#expression-context)
- [Using Expressions in Node Parameters](#using-expressions-in-node-parameters)
- [Code Node Helpers](#code-node-helpers)
- [fromAi() — AI-Driven Parameters](#fromai--ai-driven-parameters)
- [Practical Expression Examples](#practical-expression-examples)

## Expression Utilities

### serializeExpression() — Function to Expression

Converts a JavaScript arrow function into an n8n expression string:

```typescript
import { serializeExpression } from '@n8n/workflow-sdk'

// Access current item's JSON data
serializeExpression($ => $.json.name)
// Result: '={{ $json.name }}'

serializeExpression($ => $.json.user.email)
// Result: '={{ $json.user.email }}'

// Access environment variables
serializeExpression($ => $.env.API_TOKEN)
// Result: '={{ $env.API_TOKEN }}'

// Access workflow variables
serializeExpression($ => $.vars.baseUrl)
// Result: '={{ $vars.baseUrl }}'

// Access secrets
serializeExpression($ => $.secrets.apiKey)
// Result: '={{ $secrets.apiKey }}'

// Reference another node's output
serializeExpression($ => $('HTTP Request').json.data)
// Result: "={{ $('HTTP Request').item.json.data }}"

// Access input data
serializeExpression($ => $.input.first())
// Result: '={{ $input.first() }}'

serializeExpression($ => $.input.all())
// Result: '={{ $input.all() }}'

// Access execution metadata
serializeExpression($ => $.execution.id)
// Result: '={{ $execution.id }}'

serializeExpression($ => $.workflow.name)
// Result: '={{ $workflow.name }}'

// Date helpers
serializeExpression($ => $.now)
// Result: '={{ $now }}'

serializeExpression($ => $.today)
// Result: '={{ $today }}'

// Item/run indices
serializeExpression($ => $.itemIndex)
// Result: '={{ $itemIndex }}'

serializeExpression($ => $.runIndex)
// Result: '={{ $runIndex }}'
```

### expr() — Manual Expression Marking

Marks a string as an n8n expression by adding the `=` prefix:

```typescript
import { expr } from '@n8n/workflow-sdk'

expr('{{ $json.name }}')
// Result: '={{ $json.name }}'

expr('{{ "Hello " + $json.name }}')
// Result: '={{ "Hello " + $json.name }}'

// Handles redundant '=' prefix
expr('={{ $json.name }}')
// Result: '={{ $json.name }}' (doesn't double the =)
```

Use `expr()` when:
- You need string concatenation or complex expressions
- The expression can't be expressed as a simple property access
- You're working with template literals in expressions

### parseExpression() — Extract Inner Expression

```typescript
import { parseExpression } from '@n8n/workflow-sdk'

parseExpression('={{ $json.name }}')
// Result: '$json.name'

parseExpression('={{ $now.format("yyyy-MM-dd") }}')
// Result: '$now.format("yyyy-MM-dd")'
```

### isExpression() — Check if Value is Expression

```typescript
import { isExpression } from '@n8n/workflow-sdk'

isExpression('={{ $json.name }}')    // true
isExpression('hello world')           // false
isExpression(42)                      // false
isExpression('={{ }}')                // true (empty expression)
```

## Expression Context

The full context available inside `serializeExpression()`:

```typescript
interface ExpressionContext {
  // Current item data
  json: IDataObject                    // Current item's JSON data
  binary: BinaryContext                // Binary data fields

  // Input data access
  input: {
    first(): IDataObject               // First input item
    all(): IDataObject[]               // All input items
    item: IDataObject                  // Current input item
  }

  // Environment and variables
  env: IDataObject                     // Environment variables
  vars: IDataObject                    // Workflow variables
  secrets: IDataObject                 // Secret values

  // Date/time
  now: Date                            // Current date/time
  today: Date                          // Today's date (midnight)

  // Indices
  itemIndex: number                    // Current item index
  runIndex: number                     // Current run index

  // Metadata
  execution: {
    id: string                         // Execution ID
    mode: 'test' | 'production'        // Execution mode
    resumeUrl?: string                 // Resume URL (for wait nodes)
  }
  workflow: {
    id?: string                        // Workflow ID
    name?: string                      // Workflow name
    active: boolean                    // Whether workflow is active
  }
}
```

## Using Expressions in Node Parameters

```typescript
const httpNode = node({
  type: 'n8n-nodes-base.httpRequest', version: 5,
  config: {
    parameters: {
      // Using serializeExpression
      url: serializeExpression($ => $('Config').json.baseUrl),

      // Using expr() for complex expressions
      headers: {
        Authorization: expr('{{ "Bearer " + $json.token }}')
      },

      // Static value (no expression)
      method: 'POST',

      // Expression in body
      body: expr('{{ JSON.stringify($json.payload) }}')
    }
  }
})
```

## Code Node Helpers

The SDK provides helpers to create Code node configurations with proper function extraction.

### runOnceForAllItems()

Processes all input items at once. The function body is extracted and converted to n8n Code node format.

```typescript
import { runOnceForAllItems, node } from '@n8n/workflow-sdk'

const codeConfig = runOnceForAllItems<{ total: number; count: number }>((ctx) => {
  const items = ctx.$input.all();
  const total = items.reduce((sum, item) => sum + (item.json.value as number), 0);
  return [
    { json: { total, count: items.length } }
  ];
})

const codeNode = node({
  type: 'n8n-nodes-base.code', version: 2,
  config: {
    name: 'Calculate Total',
    parameters: {
      ...codeConfig,            // Spreads: mode, jsCode
      language: 'javaScript'
    },
    output: [{ json: { total: 150, count: 3 } }]
  }
})
```

**AllItemsContext (`ctx`) properties:**

| Property | Type | Description |
|----------|------|-------------|
| `$input.all()` | `IDataObject[]` | Get all input items |
| `$input.first()` | `IDataObject` | Get first input item |
| `$input.last()` | `IDataObject` | Get last input item |
| `$input.itemMatching(index)` | `IDataObject` | Get item at specific index |
| `$env` | `IDataObject` | Environment variables |
| `$vars` | `IDataObject` | Workflow variables |
| `$secrets` | `IDataObject` | Secrets |
| `$now` | `Date` | Current date/time |
| `$today` | `Date` | Today's date |
| `$runIndex` | `number` | Current run index |
| `$execution` | `object` | Execution metadata |
| `$workflow` | `object` | Workflow metadata |
| `(nodeName)` | `function` | Reference other node outputs |
| `$jmespath(data, expr)` | `function` | JMESPath evaluation |

**Return type:** `Array<{ json: T }>` — An array of output items.

### runOnceForEachItem()

Processes one input item at a time. Called for each item in the input.

```typescript
import { runOnceForEachItem, node } from '@n8n/workflow-sdk'

const codeConfig = runOnceForEachItem<{ doubled: number; original: number }>((ctx) => {
  const value = ctx.$input.item.json.value as number;
  return {
    json: { doubled: value * 2, original: value }
  };
})

const codeNode = node({
  type: 'n8n-nodes-base.code', version: 2,
  config: {
    name: 'Double Values',
    parameters: {
      ...codeConfig,
      language: 'javaScript'
    },
    output: [{ json: { doubled: 20, original: 10 } }]
  }
})
```

**EachItemContext (`ctx`) properties:**

| Property | Type | Description |
|----------|------|-------------|
| `$input.item` | `IDataObject` | Current input item |
| `$itemIndex` | `number` | Current item index |
| `$env` | `IDataObject` | Environment variables |
| `$vars` | `IDataObject` | Workflow variables |
| `$secrets` | `IDataObject` | Secrets |
| `$now` | `Date` | Current date/time |
| `$today` | `Date` | Today's date |
| `$runIndex` | `number` | Current run index |
| `$execution` | `object` | Execution metadata |
| `$workflow` | `object` | Workflow metadata |
| `(nodeName)` | `function` | Reference other node outputs |
| `$jmespath(data, expr)` | `function` | JMESPath evaluation |

**Return type:** `{ json: T } | null` — A single output item or null to skip.

### CodeResult Type

Both helpers return a `CodeResult<T>`:

```typescript
interface CodeResult<T> {
  mode: 'runOnceForAllItems' | 'runOnceForEachItem'
  jsCode: string            // Extracted function body as string
  _outputType?: T           // Type marker for inference
}
```

Spread into `parameters` to use:

```typescript
config: {
  parameters: {
    ...codeResult,         // Sets mode and jsCode
    language: 'javaScript' // You set the language
  }
}
```

## fromAi() — AI-Driven Parameters

Creates `$fromAI` expressions for tool node parameters. The AI agent decides the value at runtime.

```typescript
import { fromAi } from '@n8n/workflow-sdk'

// Basic: key only
fromAi('search_query')
// → generates $fromAI expression

// With description
fromAi('recipient', 'The email address to send to')

// With type
fromAi('count', 'Number of results to fetch', 'number')

// With default value
fromAi('include_details', 'Whether to include full details', 'boolean', false)

// JSON type for complex data
fromAi('filters', 'Search filters as JSON object', 'json')
```

**Parameters:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | `string` | Yes | Parameter identifier |
| `description` | `string` | No | What the AI should provide |
| `type` | `FromAIArgumentType` | No | `'string'` \| `'number'` \| `'boolean'` \| `'json'` |
| `defaultValue` | `string \| number \| boolean \| object` | No | Default if AI doesn't provide |

**Important:** Only use `fromAi()` in tool nodes. The validator will emit `FROM_AI_IN_NON_TOOL` if used in regular nodes.

### Usage in Tool Nodes

```typescript
import { tool, fromAi } from '@n8n/workflow-sdk'

const searchTool = tool({
  type: 'n8n-nodes-base.httpRequestTool', version: 1,
  config: {
    parameters: {
      url: 'https://api.example.com/search',
      method: 'GET',
      queryParameters: {
        parameters: [
          { name: 'q', value: fromAi('query', 'Search query string') },
          { name: 'limit', value: fromAi('limit', 'Max results', 'number', 10) }
        ]
      }
    }
  }
})
```

## Practical Expression Examples

### String Concatenation

```typescript
// Build a URL with parameters
parameters: {
  url: expr('{{ $json.baseUrl + "/api/v2/users/" + $json.userId }}')
}
```

### Conditional Values

```typescript
// Ternary in expression
parameters: {
  url: expr('{{ $json.isProd ? "https://api.prod.com" : "https://api.staging.com" }}')
}
```

### Referencing Other Nodes

```typescript
// Use output from a specific node
parameters: {
  body: serializeExpression($ => $('Transform Data').json.processedPayload)
}
```

### Date Formatting

```typescript
// Current date in expressions
parameters: {
  startDate: expr('{{ $now.toISOString() }}'),
  dateStr: expr('{{ $today.format("yyyy-MM-dd") }}')
}
```

### Environment Variables

```typescript
// Use env vars for configuration
parameters: {
  url: serializeExpression($ => $.env.API_BASE_URL),
  headers: {
    'X-Api-Key': serializeExpression($ => $.env.API_KEY)
  }
}
```

### Item Index

```typescript
// Use item index for sequencing
parameters: {
  rowNumber: serializeExpression($ => $.itemIndex)
}
```

### Binary Data Access

```typescript
// Access binary data keys
serializeExpression($ => $.binary.keys())
// Result: '={{ $binary.keys() }}'
```
