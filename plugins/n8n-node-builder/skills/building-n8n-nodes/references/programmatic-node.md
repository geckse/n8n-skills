# Programmatic Node Reference

Complete template and patterns for building a programmatic-style n8n node.

## Table of Contents

1. [Complete Base File Template](#complete-base-file-template)
2. [The execute() Method](#the-execute-method)
3. [Item Processing Loop](#item-processing-loop)
4. [Error Handling Patterns](#error-handling-patterns)
5. [HTTP Request Patterns](#http-request-patterns)
6. [Item Linking (pairedItem)](#item-linking-paireditem)
7. [Binary Data Handling](#binary-data-handling)
8. [Trigger Node Template](#trigger-node-template)
9. [Full Versioning Structure](#full-versioning-structure)
10. [Complete Working Example](#complete-working-example)

## Complete Base File Template

```typescript
import type { IExecuteFunctions } from 'n8n-workflow';
import {
  IDataObject,
  INodeExecutionData,
  INodeType,
  INodeTypeDescription,
  JsonObject,
  NodeApiError,
  NodeConnectionType,
  NodeOperationError,
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
        ],
        default: 'contact',
      },
      // Operations
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
          },
          {
            name: 'Get',
            value: 'get',
            action: 'Get a contact',
            description: 'Retrieve a contact by ID',
          },
          {
            name: 'Get Many',
            value: 'getAll',
            action: 'Get many contacts',
            description: 'Retrieve multiple contacts',
          },
          {
            name: 'Update',
            value: 'update',
            action: 'Update a contact',
            description: 'Update an existing contact',
          },
          {
            name: 'Delete',
            value: 'delete',
            action: 'Delete a contact',
            description: 'Delete a contact',
          },
        ],
        default: 'create',
      },
      // Fields
      {
        displayName: 'Contact ID',
        name: 'contactId',
        type: 'string',
        required: true,
        default: '',
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
        displayOptions: {
          show: {
            resource: ['contact'],
            operation: ['create'],
          },
        },
      },
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
          },
          {
            displayName: 'Last Name',
            name: 'lastName',
            type: 'string',
            default: '',
          },
        ],
      },
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
        typeOptions: { minValue: 1 },
        default: 50,
        displayOptions: {
          show: {
            resource: ['contact'],
            operation: ['getAll'],
            returnAll: [false],
          },
        },
        description: 'Max number of results to return',
      },
    ],
  };

  async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
    const items = this.getInputData();
    const returnData: INodeExecutionData[] = [];
    const resource = this.getNodeParameter('resource', 0) as string;
    const operation = this.getNodeParameter('operation', 0) as string;

    for (let i = 0; i < items.length; i++) {
      try {
        if (resource === 'contact') {
          if (operation === 'create') {
            const email = this.getNodeParameter('email', i) as string;
            const additionalFields = this.getNodeParameter(
              'additionalFields', i,
            ) as IDataObject;

            const body: IDataObject = { email, ...additionalFields };

            const response = await this.helpers.httpRequestWithAuthentication.call(
              this,
              'myServiceApi',
              {
                method: 'POST',
                url: 'https://api.myservice.com/v1/contacts',
                body,
              },
            );

            const executionData = this.helpers.constructExecutionMetaData(
              this.helpers.returnJsonArray(response as IDataObject),
              { itemData: { item: i } },
            );
            returnData.push(...executionData);
          }

          if (operation === 'get') {
            const contactId = this.getNodeParameter('contactId', i) as string;

            const response = await this.helpers.httpRequestWithAuthentication.call(
              this,
              'myServiceApi',
              {
                method: 'GET',
                url: `https://api.myservice.com/v1/contacts/${contactId}`,
              },
            );

            const executionData = this.helpers.constructExecutionMetaData(
              this.helpers.returnJsonArray(response as IDataObject),
              { itemData: { item: i } },
            );
            returnData.push(...executionData);
          }

          if (operation === 'getAll') {
            const returnAll = this.getNodeParameter('returnAll', i) as boolean;

            if (returnAll) {
              // Use a helper that handles pagination (see GenericFunctions.ts)
              const responseData = await myServiceApiRequestAllItems.call(
                this, 'contacts', 'GET', '/contacts',
              );
              const executionData = this.helpers.constructExecutionMetaData(
                this.helpers.returnJsonArray(responseData),
                { itemData: { item: i } },
              );
              returnData.push(...executionData);
            } else {
              const limit = this.getNodeParameter('limit', i) as number;
              const response = await this.helpers.httpRequestWithAuthentication.call(
                this,
                'myServiceApi',
                {
                  method: 'GET',
                  url: 'https://api.myservice.com/v1/contacts',
                  qs: { limit },
                },
              );
              const contacts = (response as IDataObject).data as IDataObject[];
              const executionData = this.helpers.constructExecutionMetaData(
                this.helpers.returnJsonArray(contacts),
                { itemData: { item: i } },
              );
              returnData.push(...executionData);
            }
          }

          if (operation === 'update') {
            const contactId = this.getNodeParameter('contactId', i) as string;
            const additionalFields = this.getNodeParameter(
              'additionalFields', i,
            ) as IDataObject;

            const response = await this.helpers.httpRequestWithAuthentication.call(
              this,
              'myServiceApi',
              {
                method: 'PUT',
                url: `https://api.myservice.com/v1/contacts/${contactId}`,
                body: additionalFields,
              },
            );

            const executionData = this.helpers.constructExecutionMetaData(
              this.helpers.returnJsonArray(response as IDataObject),
              { itemData: { item: i } },
            );
            returnData.push(...executionData);
          }

          if (operation === 'delete') {
            const contactId = this.getNodeParameter('contactId', i) as string;

            await this.helpers.httpRequestWithAuthentication.call(
              this,
              'myServiceApi',
              {
                method: 'DELETE',
                url: `https://api.myservice.com/v1/contacts/${contactId}`,
              },
            );

            const executionData = this.helpers.constructExecutionMetaData(
              this.helpers.returnJsonArray({ deleted: true }),
              { itemData: { item: i } },
            );
            returnData.push(...executionData);
          }
        }
      } catch (error) {
        if (this.continueOnFail()) {
          const executionErrorData = this.helpers.constructExecutionMetaData(
            this.helpers.returnJsonArray({ error: (error as Error).message }),
            { itemData: { item: i } },
          );
          returnData.push(...executionErrorData);
          continue;
        }
        throw new NodeApiError(this.getNode(), error as JsonObject);
      }
    }

    return [returnData];
  }
}
```

## The execute() Method

The execute method is called once per node execution. It receives all input items and must return all output items.

```typescript
async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
  // Get all items from the previous node
  const items = this.getInputData();

  // Storage for output items
  const returnData: INodeExecutionData[] = [];

  // Get parameters that don't change per item (index 0)
  const resource = this.getNodeParameter('resource', 0) as string;
  const operation = this.getNodeParameter('operation', 0) as string;

  // Loop over each input item
  for (let i = 0; i < items.length; i++) {
    // Get parameters that may change per item (using expression)
    const value = this.getNodeParameter('fieldName', i) as string;

    // Process and push results
    returnData.push({
      json: { /* result data */ },
      pairedItem: { item: i },
    });
  }

  // Return: array of arrays (one per output connector)
  return [returnData];
}
```

## Item Processing Loop

Key method calls inside the loop:

```typescript
// Get a parameter value (resolves expressions for item i)
const name = this.getNodeParameter('name', i) as string;

// Get optional fields from Additional Fields
const additionalFields = this.getNodeParameter('additionalFields', i) as IDataObject;

// Get a parameter with a default fallback
const limit = this.getNodeParameter('limit', i, 50) as number;

// Access the raw input item
const inputItem = items[i].json;

// Clone input data (never mutate directly)
const newItem = { ...items[i].json };
```

## Error Handling Patterns

### Standard try/catch with continueOnFail

```typescript
for (let i = 0; i < items.length; i++) {
  try {
    // Your logic
  } catch (error) {
    if (this.continueOnFail()) {
      returnData.push({
        json: { error: (error as Error).message },
        pairedItem: { item: i },
      });
      continue;
    }
    // Re-throw as a structured n8n error
    throw new NodeApiError(this.getNode(), error as JsonObject);
  }
}
```

### Specific HTTP Error Handling

```typescript
try {
  const response = await this.helpers.httpRequestWithAuthentication.call(
    this, 'myApi', options,
  );
} catch (error) {
  if ((error as any).httpCode === '404') {
    throw new NodeApiError(this.getNode(), error as JsonObject, {
      message: 'Resource not found',
      description: `The item with ID "${itemId}" does not exist. Check the ID.`,
    });
  }
  if ((error as any).httpCode === '429') {
    throw new NodeApiError(this.getNode(), error as JsonObject, {
      message: 'Rate limit exceeded',
      description: 'Too many requests. Try again later.',
    });
  }
  throw new NodeApiError(this.getNode(), error as JsonObject);
}
```

### Validation Errors

```typescript
if (!email.includes('@')) {
  throw new NodeOperationError(
    this.getNode(),
    'Invalid email address',
    { itemIndex: i },
  );
}
```

## HTTP Request Patterns

### Basic GET

```typescript
const response = await this.helpers.httpRequestWithAuthentication.call(
  this,
  'myServiceApi',
  {
    method: 'GET',
    url: `https://api.example.com/items/${id}`,

  },
);
```

### POST with Body

```typescript
const response = await this.helpers.httpRequestWithAuthentication.call(
  this,
  'myServiceApi',
  {
    method: 'POST',
    url: 'https://api.example.com/items',
    body: {
      name: 'New Item',
      description: 'A description',
    },

  },
);
```

### GET with Query Parameters

```typescript
const response = await this.helpers.httpRequestWithAuthentication.call(
  this,
  'myServiceApi',
  {
    method: 'GET',
    url: 'https://api.example.com/items',
    qs: {
      page: 1,
      per_page: 50,
      sort: 'created_at',
    },

  },
);
```

### Custom Headers

```typescript
const response = await this.helpers.httpRequestWithAuthentication.call(
  this,
  'myServiceApi',
  {
    method: 'GET',
    url: 'https://api.example.com/items',
    headers: {
      'X-Custom-Header': 'value',
    },

  },
);
```

## Item Linking (constructExecutionMetaData)

Every output item must link back to its source input. The modern approach uses `constructExecutionMetaData`:

```typescript
// Recommended: constructExecutionMetaData (handles pairedItem automatically)
const executionData = this.helpers.constructExecutionMetaData(
  this.helpers.returnJsonArray(responseData),
  { itemData: { item: i } },
);
returnData.push(...executionData);

// Also works for arrays (e.g., getAll returns multiple items):
const results = response.data as IDataObject[];
const executionData = this.helpers.constructExecutionMetaData(
  this.helpers.returnJsonArray(results),
  { itemData: { item: i } },
);
returnData.push(...executionData);
```

Legacy manual approach (still works but less preferred):
```typescript
returnData.push({
  json: response,
  pairedItem: { item: i },
});
```

## Binary Data Handling

For nodes that work with files:

```typescript
// Receiving binary data from previous node:
const binaryData = items[i].binary;
if (binaryData && binaryData.data) {
  const buffer = await this.helpers.getBinaryDataBuffer(i, 'data');
  // Use buffer...
}

// Returning binary data:
const binaryProperty = await this.helpers.prepareBinaryData(
  buffer,
  'filename.pdf',
  'application/pdf',
);

returnData.push({
  json: { success: true },
  binary: { data: binaryProperty },
  pairedItem: { item: i },
});
```

## Trigger Node Patterns

Trigger nodes are always programmatic. They differ from action nodes in several key ways:

| Aspect | Action Node | Trigger Node |
|--------|------------|--------------|
| `group` | `['transform']` | `['trigger']` |
| `inputs` | `[NodeConnectionType.Main]` | `[]` (EMPTY) |
| Method | `execute()` | `webhook()`, `poll()`, or `trigger()` |
| Class name | `MyService` | `MyServiceTrigger` |
| File name | `MyService.node.ts` | `MyServiceTrigger.node.ts` |

### Pattern 1: Webhook Trigger (Auto-Registered)

The external service supports API-based webhook registration. n8n registers/deregisters automatically when the workflow is activated/deactivated.

```typescript
import {
  IHookFunctions, IWebhookFunctions, INodeType,
  INodeTypeDescription, IWebhookResponseData,
  NodeConnectionType,
} from 'n8n-workflow';

export class MyServiceTrigger implements INodeType {
  description: INodeTypeDescription = {
    displayName: 'My Service Trigger',
    name: 'myServiceTrigger',
    icon: 'file:myservice.svg',
    group: ['trigger'],
    version: 1,
    subtitle: '={{$parameter["event"]}}',
    description: 'Starts workflow when My Service events occur',
    defaults: { name: 'My Service Trigger' },
    inputs: [],                            // NO inputs for triggers
    outputs: [NodeConnectionType.Main],
    credentials: [{ name: 'myServiceApi', required: true }],
    webhooks: [
      {
        name: 'default',
        httpMethod: 'POST',
        responseMode: 'onReceived',
        path: 'webhook',
      },
    ],
    properties: [
      {
        displayName: 'Event',
        name: 'event',
        type: 'options',
        options: [
          { name: 'Contact Created', value: 'contact.created' },
          { name: 'Deal Updated', value: 'deal.updated' },
        ],
        default: 'contact.created',
        required: true,
      },
    ],
  };

  webhookMethods = {
    default: {
      async checkExists(this: IHookFunctions): Promise<boolean> {
        const webhookData = this.getWorkflowStaticData('node');
        if (webhookData.webhookId) {
          return true;
        }
        return false;
      },

      async create(this: IHookFunctions): Promise<boolean> {
        const webhookData = this.getWorkflowStaticData('node');
        const webhookUrl = this.getNodeWebhookUrl('default');
        const event = this.getNodeParameter('event') as string;

        // Register webhook with external API
        const response = await myServiceApiRequest.call(this, 'POST', '/webhooks', {
          url: webhookUrl,
          events: [event],
        });

        // Store registration ID for cleanup
        webhookData.webhookId = response.id;
        return true;
      },

      async delete(this: IHookFunctions): Promise<boolean> {
        const webhookData = this.getWorkflowStaticData('node');
        const webhookId = webhookData.webhookId as string;

        if (webhookId) {
          await myServiceApiRequest.call(this, 'DELETE', `/webhooks/${webhookId}`);
          delete webhookData.webhookId;
        }
        return true;
      },
    },
  };

  async webhook(this: IWebhookFunctions): Promise<IWebhookResponseData> {
    const bodyData = this.getBodyData();
    return {
      workflowData: [this.helpers.returnJsonArray(bodyData)],
    };
  }
}
```

**Lifecycle:**
1. **Workflow activated** → `checkExists()` → if false → `create()` registers webhook
2. **Event received** → `webhook()` processes payload → triggers workflow
3. **Workflow deactivated** → `delete()` removes webhook registration

Use `this.getWorkflowStaticData('node')` to persist data (webhook IDs) between lifecycle calls. This data survives n8n restarts.

### Pattern 2: Simple Webhook (Manual URL)

No auto-registration — the user manually configures the webhook URL in the external service.

```typescript
export class MyServiceTrigger implements INodeType {
  description: INodeTypeDescription = {
    displayName: 'My Service Trigger',
    name: 'myServiceTrigger',
    group: ['trigger'],
    version: 1,
    description: 'Starts workflow on My Service webhook',
    defaults: { name: 'My Service Trigger' },
    inputs: [],
    outputs: [NodeConnectionType.Main],
    webhooks: [
      {
        name: 'default',
        httpMethod: 'POST',
        responseMode: 'onReceived',
        path: 'webhook',
      },
    ],
    properties: [],
  };

  // No webhookMethods needed — user configures URL manually
  async webhook(this: IWebhookFunctions): Promise<IWebhookResponseData> {
    const bodyData = this.getBodyData();
    return {
      workflowData: [this.helpers.returnJsonArray(bodyData)],
    };
  }
}
```

### Pattern 3: Poll Trigger

n8n polls the external API on a schedule, checking for new data since the last poll.

```typescript
import {
  IPollFunctions, INodeType, INodeTypeDescription,
  INodeExecutionData, NodeConnectionType,
} from 'n8n-workflow';

export class MyServiceTrigger implements INodeType {
  description: INodeTypeDescription = {
    displayName: 'My Service Trigger',
    name: 'myServiceTrigger',
    group: ['trigger'],
    version: 1,
    description: 'Starts workflow when new items appear',
    defaults: { name: 'My Service Trigger' },
    inputs: [],
    outputs: [NodeConnectionType.Main],
    polling: true,                         // REQUIRED for poll triggers
    credentials: [{ name: 'myServiceApi', required: true }],
    properties: [],
  };

  async poll(this: IPollFunctions): Promise<INodeExecutionData[][] | null> {
    const webhookData = this.getWorkflowStaticData('node');
    const lastChecked = webhookData.lastTimeChecked as string
      || new Date().toISOString();

    // Query API for items created/updated since lastChecked
    const items = await myServiceApiRequest.call(
      this, 'GET', '/items', {}, { since: lastChecked },
    );

    // Update last checked time
    webhookData.lastTimeChecked = new Date().toISOString();

    if (items.length === 0) {
      return null;                         // Return null = no new data, don't trigger
    }

    return [this.helpers.returnJsonArray(items)];
  }
}
```

**Key points:**
- Set `polling: true` in the description
- `poll()` returns `INodeExecutionData[][] | null` — return `null` when there are no new items
- Track state with `getWorkflowStaticData('node')` to avoid re-processing old data

### Pattern 4: Event/Stream Trigger

Long-running listener for message queues, SSE, or WebSocket connections:

```typescript
import {
  ITriggerFunctions, ITriggerResponse, INodeType,
  INodeTypeDescription, NodeConnectionType,
} from 'n8n-workflow';

export class MyServiceTrigger implements INodeType {
  description: INodeTypeDescription = {
    displayName: 'My Service Trigger',
    name: 'myServiceTrigger',
    group: ['trigger'],
    version: 1,
    inputs: [],
    outputs: [NodeConnectionType.Main],
    properties: [/* ... */],
  };

  async trigger(this: ITriggerFunctions): Promise<ITriggerResponse> {
    // Set up listener
    const client = new MyServiceClient(/* ... */);
    client.on('message', (data) => {
      this.emit([this.helpers.returnJsonArray(data)]);
    });
    await client.connect();

    // Return cleanup + manual trigger functions
    const closeFunction = async () => {
      await client.disconnect();
    };
    const manualTriggerFunction = async () => {
      // Emit test data for manual workflow runs
      this.emit([this.helpers.returnJsonArray({ test: true })]);
    };

    return { closeFunction, manualTriggerFunction };
  }
}
```

**Key points:**
- `this.emit()` pushes data into the workflow whenever an event arrives
- `closeFunction` runs on workflow deactivation — clean up connections
- `manualTriggerFunction` provides test data when user clicks "Test Workflow"

### Trigger Common Mistakes

| Mistake | Fix |
|---------|-----|
| Trigger node with `inputs: [NodeConnectionType.Main]` | Use `inputs: []` — triggers have NO inputs |
| Missing `polling: true` on poll trigger | Required for n8n to schedule the poll |
| Not storing webhook ID in static data | Use `getWorkflowStaticData('node')` to persist between restarts |
| `poll()` returning empty array instead of null | Return `null` for no new data (empty array triggers with no items) |
| Using `IExecuteFunctions` in trigger | Use `IWebhookFunctions`, `IPollFunctions`, or `ITriggerFunctions` |
| Forgetting `delete()` in webhookMethods | Always clean up webhook registrations on deactivation |

## Full Versioning Structure

When you need fundamentally different behavior between versions:

```
nodes/MyNode/
├── MyNode.node.ts          # Version router
├── v1/
│   ├── MyNodeV1.node.ts    # INodeType for v1
│   └── actions/
└── v2/
    ├── MyNodeV2.node.ts    # INodeType for v2
    └── actions/
```

The main file:

```typescript
import { INodeTypeBaseDescription, IVersionedNodeType } from 'n8n-workflow';
import { NodeVersionedType } from 'n8n-core';
import { MyNodeV1 } from './v1/MyNodeV1.node';
import { MyNodeV2 } from './v2/MyNodeV2.node';

export class MyNode extends NodeVersionedType {
  constructor() {
    const baseDescription: INodeTypeBaseDescription = {
      displayName: 'My Node',
      name: 'myNode',
      icon: 'file:myNode.svg',
      group: ['transform'],
      description: 'Interact with My Service',
      defaultVersion: 2,
    };

    const nodeVersions: IVersionedNodeType['nodeVersions'] = {
      1: new MyNodeV1(baseDescription),
      2: new MyNodeV2(baseDescription),
    };

    super(nodeVersions, baseDescription);
  }
}
```

## GenericFunctions.ts Pattern

Create a shared helper file to keep your execute method clean:

```typescript
// nodes/MyService/GenericFunctions.ts
import type {
  IExecuteFunctions,
  IHookFunctions,
  ILoadOptionsFunctions,
  IPollFunctions,
  IWebhookFunctions,
  IHttpRequestOptions,
  IDataObject,
  JsonObject,
} from 'n8n-workflow';
import { NodeApiError } from 'n8n-workflow';

const BASE_URL = 'https://api.myservice.com/v1';

export async function myServiceApiRequest(
  this: IExecuteFunctions | IHookFunctions | ILoadOptionsFunctions | IPollFunctions | IWebhookFunctions,
  method: string,
  endpoint: string,
  body: IDataObject = {},
  qs: IDataObject = {},
): Promise<any> {
  const options: IHttpRequestOptions = {
    method,
    url: `${BASE_URL}${endpoint}`,
    body,
    qs,
  };
  try {
    return await this.helpers.httpRequestWithAuthentication.call(this, 'myServiceApi', options);
  } catch (error) {
    throw new NodeApiError(this.getNode(), error as JsonObject);
  }
}

export async function myServiceApiRequestAllItems(
  this: IExecuteFunctions | IHookFunctions | ILoadOptionsFunctions,
  propertyName: string,
  method: string,
  endpoint: string,
  body: IDataObject = {},
  qs: IDataObject = {},
): Promise<IDataObject[]> {
  const returnData: IDataObject[] = [];
  let page = 1;
  let hasMore = true;

  while (hasMore) {
    const response = await myServiceApiRequest.call(
      this, method, endpoint, body, { ...qs, page, per_page: 100 },
    );
    const items = response[propertyName] as IDataObject[];
    returnData.push(...items);
    hasMore = items.length === 100;
    page++;
  }

  return returnData;
}
```

### Pagination Variants

The `apiRequestAllItems` function above uses page-number pagination. Here are the other common patterns:

**Cursor-based pagination:**
```typescript
export async function myServiceApiRequestAllItems(
  this: IExecuteFunctions,
  method: string,
  endpoint: string,
  body: IDataObject = {},
  qs: IDataObject = {},
): Promise<IDataObject[]> {
  const returnData: IDataObject[] = [];
  let cursor: string | undefined;

  do {
    if (cursor) qs.cursor = cursor;
    const response = await myServiceApiRequest.call(this, method, endpoint, body, qs);
    returnData.push(...response.results);
    cursor = response.next_cursor;
  } while (cursor);

  return returnData;
}
```

**Offset-based pagination:**
```typescript
export async function myServiceApiRequestAllItems(
  this: IExecuteFunctions,
  propertyName: string,
  method: string,
  endpoint: string,
  body: IDataObject = {},
  qs: IDataObject = {},
): Promise<IDataObject[]> {
  const returnData: IDataObject[] = [];
  qs.limit = 100;
  qs.offset = 0;
  let responseItems: IDataObject[];

  do {
    const response = await myServiceApiRequest.call(this, method, endpoint, body, qs);
    responseItems = response[propertyName] as IDataObject[];
    returnData.push(...responseItems);
    qs.offset = (qs.offset as number) + (qs.limit as number);
  } while (responseItems.length === qs.limit);

  return returnData;
}
```

Then use in your node:
```typescript
import { myServiceApiRequest, myServiceApiRequestAllItems } from './GenericFunctions';

// In execute():
const response = await myServiceApiRequest.call(this, 'POST', '/contacts', body);
```

## Key Helpers Reference

| Method | Purpose |
|--------|---------|
| `this.getInputData()` | Get input items array |
| `this.getNodeParameter(name, index)` | Read a user-configured parameter |
| `this.getCredentials('credName')` | Retrieve stored credentials |
| `this.helpers.returnJsonArray(data)` | Wrap response as `INodeExecutionData[]` |
| `this.helpers.constructExecutionMetaData(data, { itemData })` | Link output to input items |
| `this.continueOnFail()` | Check if user enabled "Continue On Fail" |
| `this.helpers.httpRequest(options)` | Make HTTP request (unauthenticated) |
| `this.helpers.httpRequestWithAuthentication('credName', options)` | Authenticated HTTP request |

> **Deprecation note:** `this.helpers.requestWithAuthentication` and `IRequestOptions` are **deprecated**. Always use `httpRequestWithAuthentication` with `IHttpRequestOptions`. The new interface uses `url` (not `uri`) and defaults to JSON parsing (no `json: true` needed).

## Complete Working Example

See the template at the top of this document for a complete, copy-paste-ready programmatic node. It demonstrates all the key patterns: resource/operation routing with `returnAll`/`limit`, item processing, error handling with `continueOnFail`, `constructExecutionMetaData` for proper item linking, and the correct return format.
