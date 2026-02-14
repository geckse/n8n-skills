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

All available postReceive transforms:

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

      // Custom transform:
      { type: 'set', properties: { value: '={{ { "id": $response.body.id } }}' } },
    ],
  },
}
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
