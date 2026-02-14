# Declarative Node Reference

Complete template and patterns for building a declarative-style n8n node.

## Table of Contents

1. [Complete Base File Template](#complete-base-file-template)
2. [Routing Patterns](#routing-patterns)
3. [Request Defaults](#request-defaults)
4. [Operations with Routing](#operations-with-routing)
5. [Query String Parameters](#query-string-parameters)
6. [Request Body](#request-body)
7. [Response Handling](#response-handling)
8. [Additional Fields with Routing](#additional-fields-with-routing)
9. [Codex File](#codex-file)
10. [Complete Working Example](#complete-working-example)
11. [Advanced Declarative Patterns](#advanced-declarative-patterns)
    - [Declarative Dynamic Dropdowns](#declarative-dynamic-dropdowns-loadoptions-with-routing)
    - [Dynamic Property Paths in Routing](#dynamic-property-paths-in-routing)
    - [Routing on Parameter Fields](#routing-on-parameter-fields-not-just-operations)
    - [Description File Splitting Pattern](#description-file-splitting-pattern)
    - [preSend Functions](#presend-functions)
    - [Custom postReceive Functions](#custom-postreceive-functions)
    - [Custom Pagination Functions](#custom-pagination-functions)
    - [Resource Locator Parameters](#resource-locator-parameters)
    - [Resource Mapper Parameters](#resource-mapper-parameters)
    - [Methods Object (listSearch, loadOptions, resourceMapping)](#methods-object)
    - [fixedCollection Parameters](#fixedcollection-parameters)
    - [Combining displayOptions show and hide](#combining-displayoptions-show-and-hide)
    - [Advanced displayOptions Conditions](#advanced-displayoptions-conditions)
    - [Error Handling with ignoreHttpStatusErrors](#error-handling-with-ignorehttpstatuserrors)
    - [Generic Pagination](#generic-pagination)
    - [Cursor-Based Pagination](#cursor-based-pagination)
    - [Dynamic Base URL from Credentials](#dynamic-base-url-from-credentials)
    - [File Upload with preSend](#file-upload-with-presend)
    - [File Download with postReceive](#file-download-with-postreceive)
    - [Modular Operations Structure](#modular-operations-structure)
    - [TypeScript Type Reference](#typescript-type-reference)

## Complete Base File Template

```typescript
import {
  INodeType,
  INodeTypeDescription,
  NodeConnectionType,
} from 'n8n-workflow';

export class MyService implements INodeType {
  description: INodeTypeDescription = {
    displayName: 'My Service',
    name: 'myService',
    icon: 'file:myService.svg',
    group: ['transform'],
    version: 1,
    subtitle: '={{$parameter["operation"] + ": " + $parameter["resource"]}}',
    description: 'Interact with the My Service API',
    defaults: {
      name: 'My Service',
    },
    inputs: [NodeConnectionType.Main],
    outputs: [NodeConnectionType.Main],
    usableAsTool: true,
    credentials: [
      {
        name: 'myServiceApi',
        required: true,
      },
    ],
    requestDefaults: {
      baseURL: 'https://api.myservice.com/v1',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
    },
    properties: [
      // Resource
      {
        displayName: 'Resource',
        name: 'resource',
        type: 'options',
        noDataExpression: true,
        options: [
          {
            name: 'Contact',
            value: 'contact',
          },
          {
            name: 'Deal',
            value: 'deal',
          },
        ],
        default: 'contact',
      },
      // Operations for Contact
      {
        displayName: 'Operation',
        name: 'operation',
        type: 'options',
        noDataExpression: true,
        displayOptions: {
          show: {
            resource: ['contact'],
          },
        },
        options: [
          {
            name: 'Create',
            value: 'create',
            action: 'Create a contact',
            description: 'Create a new contact',
            routing: {
              request: {
                method: 'POST',
                url: '/contacts',
              },
            },
          },
          {
            name: 'Delete',
            value: 'delete',
            action: 'Delete a contact',
            description: 'Delete an existing contact',
            routing: {
              request: {
                method: 'DELETE',
                url: '=/contacts/{{$parameter["contactId"]}}',
              },
            },
          },
          {
            name: 'Get',
            value: 'get',
            action: 'Get a contact',
            description: 'Retrieve a single contact',
            routing: {
              request: {
                method: 'GET',
                url: '=/contacts/{{$parameter["contactId"]}}',
              },
            },
          },
          {
            name: 'Get Many',
            value: 'getAll',
            action: 'Get many contacts',
            description: 'Retrieve multiple contacts',
            routing: {
              request: {
                method: 'GET',
                url: '/contacts',
              },
            },
          },
          {
            name: 'Update',
            value: 'update',
            action: 'Update a contact',
            description: 'Update an existing contact',
            routing: {
              request: {
                method: 'PUT',
                url: '=/contacts/{{$parameter["contactId"]}}',
              },
            },
          },
        ],
        default: 'create',
      },
      // Fields for Contact operations
      {
        displayName: 'Contact ID',
        name: 'contactId',
        type: 'string',
        required: true,
        default: '',
        description: 'The ID of the contact',
        displayOptions: {
          show: {
            resource: ['contact'],
            operation: ['get', 'update', 'delete'],
          },
        },
      },
      {
        displayName: 'Email',
        name: 'email',
        type: 'string',
        required: true,
        default: '',
        placeholder: 'user@example.com',
        description: 'The email address of the contact',
        displayOptions: {
          show: {
            resource: ['contact'],
            operation: ['create'],
          },
        },
        routing: {
          send: {
            type: 'body',
            property: 'email',
          },
        },
      },
      // Return All / Limit for Get Many
      {
        displayName: 'Return All',
        name: 'returnAll',
        type: 'boolean',
        default: false,
        displayOptions: {
          show: { resource: ['contact'], operation: ['getAll'] },
        },
        description: 'Whether to return all results or only up to a given limit',
      },
      {
        displayName: 'Limit',
        name: 'limit',
        type: 'number',
        default: 50,
        typeOptions: { minValue: 1 },
        displayOptions: {
          show: { resource: ['contact'], operation: ['getAll'], returnAll: [false] },
        },
        description: 'Max number of results to return',
        routing: {
          send: { type: 'query', property: 'limit' },
        },
      },
      // Additional Fields for Create
      {
        displayName: 'Additional Fields',
        name: 'additionalFields',
        type: 'collection',
        placeholder: 'Add Field',
        default: {},
        displayOptions: {
          show: {
            resource: ['contact'],
            operation: ['create', 'update'],
          },
        },
        options: [
          {
            displayName: 'First Name',
            name: 'firstName',
            type: 'string',
            default: '',
            routing: {
              send: {
                type: 'body',
                property: 'first_name',
              },
            },
          },
          {
            displayName: 'Last Name',
            name: 'lastName',
            type: 'string',
            default: '',
            routing: {
              send: {
                type: 'body',
                property: 'last_name',
              },
            },
          },
          {
            displayName: 'Phone',
            name: 'phone',
            type: 'string',
            default: '',
            routing: {
              send: {
                type: 'body',
                property: 'phone',
              },
            },
          },
        ],
      },
    ],
  };
}
```

## Routing Patterns

### Setting the Request Method and URL

Inside each operation's `routing.request`:

```typescript
routing: {
  request: {
    method: 'GET',           // GET, POST, PUT, PATCH, DELETE
    url: '/contacts',        // Static URL
  },
}

// Dynamic URL using expressions:
routing: {
  request: {
    method: 'GET',
    url: '=/contacts/{{$parameter["contactId"]}}',
  },
}
```

### Sending Data in the Body

```typescript
// From a specific field:
routing: {
  send: {
    type: 'body',
    property: 'email',       // Maps to request body key
  },
}

// Entire body from the operation:
routing: {
  request: {
    method: 'POST',
    url: '/contacts',
    body: {
      email: '={{$parameter["email"]}}',
      name: '={{$parameter["name"]}}',
    },
  },
}
```

### Query String Parameters

```typescript
routing: {
  request: {
    qs: {
      limit: '={{$parameter["limit"]}}',
      offset: '={{$parameter["offset"]}}',
    },
  },
}

// Or from a field:
routing: {
  send: {
    type: 'query',
    property: 'search',
  },
}

// Dot notation in property names (enabled by default):
routing: {
  send: {
    type: 'body',
    property: 'profile.firstName',  // Creates nested: { profile: { firstName: value } }
    propertyInDotNotation: true,    // Default; set false to use literal dot in key name
  },
}
```

### Response Handling (postReceive)

```typescript
routing: {
  request: {
    method: 'GET',
    url: '/contacts',
  },
  output: {
    postReceive: [
      {
        type: 'rootProperty',
        properties: {
          property: 'data',    // Extract from response.data
        },
      },
    ],
  },
}
```

All available declarative postReceive transforms:

```typescript
routing: {
  output: {
    postReceive: [
      // Extract nested data from response:
      { type: 'rootProperty', properties: { property: 'data' } },

      // Filter results:
      { type: 'filter', properties: { pass: '={{$responseItem.active}}' } },

      // Limit results:
      { type: 'limit', properties: { maxResults: '={{$parameter.limit}}' } },

      // Replace response with a static or computed value:
      { type: 'set', properties: { value: '={{ { "id": $response.body.id } }}' } },

      // Transform response items into name/value pairs (for loadOptions dropdowns):
      { type: 'setKeyValue', properties: {
        name: '={{$responseItem.name}} - ({{$responseItem.category}})',
        value: '={{$responseItem.id}}',
      }},

      // Sort results by a key:
      { type: 'sort', properties: { key: 'name' } },

      // Convert response body to binary data:
      { type: 'binaryData', properties: { destinationProperty: 'data' } },
    ],
  },
}
```

**Conditional and error-annotated transforms:** Any declarative postReceive transform supports optional `enabled` and `errorMessage` properties:

```typescript
{
  type: 'rootProperty',
  properties: { property: 'data' },
  enabled: '={{$parameter.simplify}}',   // Only run when 'simplify' is true
  errorMessage: 'Could not extract data from response',  // Shown if transform fails
}
```

**`maxResults` on output:** You can set `maxResults` directly on `routing.output` (not just inside a `limit` transform):
```typescript
routing: {
  output: {
    maxResults: '={{$parameter.limit}}',
    postReceive: [
      { type: 'rootProperty', properties: { property: 'data' } },
    ],
  },
}
```

Transforms execute in order — chain them for complex pipelines (e.g., `rootProperty` → `setKeyValue` → `sort` to load dropdown options from an API).

You can also pass custom async functions instead of declarative objects — see [Custom postReceive Functions](#custom-postreceive-functions).

### Routing Expression Variables

Expressions in routing use these variables:

| Variable | Context | Example |
|----------|---------|---------|
| `$value` | Current field's value | `'={{$value}}'` |
| `$parameter.fieldName` | Any node parameter | `'=/items/{{$parameter.itemId}}'` |
| `$parameter["fieldName"]` | Same, bracket notation | `'={{$parameter["email"]}}'` |
| `$credentials.fieldName` | Credential field | `'={{$credentials.apiKey}}'` |
| `$responseItem` | Current response item (in postReceive) | `'={{$responseItem.name}}'` |
| `$response` | Full response (in postReceive set) | `'={{ $response.body }}'` |
| `$index` | Current index in fixedCollection | `'=items[{{$index}}].value'` |
| `$parent.fieldName` | Parent scope value (in nested contexts) | `'=attributes.{{$parent.fieldName}}'` |
| `$request` | Current request options (in generic pagination) | `'={{ $request.qs?.$select }}'` |
| `$version` | Node type version (in generic pagination) | `'={{ $version }}'` |

**URL encoding in expressions:** Use `encodeURIComponent()` or `encodeURI()` for user-provided values in URLs:
```typescript
url: '=/v3/contacts/{{encodeURIComponent($parameter.identifier)}}'
url: '=/v3/attributes/{{$parameter.category}}/{{encodeURI($parameter.name)}}'
```

### Declarative Pagination

For list operations that need automatic pagination:

```typescript
{
  name: 'Get Many',
  value: 'getAll',
  action: 'Get many items',
  routing: {
    request: {
      method: 'GET',
      url: '/items',
    },
    output: {
      postReceive: [
        { type: 'rootProperty', properties: { property: 'data' } },
        { type: 'limit', properties: { maxResults: '={{$parameter.limit}}' } },
      ],
    },
    operations: {
      pagination: {
        type: 'offset',
        properties: {
          limitParameter: 'per_page',
          offsetParameter: 'page',
          pageSize: 100,
          type: 'query',
        },
      },
    },
  },
},
```

## Request Defaults

Set once in the description, applied to all requests:

```typescript
requestDefaults: {
  baseURL: 'https://api.example.com/v1',
  headers: {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  },
},
```

Individual operation routing merges with (and can override) these defaults.

## Codex File

Place alongside the `.node.ts` file as `<Name>.node.json`:

```json
{
  "node": "n8n-nodes-<package>.<nodeName>",
  "nodeVersion": "1.0",
  "codexVersion": "1.0",
  "categories": ["Marketing & Content"],
  "resources": {
    "credentialDocumentation": [
      {
        "url": "https://docs.myservice.com/api-key"
      }
    ],
    "primaryDocumentation": [
      {
        "url": "https://docs.myservice.com/n8n"
      }
    ]
  }
}
```

## Complete Working Example

A full declarative node for a hypothetical "TaskBoard" API:

```typescript
import {
  INodeType,
  INodeTypeDescription,
  NodeConnectionType,
} from 'n8n-workflow';

export class TaskBoard implements INodeType {
  description: INodeTypeDescription = {
    displayName: 'TaskBoard',
    name: 'taskBoard',
    icon: 'file:taskBoard.svg',
    group: ['transform'],
    version: 1,
    subtitle: '={{$parameter["operation"] + ": " + $parameter["resource"]}}',
    description: 'Manage tasks on TaskBoard',
    defaults: {
      name: 'TaskBoard',
    },
    inputs: [NodeConnectionType.Main],
    outputs: [NodeConnectionType.Main],
    usableAsTool: true,
    credentials: [
      {
        name: 'taskBoardApi',
        required: true,
      },
    ],
    requestDefaults: {
      baseURL: 'https://api.taskboard.io/v2',
      headers: {
        Accept: 'application/json',
      },
    },
    properties: [
      {
        displayName: 'Resource',
        name: 'resource',
        type: 'options',
        noDataExpression: true,
        options: [
          { name: 'Task', value: 'task' },
        ],
        default: 'task',
      },
      {
        displayName: 'Operation',
        name: 'operation',
        type: 'options',
        noDataExpression: true,
        displayOptions: {
          show: { resource: ['task'] },
        },
        options: [
          {
            name: 'Create',
            value: 'create',
            action: 'Create a task',
            routing: {
              request: { method: 'POST', url: '/tasks' },
            },
          },
          {
            name: 'Get',
            value: 'get',
            action: 'Get a task',
            routing: {
              request: {
                method: 'GET',
                url: '=/tasks/{{$parameter["taskId"]}}',
              },
            },
          },
          {
            name: 'Get Many',
            value: 'getAll',
            action: 'Get many tasks',
            routing: {
              request: { method: 'GET', url: '/tasks' },
              output: {
                postReceive: [
                  {
                    type: 'rootProperty',
                    properties: { property: 'tasks' },
                  },
                ],
              },
            },
          },
        ],
        default: 'create',
      },
      {
        displayName: 'Task ID',
        name: 'taskId',
        type: 'string',
        required: true,
        default: '',
        displayOptions: {
          show: { resource: ['task'], operation: ['get'] },
        },
      },
      {
        displayName: 'Title',
        name: 'title',
        type: 'string',
        required: true,
        default: '',
        displayOptions: {
          show: { resource: ['task'], operation: ['create'] },
        },
        routing: {
          send: { type: 'body', property: 'title' },
        },
      },
      {
        displayName: 'Additional Fields',
        name: 'additionalFields',
        type: 'collection',
        placeholder: 'Add Field',
        default: {},
        displayOptions: {
          show: { resource: ['task'], operation: ['create'] },
        },
        options: [
          {
            displayName: 'Description',
            name: 'description',
            type: 'string',
            typeOptions: { rows: 4 },
            default: '',
            routing: {
              send: { type: 'body', property: 'description' },
            },
          },
          {
            displayName: 'Priority',
            name: 'priority',
            type: 'options',
            options: [
              { name: 'Low', value: 'low' },
              { name: 'Medium', value: 'medium' },
              { name: 'High', value: 'high' },
            ],
            default: 'medium',
            routing: {
              send: { type: 'body', property: 'priority' },
            },
          },
          {
            displayName: 'Due Date',
            name: 'dueDate',
            type: 'dateTime',
            default: '',
            routing: {
              send: { type: 'body', property: 'due_date' },
            },
          },
        ],
      },
      {
        displayName: 'Return All',
        name: 'returnAll',
        type: 'boolean',
        default: false,
        displayOptions: {
          show: { resource: ['task'], operation: ['getAll'] },
        },
        description: 'Whether to return all results or only up to a given limit',
      },
      {
        displayName: 'Limit',
        name: 'limit',
        type: 'number',
        typeOptions: { minValue: 1, maxValue: 100 },
        default: 50,
        displayOptions: {
          show: { resource: ['task'], operation: ['getAll'], returnAll: [false] },
        },
        description: 'Max number of results to return',
        routing: {
          send: { type: 'query', property: 'limit' },
        },
      },
    ],
  };
}
```

## Advanced Declarative Patterns

The basic declarative patterns above cover simple REST wrappers. For more complex nodes — dynamic dropdowns, custom request/response transformation, binary file handling, dynamic field mapping, cascading dropdowns, and custom pagination — use the advanced patterns below. These are still declarative (no `execute()` method) but use routing expressions, `preSend`/`postReceive` functions, and the `methods` object.

### Declarative Dynamic Dropdowns (loadOptions with Routing)

Load dropdown options from an API without writing any code — use `typeOptions.loadOptions.routing` with postReceive transforms to fetch, reshape, and sort results:

```typescript
{
  displayName: 'Template',
  name: 'templateId',
  type: 'options',
  default: '',
  typeOptions: {
    loadOptions: {
      routing: {
        request: {
          method: 'GET',
          url: '/v3/templates',
          qs: { status: true, limit: 1000, offset: 0 },
        },
        output: {
          postReceive: [
            { type: 'rootProperty', properties: { property: 'templates' } },
            { type: 'setKeyValue', properties: {
              name: '={{$responseItem.name}}',
              value: '={{$responseItem.id}}',
            }},
            { type: 'sort', properties: { key: 'name' } },
          ],
        },
      },
    },
  },
  routing: {
    send: { type: 'body', property: 'templateId' },
  },
}
```

This fetches templates from the API, extracts the `templates` array, maps each item to `{name, value}` for the dropdown, and sorts alphabetically — all without `methods.loadOptions`.

For attribute/field dropdowns that show category info:
```typescript
{ type: 'setKeyValue', properties: {
  name: '={{$responseItem.name}} - ({{$responseItem.category}})',
  value: '={{$responseItem.name}}',
}},
```

### Dynamic Property Paths in Routing

Use expression variables (`$parent`, `$index`, `$value`) to build dynamic body property paths. This is essential for fixedCollection fields that map to nested or array structures in the API:

**Mapping to nested objects using `$parent`:**
```typescript
// In a fixedCollection where user picks a field name and enters a value:
{
  displayName: 'Field Value',
  name: 'fieldValue',
  type: 'string',
  default: '',
  routing: {
    send: {
      value: '={{$value}}',
      property: '=attributes.{{$parent.fieldName}}',  // Creates body.attributes[selectedField] = value
      type: 'body',
    },
  },
}
```

**Mapping to arrays using `$index`:**
```typescript
// In a fixedCollection with multipleValues, each entry maps to an array element:
{
  displayName: 'Value ID',
  name: 'itemValue',
  type: 'number',
  default: 1,
  routing: {
    send: {
      value: '={{$value}}',
      property: '=enumeration[{{$index}}].value',  // Creates body.enumeration[0].value, [1].value, etc.
      type: 'body',
    },
  },
},
{
  displayName: 'Label',
  name: 'itemLabel',
  type: 'string',
  default: '',
  routing: {
    send: {
      value: '={{$value}}',
      property: '=enumeration[{{$index}}].label',  // Creates body.enumeration[0].label, [1].label, etc.
      type: 'body',
    },
  },
}
```

### Routing on Parameter Fields (Not Just Operations)

Routing isn't limited to operation options. You can place `routing` on **any parameter** — including fields inside fixedCollections, additional fields, and even on the parent fixedCollection itself. This is useful for:

**Routing on a field parameter to set request method/URL:**
```typescript
// A field that also defines how to reach the API
{
  displayName: 'Contact Identifier',
  name: 'identifier',
  type: 'string',
  routing: {
    request: {
      method: 'GET',
      url: '=/v3/contacts/{{encodeURIComponent($value)}}',
    },
  },
}
```

**Routing on a fixedCollection parent to set both request and preSend:**
```typescript
{
  displayName: 'Attributes',
  name: 'attributes',
  type: 'fixedCollection',
  typeOptions: { multipleValues: true },
  routing: {
    request: {
      method: 'PUT',
      url: '=/v3/contacts/{{encodeURIComponent($parameter.identifier)}}',
    },
  },
  options: [/* ... field definitions with their own routing.send */],
}
```

**Inline preSend on a field (not just on operations):**
```typescript
{
  displayName: 'Sender',
  name: 'sender',
  type: 'string',
  routing: {
    send: {
      preSend: [validateSenderEmail],  // Runs when this field has a value
    },
  },
}
```

### Description File Splitting Pattern

For nodes with multiple resources, split operations and fields into separate `*Description.ts` files and spread them into the main node's properties array:

```typescript
// ContactDescription.ts
export const contactOperations: INodeProperties[] = [
  { displayName: 'Operation', name: 'operation', type: 'options', /* ... */ },
];
export const contactFields: INodeProperties[] = [
  ...createFields,
  ...getFields,
  ...getAllFields,
  ...updateFields,
  ...deleteFields,
];

// Main node file
import { contactOperations, contactFields } from './ContactDescription';
import { emailOperations, emailFields } from './EmailDescription';

export class MyService implements INodeType {
  description: INodeTypeDescription = {
    // ...
    properties: [
      { displayName: 'Resource', name: 'resource', type: 'options', /* ... */ },
      ...contactOperations,
      ...contactFields,
      ...emailOperations,
      ...emailFields,
    ],
  };
}
```

### preSend Functions

`preSend` functions run **before** the HTTP request is sent. They receive the request options and return modified options. Use them to transform request bodies, switch HTTP methods conditionally, build form-data, or apply complex query parameters.

**Signature** (exported as `PreSendAction` type in `n8n-workflow`):
```typescript
import type { PreSendAction } from 'n8n-workflow';

// Equivalent to:
type PreSendAction = (
  this: IExecuteSingleFunctions,
  requestOptions: IHttpRequestOptions,
) => Promise<IHttpRequestOptions>;
```

**Factory pattern** for reusable preSend functions (from n8n source):
```typescript
import type { PreSendAction, IExecuteSingleFunctions, IHttpRequestOptions } from 'n8n-workflow';

export const parseAndSetBodyJson = (parameterName: string, setAsBodyProperty?: string): PreSendAction => {
  return async function (this: IExecuteSingleFunctions, requestOptions: IHttpRequestOptions) {
    const rawData = this.getNodeParameter(parameterName, '{}') as string;
    const parsed = JSON.parse(rawData);
    if (setAsBodyProperty) {
      requestOptions.body = { ...requestOptions.body as object, [setAsBodyProperty]: parsed };
    } else {
      requestOptions.body = parsed;
    }
    return requestOptions;
  };
};
```

**Wiring preSend into an operation:**
```typescript
{
  name: 'Create',
  value: 'create',
  action: 'Create a record',
  routing: {
    request: {
      method: 'POST',
      url: '=/tables/{{$parameter.tableId}}/records',
    },
    send: {
      paginate: false,
      preSend: [myPreSendFunction],  // Array of functions, executed in order
      type: 'body',
    },
  },
}
```

**Example — Transform input data into API format:**
```typescript
import type { IDataObject, IExecuteSingleFunctions, IHttpRequestOptions, INodeExecutionData } from 'n8n-workflow';
import { NodeOperationError } from 'n8n-workflow';

export const createRecordBody = async function (
  this: IExecuteSingleFunctions,
  requestOptions: IHttpRequestOptions,
): Promise<IHttpRequestOptions> {
  const item = this.getInputData() as INodeExecutionData;

  // Read node parameters
  const addAllFields = this.getNodeParameter('addAllFields', true) as boolean;

  let bodyData: IDataObject;

  if (addAllFields) {
    // Send all input fields wrapped in { fields: {...} }
    bodyData = { fields: item.json };
  } else {
    // Send only selected fields
    const fieldsToSend = this.getNodeParameter('fieldsToSend') as string[];
    const fields: IDataObject = {};
    for (const field of fieldsToSend) {
      fields[field] = item.json[field];
    }
    bodyData = { fields };
  }

  requestOptions.body = bodyData;
  return requestOptions;
};
```

**Example — Conditionally switch HTTP method:**
```typescript
export const queryPreSend = async function (
  this: IExecuteSingleFunctions,
  requestOptions: IHttpRequestOptions,
): Promise<IHttpRequestOptions> {
  const readOnly = this.getNodeParameter('readOnly', 0) as boolean;
  const query = this.getNodeParameter('query', 0) as string;

  if (readOnly) {
    requestOptions.method = 'GET';
    requestOptions.qs = requestOptions.qs || {};
    (requestOptions.qs as IDataObject).query = query;
  } else {
    requestOptions.method = 'POST';
    requestOptions.body = requestOptions.body || {};
    (requestOptions.body as IDataObject).query = query;
  }

  return requestOptions;
};
```

**Example — Build filters from fixedCollection into query string:**
```typescript
export const applyFilters = async function (
  this: IExecuteSingleFunctions,
  requestOptions: IHttpRequestOptions,
): Promise<IHttpRequestOptions> {
  const additionalOptions = this.getNodeParameter('additionalOptions', 0, {}) as IDataObject;

  if (additionalOptions.filters) {
    const filters = additionalOptions.filters as IDataObject;
    const filtersData: IDataObject = {};

    if (filters.filter && Array.isArray(filters.filter)) {
      for (const filter of filters.filter as IDataObject[]) {
        filtersData[filter.fieldId as string] = filter.value;
      }
    }

    if (Object.keys(filtersData).length > 0) {
      requestOptions.qs = requestOptions.qs || {};
      requestOptions.qs.filters = JSON.stringify({ fields: filtersData });
    }
  }

  return requestOptions;
};
```

**Key things available in `this` (IExecuteSingleFunctions):**
- `this.getInputData()` — current input item
- `this.getNodeParameter(name, fallback)` — read any node parameter
- `this.getNode().typeVersion` — check the node version
- `this.getCredentials('credentialName')` — access credential values
- `this.helpers.httpRequest(options)` — make additional HTTP requests
- `this.helpers.getBinaryDataBuffer(propertyName)` — get binary data as Buffer

### Custom postReceive Functions

Beyond the declarative `postReceive` transforms (`rootProperty`, `filter`, `limit`, `set`), you can pass custom async functions to transform responses arbitrarily.

**Signature:**
```typescript
async function(
  this: IExecuteSingleFunctions,
  items: INodeExecutionData[],
  response: IN8nHttpFullResponse,
): Promise<INodeExecutionData[]>
```

**Wiring into an operation:**
```typescript
routing: {
  request: {
    method: 'GET',
    url: '=/records/{{$parameter.recordId}}/files/{{$parameter.fileName}}',
    returnFullResponse: true,  // Required for custom postReceive to get headers
    encoding: 'arraybuffer',   // For binary downloads
  },
  output: {
    postReceive: [handleFileDownload],  // Custom function
  },
}
```

**Example — Convert HTTP response into binary data item:**
```typescript
import type { IExecuteSingleFunctions, IN8nHttpFullResponse, INodeExecutionData } from 'n8n-workflow';
import { NodeOperationError } from 'n8n-workflow';

export const handleFileDownload = async function (
  this: IExecuteSingleFunctions,
  items: INodeExecutionData[],
  response: IN8nHttpFullResponse,
): Promise<INodeExecutionData[]> {
  try {
    for (let i = 0; i < items.length; i++) {
      const mimeType = response.headers['content-type'] as string | undefined;

      const newItem: INodeExecutionData = {
        json: {},
        binary: {},
        pairedItem: { item: i },
      };

      // Preserve existing binary data
      if (items[i].binary !== undefined && newItem.binary !== undefined) {
        Object.assign(newItem.binary, items[i].binary);
      }

      const fileName = this.getNodeParameter('fileName', i) as string;

      // Convert response body to Buffer
      const data = response.body instanceof Buffer
        ? response.body
        : Buffer.from(response.body as ArrayBuffer);

      newItem.binary![fileName] = await this.helpers.prepareBinaryData(
        data,
        fileName,
        mimeType,
      );

      items[i] = newItem;
    }
    return items;
  } catch (err) {
    throw new NodeOperationError(this.getNode(), `${err}`);
  }
};
```

**Example — Return a static success response (e.g. for Delete):**

You can also mix declarative and custom postReceive in the same array:
```typescript
output: {
  postReceive: [
    {
      type: 'set',
      properties: {
        value: '={{ { "deleted": true } }}',
      },
    },
  ],
}
```

### Custom Pagination Functions

For APIs where the built-in offset pagination isn't sufficient (e.g., duplicate detection, cursor-based), use a custom pagination function.

**Signature and wiring:**
```typescript
routing: {
  request: {
    method: 'GET',
    url: '/records',
  },
  operations: {
    pagination: async function(this, requestOptions) {
      // Custom pagination logic — return INodeExecutionData[]
    },
  },
}
```

**Example — Page-based pagination with duplicate detection:**
```typescript
operations: {
  pagination: async function(this, requestOptions) {
    const returnData = [];
    let page = 0;
    const limit = this.getNodeParameter('limit', 500) as number;
    const returnAll = this.getNodeParameter('returnAll', false) as boolean;
    const maxPages = 100;
    const seenIds = new Set();

    while (page < maxPages) {
      requestOptions.options.qs = requestOptions.options.qs || {};
      requestOptions.options.qs.page = page;
      requestOptions.options.qs.perPage = 500;

      const responseData = await this.makeRoutingRequest(requestOptions);

      if (!Array.isArray(responseData) || responseData.length === 0) break;

      // Detect duplicate pages (API returning same data)
      if (responseData[0]?.id && seenIds.has(responseData[0].id)) break;

      for (const item of responseData) {
        if (item.id) seenIds.add(item.id);
        returnData.push(item);

        if (!returnAll && returnData.length >= limit) {
          return this.helpers.returnJsonArray(returnData.slice(0, limit));
        }
      }

      if (responseData.length < 500) break;
      page++;
    }

    if (!returnAll && returnData.length > limit) {
      return this.helpers.returnJsonArray(returnData.slice(0, limit));
    }
    return this.helpers.returnJsonArray(returnData);
  },
}
```

**Controlling pagination from parameters with `routing.send.paginate`:**

Use the `paginate` property on `routing.send` to let a boolean parameter drive whether pagination runs:

```typescript
// On the "Return All" parameter:
{
  displayName: 'Return All',
  name: 'returnAll',
  type: 'boolean',
  default: false,
  routing: {
    send: {
      paginate: '={{$value}}',  // true → paginate, false → single page
    },
  },
}
```

On operations where you never want pagination (e.g., Create, Update), set `paginate: false` explicitly:
```typescript
send: {
  paginate: false,
  preSend: [myPreSendFn],
  type: 'body',
}
```

### Resource Locator Parameters

Use `type: 'resourceLocator'` instead of plain string inputs when users need to select a specific entity (a project, database, table, channel, etc.). It provides multiple input modes: searchable list, URL parsing, and direct ID entry.

```typescript
{
  displayName: 'Project',
  name: 'projectId',
  type: 'resourceLocator',
  default: { mode: 'list', value: '' },
  required: true,
  description: 'The project to access. Choose from the list, or specify an ID.',
  modes: [
    // Mode 1: Searchable dropdown (fetches from API)
    {
      displayName: 'From List',
      name: 'list',
      type: 'list',
      typeOptions: {
        searchListMethod: 'getProjects',  // Method name in methods.listSearch
        searchable: true,
      },
    },
    // Mode 2: URL input with regex extraction
    {
      displayName: 'By URL',
      name: 'url',
      type: 'string',
      placeholder: 'https://app.example.com/projects/abc123',
      validation: [
        {
          type: 'regex',
          properties: {
            regex: 'https://app.example.com/projects/[a-zA-Z0-9]+',
            errorMessage: 'Not a valid project URL',
          },
        },
      ],
      extractValue: {
        type: 'regex',
        regex: 'https://app.example.com/projects/([a-zA-Z0-9]+)',
      },
    },
    // Mode 3: Direct ID entry
    {
      displayName: 'ID',
      name: 'id',
      type: 'string',
      placeholder: 'abc123',
      validation: [
        {
          type: 'regex',
          properties: {
            regex: '[a-zA-Z0-9_]{2,}',
            errorMessage: 'Not a valid project ID',
          },
        },
      ],
    },
  ],
}
```

**Cascading resource locators** (e.g., Team → Database → Table): Use `displayOptions.hide` to only show the next locator when the previous has a value:

```typescript
{
  displayName: 'Database',
  name: 'databaseId',
  type: 'resourceLocator',
  default: { mode: 'list', value: '' },
  displayOptions: {
    hide: {
      teamId: [''],  // Hide until team is selected
    },
  },
  modes: [
    {
      displayName: 'From List',
      name: 'list',
      type: 'list',
      typeOptions: {
        searchListMethod: 'getDatabases',  // This method reads teamId
        searchable: true,
      },
    },
    // ... URL and ID modes
  ],
}
```

### Resource Mapper Parameters

Use `type: 'resourceMapper'` for operations where users need to map input fields to API fields (Create, Update). It provides a UI for field mapping that can auto-detect available fields from the API.

**Parameter definition:**
```typescript
{
  displayName: 'Fields',
  name: 'fields',
  type: 'resourceMapper',
  noDataExpression: true,
  default: {
    mappingMode: 'defineBelow',
    value: null,
  },
  required: true,
  typeOptions: {
    loadOptionsDependsOn: ['tableId.value'],  // Reload when table changes
    resourceMapper: {
      resourceMapperMethod: 'getFields',  // Method in methods.resourceMapping
      mode: 'add',
      fieldWords: {
        singular: 'field',
        plural: 'fields',
      },
      multiKeyMatch: false,
      matchingFieldsLabels: {
        title: 'Field Matching',
        description: 'Map input fields to API fields',
      },
    },
  },
  displayOptions: {
    show: {
      resource: ['record'],
      operation: ['create', 'update'],
    },
  },
}
```

**The `resourceMapperMethod` implementation** (in `methods/resourceMapping.ts`):

```typescript
import type { IDataObject, ILoadOptionsFunctions, ResourceMapperFields, ResourceMapperField, FieldType } from 'n8n-workflow';
import { apiRequest } from '../transport';

// Map the external API's type names to n8n's FieldType
type TypesMap = Partial<Record<FieldType, string[]>>;

const apiTypesMap: TypesMap = {
  string: ['text', 'email', 'url', 'choice'],
  number: ['number', 'currency', 'percent'],
  boolean: ['boolean'],
  dateTime: ['dateTime', 'date'],
  object: ['json'],
  array: ['array'],
};

function mapForeignType(foreignType: string, typesMap: TypesMap): FieldType {
  for (const nativeType of Object.keys(typesMap)) {
    if (typesMap[nativeType as FieldType]?.includes(foreignType)) {
      return nativeType as FieldType;
    }
  }
  return 'string'; // fallback
}

export async function getFields(this: ILoadOptionsFunctions): Promise<ResourceMapperFields> {
  const tableId = this.getCurrentNodeParameter('tableId', { extractValue: true }) as string;

  const schema = await apiRequest.call(this, 'GET', `/tables/${tableId}`);

  const resourceFields: ResourceMapperField[] = schema.fields.map((f: IDataObject) => ({
    id: f.id,
    displayName: f.name,
    required: false,
    defaultMatch: f.id === 'id',
    display: true,
    type: mapForeignType((f.type as string) || 'string', apiTypesMap),
    canBeUsedToMatch: f.id === 'id',
  }));

  return { fields: resourceFields };
}
```

**Reading resourceMapper values in a preSend function:**
```typescript
const dataMode = this.getNodeParameter('fields.mappingMode', 0) as string;

if (dataMode === 'defineBelow') {
  // User explicitly mapped fields in the UI
  const mappingValues = this.getNodeParameter('fields.value', 0) as IDataObject;
  requestOptions.body = { fields: mappingValues };
} else if (dataMode === 'autoMapInputData') {
  // Automatically use all input fields
  const item = this.getInputData() as INodeExecutionData;
  requestOptions.body = { fields: item.json };
}
```

### Methods Object

Declarative nodes can define a `methods` object on the class (outside `description`) to provide dynamic data for resource locators, dropdowns, and resource mappers:

```typescript
export class MyService implements INodeType {
  description: INodeTypeDescription = { /* ... */ };

  methods = {
    // For resourceLocator searchListMethod
    listSearch: {
      async getProjects(this: ILoadOptionsFunctions, filter?: string): Promise<INodeListSearchResult> {
        const items = await apiRequest.call(this, 'GET', '/projects');
        const results = items
          .map((p: IDataObject) => ({ name: p.name as string, value: p.id as string }))
          .filter((p: INodeListSearchItems) =>
            !filter || p.name.toLowerCase().includes(filter.toLowerCase())
          )
          .sort((a: INodeListSearchItems, b: INodeListSearchItems) =>
            a.name.toLowerCase().localeCompare(b.name.toLowerCase())
          );
        return { results };
      },
      // Dependent search: reads parent parameter
      async getDatabases(this: ILoadOptionsFunctions, filter?: string): Promise<INodeListSearchResult> {
        const teamId = (this.getCurrentNodeParameter('teamId') as INodeParameterResourceLocator).value;
        const items = await apiRequest.call(this, 'GET', `/teams/${teamId}/databases`);
        const results = items
          .map((d: IDataObject) => ({ name: d.name as string, value: d.id as string }))
          .filter((d: INodeListSearchItems) =>
            !filter || d.name.toLowerCase().includes(filter.toLowerCase())
          );
        return { results };
      },
    },

    // For loadOptionsMethod on regular dropdowns
    loadOptions: {
      async getStatuses(this: ILoadOptionsFunctions): Promise<INodePropertyOptions[]> {
        const statuses = await apiRequest.call(this, 'GET', '/statuses');
        return statuses.map((s: IDataObject) => ({
          name: s.label as string,
          value: s.id as string,
        }));
      },
    },

    // For resourceMapper resourceMapperMethod
    resourceMapping: {
      getFields,  // Imported from methods/resourceMapping.ts
    },
  };
}
```

**Import types needed for methods:**
```typescript
import type {
  INodeListSearchResult,
  INodeListSearchItems,
  INodePropertyOptions,
  INodeParameterResourceLocator,
  ILoadOptionsFunctions,
} from 'n8n-workflow';
```

### fixedCollection Parameters

Use `type: 'fixedCollection'` for structured, repeatable parameter groups like filters or sort rules. These are especially useful inside "Additional Options" collections.

```typescript
{
  displayName: 'Filters',
  name: 'filters',
  type: 'fixedCollection',
  typeOptions: {
    multipleValues: true,  // Allow multiple filter entries
  },
  placeholder: 'Add Filter',
  default: {},
  options: [
    {
      name: 'filter',
      displayName: 'Filter',
      values: [
        {
          displayName: 'Field ID',
          name: 'fieldId',
          type: 'string',
          default: '',
          description: 'The ID of the field to filter by',
        },
        {
          displayName: 'Value',
          name: 'value',
          type: 'string',
          default: '',
          description: 'The value to filter for',
        },
      ],
    },
  ],
}
```

**Sort rule fixedCollection with routing on nested values:**
```typescript
{
  displayName: 'Sort by Field',
  name: 'sort',
  type: 'fixedCollection',
  typeOptions: { multipleValues: true },
  placeholder: 'Add Sort Rule',
  default: {},
  options: [
    {
      name: 'property',
      displayName: 'Property',
      values: [
        {
          displayName: 'Field',
          name: 'field',
          type: 'string',
          default: '',
          routing: {
            send: { type: 'query', property: 'order' },
          },
        },
        {
          displayName: 'Direction',
          name: 'direction',
          type: 'options',
          options: [
            {
              name: 'ASC',
              value: 'asc',
              routing: { send: { type: 'query', property: 'desc', value: 'false' } },
            },
            {
              name: 'DESC',
              value: 'desc',
              routing: { send: { type: 'query', property: 'desc', value: 'true' } },
            },
          ],
          default: 'asc',
        },
      ],
    },
  ],
}
```

### Combining displayOptions show and hide

Use `show` and `hide` together to display a field for most values of a parameter but exclude specific ones:

```typescript
{
  displayName: 'Value',
  name: 'attributeValue',
  type: 'string',
  displayOptions: {
    show: {
      resource: ['attribute'],
      operation: ['update'],
    },
    hide: {
      attributeCategory: ['category'],  // Show for all categories EXCEPT 'category'
    },
  },
}
```

### Advanced displayOptions Conditions

Beyond simple value arrays, `displayOptions.show` and `hide` support advanced condition operators via `DisplayCondition`:

```typescript
displayOptions: {
  show: {
    // Show only for node version 2+:
    '@version': [{ _cnd: { gte: 2 } }],

    // Show when used as an AI tool:
    '@tool': [true],

    // Show when field value starts with a prefix:
    protocol: [{ _cnd: { startsWith: 'https' } }],

    // Show when a field exists (has any value):
    apiKey: [{ _cnd: { exists: true } }],
  },
}
```

**All available `_cnd` operators:**

| Operator | Description | Example |
|----------|-------------|---------|
| `eq` | Equals | `{ _cnd: { eq: 'value' } }` |
| `not` | Not equals | `{ _cnd: { not: 'value' } }` |
| `gte` | Greater than or equal | `{ _cnd: { gte: 2 } }` |
| `lte` | Less than or equal | `{ _cnd: { lte: 10 } }` |
| `gt` | Greater than | `{ _cnd: { gt: 0 } }` |
| `lt` | Less than | `{ _cnd: { lt: 100 } }` |
| `between` | Between range | `{ _cnd: { between: { from: 1, to: 5 } } }` |
| `startsWith` | Starts with string | `{ _cnd: { startsWith: 'http' } }` |
| `endsWith` | Ends with string | `{ _cnd: { endsWith: '.json' } }` |
| `includes` | Contains string | `{ _cnd: { includes: 'api' } }` |
| `regex` | Matches regex | `{ _cnd: { regex: '^v\\d+' } }` |
| `exists` | Has any value | `{ _cnd: { exists: true } }` |

**Special `show` keys:**
- `'@version'`: Filter by node type version — `{ show: { '@version': [1] } }` or `{ show: { '@version': [{ _cnd: { gte: 2 } }] } }`
- `'@tool'`: Filter by AI tool usage — `{ show: { '@tool': [true] } }`
- `'@feature'`: Filter by node feature flags

### Error Handling with ignoreHttpStatusErrors

For declarative nodes that need custom error handling, use `ignoreHttpStatusErrors: true` on the request to prevent n8n from throwing on HTTP errors. Then use a custom `postReceive` function to inspect the response and handle errors:

```typescript
{
  name: 'Delete',
  value: 'delete',
  action: 'Delete an item',
  routing: {
    request: {
      method: 'DELETE',
      url: '=/items/{{$parameter.itemId}}',
      ignoreHttpStatusErrors: true,  // Don't throw on 4xx/5xx
    },
    output: {
      postReceive: [handleErrors, { type: 'set', properties: { value: '={{ { "deleted": true } }}' } }],
    },
  },
}
```

The `handleErrors` function can inspect the response status and throw meaningful errors:
```typescript
import type { IExecuteSingleFunctions, IN8nHttpFullResponse, INodeExecutionData } from 'n8n-workflow';
import { NodeApiError } from 'n8n-workflow';

export const handleErrors = async function (
  this: IExecuteSingleFunctions,
  items: INodeExecutionData[],
  response: IN8nHttpFullResponse,
): Promise<INodeExecutionData[]> {
  if (response.statusCode >= 400) {
    const errorBody = response.body as { message?: string; error?: string };
    throw new NodeApiError(this.getNode(), {
      message: errorBody.message || errorBody.error || `HTTP ${response.statusCode}`,
      httpCode: String(response.statusCode),
    });
  }
  return items;
};
```

**Selective error ignoring:** You can ignore only specific status codes:
```typescript
ignoreHttpStatusErrors: { except: [401, 403] },  // Still throw on auth errors
```

### Generic Pagination

The `generic` pagination type uses expression-based configuration with `$response` and `$request` variables to handle APIs with token/link-based pagination:

```typescript
routing: {
  request: {
    method: 'GET',
    url: '/items',
  },
  send: { paginate: true },
  operations: {
    pagination: {
      type: 'generic',
      properties: {
        // Expression that evaluates to true/false — continue paginating?
        continue: '={{ !!$response.body?.nextPageToken }}',
        // Request config for the next page — merged with original request
        request: {
          url: '={{ $response.body?.nextLink ?? $request.url }}',
          qs: {
            pageToken: '={{ $response.body?.nextPageToken ?? "" }}',
          },
        },
      },
    },
  },
}
```

**OData-style pagination** (Microsoft/SharePoint pattern):
```typescript
operations: {
  pagination: {
    type: 'generic',
    properties: {
      continue: '={{ !!$response.body?.["@odata.nextLink"] }}',
      request: {
        url: '={{ $response.body?.["@odata.nextLink"] ?? $request.url }}',
        qs: {
          $select: '={{ !!$response.body?.["@odata.nextLink"] ? undefined : $request.qs?.$select }}',
        },
      },
    },
  },
}
```

**Key variables in generic pagination expressions:**
- `$response.body` — parsed response body from the last request
- `$response.headers` — response headers
- `$response.statusCode` — HTTP status code
- `$request` — the current request options (url, qs, body, headers)
- `$version` — node type version number

### Cursor-Based Pagination

For cursor-based APIs (common in modern REST APIs), create a reusable pagination function:

```typescript
import type { IExecutePaginationFunctions, INodeExecutionData, IDataObject, DeclarativeRestApiSettings } from 'n8n-workflow';

export const getCursorPaginator = () => {
  return async function cursorPagination(
    this: IExecutePaginationFunctions,
    requestOptions: DeclarativeRestApiSettings.ResultOptions,
  ): Promise<INodeExecutionData[]> {
    if (!requestOptions.options.qs) {
      requestOptions.options.qs = {};
    }

    let executions: INodeExecutionData[] = [];
    let nextCursor: string | undefined = undefined;
    const returnAll = this.getNodeParameter('returnAll', true) as boolean;

    do {
      requestOptions.options.qs.cursor = nextCursor;
      const responseData = await this.makeRoutingRequest(requestOptions);

      const lastItem = responseData[responseData.length - 1]?.json;
      nextCursor = lastItem?.nextCursor as string | undefined;

      // Extract items from response data array
      for (const page of responseData) {
        const items = page.json.data as IDataObject[];
        if (items) {
          executions.push(...items.map((item) => ({ json: item })));
        }
      }
    } while (returnAll && nextCursor);

    return executions;
  };
};
```

**Usage in operation definition:**
```typescript
{
  name: 'Get Many',
  value: 'getAll',
  action: 'Get many items',
  routing: {
    request: {
      method: 'GET',
      url: '/items',
      returnFullResponse: true,
    },
    send: { paginate: true },
    operations: {
      pagination: getCursorPaginator(),
    },
  },
}
```

**Key: `IExecutePaginationFunctions`** extends `IExecuteSingleFunctions` with `makeRoutingRequest()` — this lets your custom function delegate individual requests back to n8n's routing engine (which handles auth, preSend, and postReceive automatically).

### Dynamic Base URL from Credentials

When supporting both cloud and self-hosted deployments, use an expression in `requestDefaults.baseURL` to read from credentials:

```typescript
requestDefaults: {
  baseURL: '={{ !$credentials.customBaseUrl ? "https://api.example.com/v1" : $credentials.baseUrl.replace(new RegExp("/$"), "") }}',
  url: '',
  headers: {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  },
},
```

The corresponding credential would have:
```typescript
{
  displayName: 'Custom Base URL',
  name: 'customBaseUrl',
  type: 'boolean',
  default: false,
  description: 'Whether to use a custom base URL (for self-hosted instances)',
},
{
  displayName: 'Base URL',
  name: 'baseUrl',
  type: 'string',
  default: '',
  placeholder: 'https://my-instance.example.com/api/v1',
  displayOptions: { show: { customBaseUrl: [true] } },
},
```

**Accessing credentials in preSend/postReceive:**
```typescript
const credentials = await this.getCredentials('myServiceApi');
const baseUrl = credentials.customBaseUrl
  ? String(credentials.baseUrl).replace(/\/$/, '')
  : 'https://api.example.com/v1';
```

### File Upload with preSend

Use a preSend function to convert binary input data into multipart form-data for file upload operations:

```typescript
// eslint-disable-next-line @n8n/community-nodes/no-restricted-imports
import type FormData from 'form-data';
import type { IBinaryData, IExecuteSingleFunctions, IHttpRequestOptions } from 'n8n-workflow';
import { NodeOperationError } from 'n8n-workflow';

export const uploadFile = async function (
  this: IExecuteSingleFunctions,
  requestOptions: IHttpRequestOptions,
): Promise<IHttpRequestOptions> {
  const binaryPropertyName = this.getNodeParameter('binaryPropertyName') as string;
  const item = this.getInputData();

  if (!item.binary?.[binaryPropertyName]) {
    throw new NodeOperationError(
      this.getNode(),
      `No binary data property "${binaryPropertyName}" exists on item!`,
    );
  }

  const binaryProperty = item.binary[binaryPropertyName] as IBinaryData;
  const binaryDataBuffer = await this.helpers.getBinaryDataBuffer(binaryPropertyName);

  // form-data is available in n8n's runtime
  // eslint-disable-next-line @typescript-eslint/no-require-imports, @n8n/community-nodes/no-restricted-imports
  const FormDataConstructor = require('form-data');
  const formData = new FormDataConstructor() as FormData;
  formData.append('file', binaryDataBuffer, binaryProperty.fileName);

  requestOptions.body = formData;
  requestOptions.headers = {
    ...requestOptions.headers,
    ...formData.getHeaders(),
  };

  return requestOptions;
};
```

**Operation wiring for upload:**
```typescript
{
  name: 'Upload File',
  value: 'uploadFile',
  action: 'Upload a file',
  routing: {
    request: {
      method: 'POST',
      url: '=/records/{{$parameter.recordId}}/files',
    },
    send: {
      paginate: false,
      preSend: [uploadFile],
      type: 'body',
    },
    output: {
      postReceive: [
        { type: 'set', properties: { value: '={{ { "success": true } }}' } },
      ],
    },
  },
}
```

### File Download with postReceive

For downloading files, set `encoding: 'arraybuffer'` and `returnFullResponse: true` on the request, then use a custom postReceive to convert the response buffer into n8n binary data:

```typescript
// Operation:
{
  name: 'Download File',
  value: 'downloadFile',
  action: 'Download a file',
  routing: {
    request: {
      method: 'GET',
      returnFullResponse: true,
      encoding: 'arraybuffer',
      url: '=/records/{{$parameter.recordId}}/files/{{$parameter.fileName}}',
    },
    output: {
      postReceive: [handleFileDownload],  // See custom postReceive section above
    },
  },
}
```

### Modular Operations Structure

For complex nodes with many operations, split operations and action handlers into separate files:

```
nodes/MyService/
├── MyService.node.ts              # Main entry — imports and wires everything
├── actions/
│   ├── record/
│   │   ├── createRecords.ts       # preSend function for create
│   │   ├── updateRecords.ts       # preSend function for update
│   │   └── listRecords.ts         # preSend function for list filters
│   └── file/
│       ├── uploadFile.ts          # preSend function for upload
│       └── handleIncomingFile.ts  # postReceive function for download
├── methods/
│   ├── listSearch.ts              # listSearch methods for resource locators
│   ├── loadOptions.ts             # loadOptions methods for dropdowns
│   └── resourceMapping.ts         # resourceMapping methods for resource mapper
├── shared/
│   └── parameters.ts              # Shared parameter definitions
├── transport/
│   └── index.ts                   # API request helpers (apiRequest, apiRequestAllItems)
├── v1/
│   ├── operations.ts              # v1 operation definitions with routing
│   ├── parameters.ts              # v1-specific parameters
│   └── index.ts                   # Re-exports
└── v2/
    ├── operations.ts              # v2 operation definitions with routing
    ├── parameters.ts              # v2-specific parameters (resourceMapper, etc.)
    └── index.ts                   # Re-exports
```

**Main entry file pattern:**
```typescript
import type { INodeType, INodeTypeDescription } from 'n8n-workflow';
import { v1Operations } from './v1';
import { v2Operations, v2Parameters } from './v2';
import { sharedParameters } from './shared';
import { listSearch, loadOptions, resourceMapping } from './methods';

export class MyService implements INodeType {
  description: INodeTypeDescription = {
    // ... standard description fields
    version: [1, 2],
    properties: [
      // v2 Resource param first (for v2 UI)
      ...v2Parameters.filter(p => p.name === 'resource'),
      // v1 operations
      {
        displayName: 'Operation',
        name: 'operation',
        type: 'options',
        noDataExpression: true,
        options: v1Operations,
        default: 'list',
        displayOptions: { show: { '@version': [1] } },
      },
      // v2 operations
      {
        displayName: 'Operation',
        name: 'operation',
        type: 'options',
        noDataExpression: true,
        options: v2Operations,
        default: 'list',
        displayOptions: { show: { '@version': [2] } },
      },
      // Shared + version-specific parameters
      ...sharedParameters,
      ...v2Parameters.filter(p => p.name !== 'resource'),
    ],
  };

  methods = {
    listSearch,
    loadOptions,
    resourceMapping,
  };
}
```

### TypeScript Type Reference

Quick reference for the key TypeScript interfaces used in declarative node development. All types are from `n8n-workflow`.

**INodePropertyRouting** — Core routing interface placed on operations or parameters:
```typescript
interface INodePropertyRouting {
  operations?: IN8nRequestOperations;       // Pagination config
  output?: INodeRequestOutput;              // postReceive transforms, maxResults
  request?: IHttpRequestOptions;            // HTTP method, URL, headers, qs
  send?: INodeRequestSend;                  // preSend, paginate, body property mapping
}
```

**INodeRequestSend** — Controls how parameter values are sent:
```typescript
interface INodeRequestSend {
  preSend?: PreSendAction[];                // Functions to transform the request before sending
  paginate?: boolean | string;              // Enable/disable pagination (can be expression)
  property?: string;                        // Body/query property name (supports = prefix for expressions)
  propertyInDotNotation?: boolean;          // Default: true — dot paths create nested objects
  type?: 'body' | 'query';                 // Where to send the value
  value?: string;                           // Value expression (e.g., '={{$value}}')
}
```

**INodeRequestOutput** — Controls response handling:
```typescript
interface INodeRequestOutput {
  maxResults?: number | string;             // Limit results (can be expression)
  postReceive?: PostReceiveAction[];        // Transform chain
}
```

**PostReceiveAction** — Union of 7 built-in transform types + custom functions:
```typescript
type PostReceiveAction =
  | IPostReceiveBinaryData       // { type: 'binaryData', properties: { destinationProperty: string } }
  | IPostReceiveFilter           // { type: 'filter', properties: { pass: string } }
  | IPostReceiveLimit            // { type: 'limit', properties: { maxResults: number | string } }
  | IPostReceiveRootProperty     // { type: 'rootProperty', properties: { property: string } }
  | IPostReceiveSet              // { type: 'set', properties: { value: string } }
  | IPostReceiveSetKeyValue      // { type: 'setKeyValue', properties: { [key: string]: string } }
  | IPostReceiveSort             // { type: 'sort', properties: { key: string } }
  | ((                           // Custom async function
      this: IExecuteSingleFunctions,
      items: INodeExecutionData[],
      response: IN8nHttpFullResponse,
    ) => Promise<INodeExecutionData[]>);
```

All built-in transforms inherit `IPostReceiveBase`:
```typescript
interface IPostReceiveBase {
  enabled?: boolean | string;    // Conditionally enable/disable (can be expression)
  errorMessage?: string;         // Custom error message if transform fails
}
```

**PreSendAction** — Function signature for request transformation:
```typescript
type PreSendAction = (
  this: IExecuteSingleFunctions,
  requestOptions: IHttpRequestOptions,
) => Promise<IHttpRequestOptions>;
```

**IN8nRequestOperations** — Pagination configuration:
```typescript
interface IN8nRequestOperations {
  pagination:
    | IN8nRequestOperationPaginationOffset   // Built-in offset pagination
    | IN8nRequestOperationPaginationGeneric  // Built-in generic/token pagination
    | ((                                     // Custom pagination function
        this: IExecutePaginationFunctions,
        requestOptions: DeclarativeRestApiSettings.ResultOptions,
      ) => Promise<INodeExecutionData[]>);
}
```

**Offset pagination:**
```typescript
interface IN8nRequestOperationPaginationOffset {
  type: 'offset';
  properties: {
    limitParameter: string;      // Query/body param name for page size
    offsetParameter: string;     // Query/body param name for offset
    pageSize: number;            // Items per page
    rootProperty?: string;       // JSON path to the items array in response
    type: 'body' | 'query';     // Where limit/offset params are sent
  };
}
```

**Generic pagination:**
```typescript
interface IN8nRequestOperationPaginationGeneric {
  type: 'generic';
  properties: {
    continue: string;            // Expression → boolean: keep paginating?
    request: IHttpRequestOptions; // Merged into next request (supports expressions)
  };
}
```

**IHttpRequestOptions** — Key fields for declarative routing:
```typescript
interface IHttpRequestOptions {
  url: string;
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD';
  headers?: Record<string, string>;
  qs?: Record<string, any>;              // Query string parameters
  body?: any;
  encoding?: 'arraybuffer' | 'blob' | 'document' | 'json' | 'text' | 'stream';
  returnFullResponse?: boolean;          // Return headers + status in postReceive
  ignoreHttpStatusErrors?: boolean;      // Don't throw on 4xx/5xx
  timeout?: number;                      // Request timeout in ms
  arrayFormat?: 'indices' | 'brackets' | 'repeat' | 'comma';  // QS array serialization
}
```

**IExecutePaginationFunctions** — Available in custom pagination functions:
```typescript
// Extends IExecuteSingleFunctions with:
interface IExecutePaginationFunctions extends IExecuteSingleFunctions {
  makeRoutingRequest(
    requestOptions: DeclarativeRestApiSettings.ResultOptions,
  ): Promise<INodeExecutionData[]>;
  // Delegates to n8n's routing engine (handles auth, preSend, postReceive)
}
```

**IN8nHttpFullResponse** — Available in custom postReceive when `returnFullResponse: true`:
```typescript
interface IN8nHttpFullResponse {
  body: any;
  headers: Record<string, string>;
  statusCode: number;
  statusMessage?: string;
}
```

**ResourceMapperField** — Field definition returned by `resourceMapperMethod`:
```typescript
interface ResourceMapperField {
  id: string;
  displayName: string;
  required: boolean;
  defaultMatch: boolean;
  display: boolean;
  type: FieldType;               // 'string' | 'number' | 'boolean' | 'dateTime' | 'object' | 'array' | ...
  canBeUsedToMatch: boolean;
  readOnly?: boolean;
  removed?: boolean;
  options?: INodePropertyOptions[];
}
```
