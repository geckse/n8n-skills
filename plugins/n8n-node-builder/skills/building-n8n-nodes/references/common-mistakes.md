# Common Mistakes Reference

Error catalog for n8n node development. Each entry shows the wrong pattern and the correct fix.

## Table of Contents

1. [File Structure Errors](#file-structure-errors)
2. [Description Errors](#description-errors)
3. [Execute Method Errors](#execute-method-errors)
4. [Credential Errors](#credential-errors)
5. [Declarative Node Errors](#declarative-node-errors)
6. [Linter Errors](#linter-errors)
7. [Publishing Errors](#publishing-errors)
8. [Quick Fix Reference](#quick-fix-reference)

## File Structure Errors

### 1. Class name doesn't match filename

**Wrong:**
```
File: MyService.node.ts
Class: export class MyServiceNode implements INodeType  // "Node" suffix doesn't match
```

**Fix:** Class name must exactly match the filename (minus `.node.ts`):
```
File: MyService.node.ts
Class: export class MyService implements INodeType
```

### 2. Wrong npm package prefix

**Wrong:** `"name": "myservice-n8n-nodes"` or `"name": "n8n-myservice"`

**Fix:** Package name must start with `n8n-nodes-`:
```json
"name": "n8n-nodes-myservice"
```

### 3. Missing codex file

Every node needs a `.node.json` codex file alongside the `.node.ts` file. Without it, the node won't appear in search or have proper categorization.

### 4. Wrong paths in package.json n8n config

**Wrong:** Pointing to source files:
```json
"nodes": ["nodes/MyService/MyService.node.ts"]
```

**Fix:** Point to compiled output:
```json
"nodes": ["dist/nodes/MyService/MyService.node.js"]
```

## Description Errors

### 5. Missing noDataExpression on selectors

**Wrong:**
```typescript
{ displayName: 'Resource', name: 'resource', type: 'options', /* ... */ }
```

**Fix:** Always set `noDataExpression: true` on resource and operation selectors:
```typescript
{ displayName: 'Resource', name: 'resource', type: 'options', noDataExpression: true, /* ... */ }
```

### 6. Missing action field on operations

**Wrong:**
```typescript
options: [
  { name: 'Create', value: 'create' },
]
```

**Fix:** Every operation option needs an `action` field:
```typescript
options: [
  { name: 'Create', value: 'create', action: 'Create a contact' },
]
```

### 7. NodeConnectionType.Main — type-only in some versions

In some `n8n-workflow` versions, `NodeConnectionType` is exported **only as a type** (not a runtime value). Using it as a value will cause: `'NodeConnectionType' cannot be used as a value because it was exported using 'export type'`.

**Preferred (works everywhere):**
```typescript
inputs: [NodeConnectionType.Main],
outputs: [NodeConnectionType.Main],
```

**Fallback (if NodeConnectionType is type-only in your n8n-workflow version):**
```typescript
inputs: ['main'],
outputs: ['main'],
```

Check your installed `n8n-workflow` version. If the import fails at build time, use the string fallback.

### 8. Trigger node with non-empty inputs

**Wrong:**
```typescript
// Trigger node:
inputs: [NodeConnectionType.Main],  // Triggers don't have inputs
```

**Fix:**
```typescript
inputs: [],  // Trigger nodes have NO inputs
```

### 9. Expression prefix missing for dynamic URLs

**Wrong:**
```typescript
url: '/contacts/{{$parameter["contactId"]}}'  // Missing = prefix
```

**Fix:** Dynamic expressions in routing must start with `=`:
```typescript
url: '=/contacts/{{$parameter["contactId"]}}'  // = prefix required
```

## Execute Method Errors

### 10. Missing continueOnFail handling

**Wrong:**
```typescript
for (let i = 0; i < items.length; i++) {
  const data = await apiRequest.call(this, 'GET', '/items');
  returnData.push(...data);  // No error handling, no item linking
}
```

**Fix:** Wrap each item in try/catch with `continueOnFail()`:
```typescript
for (let i = 0; i < items.length; i++) {
  try {
    const data = await apiRequest.call(this, 'GET', '/items');
    const executionData = this.helpers.constructExecutionMetaData(
      this.helpers.returnJsonArray(data),
      { itemData: { item: i } },
    );
    returnData.push(...executionData);
  } catch (error) {
    if (this.continueOnFail()) {
      returnData.push(...this.helpers.constructExecutionMetaData(
        this.helpers.returnJsonArray({ error: (error as Error).message }),
        { itemData: { item: i } },
      ));
      continue;
    }
    throw error;
  }
}
```

### 11. Missing constructExecutionMetaData

**Wrong:**
```typescript
returnData.push(...this.helpers.returnJsonArray(responseData));  // No item linking
```

**Fix:** Always wrap with `constructExecutionMetaData` for proper item tracking:
```typescript
const executionData = this.helpers.constructExecutionMetaData(
  this.helpers.returnJsonArray(responseData),
  { itemData: { item: i } },
);
returnData.push(...executionData);
```

### 12. Not returning nested array

**Wrong:**
```typescript
return returnData;  // Must be INodeExecutionData[][]
```

**Fix:** The `execute()` method must return an array of arrays (one per output connector):
```typescript
return [returnData];  // Wrap in outer array
```

### 13. Delete operation returning wrong output

**Wrong:**
```typescript
returnData.push({ json: { success: true }, pairedItem: { item: i } });
```

**Fix:** Delete operations must return `{ deleted: true }` per n8n UX guidelines:
```typescript
returnData.push({ json: { deleted: true }, pairedItem: { item: i } });
```

This confirms the deletion succeeded and ensures the next node in the workflow receives a trigger item.

## Credential Errors

### 14. Wrong credential expression syntax

**Wrong:**
```typescript
headers: { Authorization: '={{$credential.apiKey}}' }   // singular
```

**Fix:** Always use `$credentials` (plural):
```typescript
headers: { Authorization: '={{$credentials.apiKey}}' }   // plural: $credentials
```

### 15. Missing password typeOptions on secrets

**Wrong:**
```typescript
{ displayName: 'API Key', name: 'apiKey', type: 'string', default: '' }
```

**Fix:**
```typescript
{ displayName: 'API Key', name: 'apiKey', type: 'string',
  typeOptions: { password: true }, default: '' }
```

### 16. Credential not registered in package.json

Even if the credential file exists, it won't load unless listed:
```json
"n8n": {
  "credentials": ["dist/credentials/MyServiceApi.credentials.js"]
}
```

### 17. Missing icon on credential class

The linter requires credentials to have an `icon` property:

```typescript
import type { Icon } from 'n8n-workflow';

export class MyServiceApi implements ICredentialType {
  name = 'myServiceApi';
  displayName = 'My Service API';
  icon: Icon = 'file:myservice.svg';  // SVG must be in credentials/ folder
  // ...
}
```

## Declarative Node Errors

### 18. Including execute() in a declarative node

If `requestDefaults` is present, n8n uses the routing engine. An `execute()` method will be **ignored**. Either use routing OR execute, not both.

### 19. Missing routing on operation options

**Wrong (declarative):**
```typescript
options: [{ name: 'Create', value: 'create', action: 'Create item' }]  // No routing
```

**Fix:**
```typescript
options: [{
  name: 'Create', value: 'create', action: 'Create item',
  routing: { request: { method: 'POST', url: '/items' } },
}]
```

### 25. Wrong preSend function signature

**Wrong:**
```typescript
// Missing proper this type, wrong return type
async function myPreSend(requestOptions: IHttpRequestOptions) {
  requestOptions.body = { data: 'test' };
  // Forgot to return requestOptions
}
```

**Fix:** preSend functions must use `IExecuteSingleFunctions` as `this` and return `Promise<IHttpRequestOptions>`:
```typescript
export const myPreSend = async function (
  this: IExecuteSingleFunctions,
  requestOptions: IHttpRequestOptions,
): Promise<IHttpRequestOptions> {
  requestOptions.body = { data: 'test' };
  return requestOptions;  // Must return the modified options
};
```

### 26. Missing returnFullResponse for custom postReceive

**Wrong:**
```typescript
routing: {
  request: {
    method: 'GET',
    url: '/files/download',
    encoding: 'arraybuffer',
    // Missing returnFullResponse — postReceive won't get headers
  },
  output: {
    postReceive: [handleFileDownload],
  },
}
```

**Fix:** Custom postReceive functions that need response headers require `returnFullResponse: true`:
```typescript
routing: {
  request: {
    method: 'GET',
    url: '/files/download',
    returnFullResponse: true,  // Required for postReceive to receive IN8nHttpFullResponse
    encoding: 'arraybuffer',
  },
  output: {
    postReceive: [handleFileDownload],
  },
}
```

### 27. Reading resourceLocator value without extractValue

**Wrong:**
```typescript
// In a listSearch or preSend method:
const teamId = this.getCurrentNodeParameter('teamId') as string;
// Returns { mode: 'list', value: 'abc123' } — an object, not a string!
```

**Fix:** Use `.value` on the returned object, or use `{ extractValue: true }`:
```typescript
// Option A: Access .value directly
const teamIdParam = this.getCurrentNodeParameter('teamId') as INodeParameterResourceLocator;
const teamId = teamIdParam.value as string;

// Option B: Use extractValue option (when available)
const teamId = this.getCurrentNodeParameter('teamId', { extractValue: true }) as string;
```

### 28. Missing paginate: false on non-list operations

**Wrong:**
```typescript
// Create operation without paginate: false
routing: {
  request: { method: 'POST', url: '/records' },
  send: {
    preSend: [createRecordBody],
    type: 'body',
    // Missing paginate: false — may trigger unexpected pagination
  },
}
```

**Fix:** Always set `paginate: false` on operations that should not paginate (Create, Update, Delete):
```typescript
routing: {
  request: { method: 'POST', url: '/records' },
  send: {
    paginate: false,
    preSend: [createRecordBody],
    type: 'body',
  },
}
```

### 29. Wrong postReceive function signature

**Wrong:**
```typescript
// Treating postReceive like preSend
async function handleResponse(
  this: IExecuteSingleFunctions,
  requestOptions: IHttpRequestOptions,
): Promise<IHttpRequestOptions> { ... }
```

**Fix:** Custom postReceive functions receive `(items, response)` and return `INodeExecutionData[]`:
```typescript
export const handleResponse = async function (
  this: IExecuteSingleFunctions,
  items: INodeExecutionData[],
  response: IN8nHttpFullResponse,
): Promise<INodeExecutionData[]> {
  // Transform items based on response
  return items;
};
```

### 30. Missing URL encoding for user-provided values in routing URLs

**Wrong:**
```typescript
url: '=/v3/contacts/{{$parameter.identifier}}'  // Email with @ will break the URL
```

**Fix:** Use `encodeURIComponent()` for user-provided values that may contain special characters:
```typescript
url: '=/v3/contacts/{{encodeURIComponent($parameter.identifier)}}'
```

### 31. Wrong property path expression for dynamic nested body fields

**Wrong:**
```typescript
routing: {
  send: {
    property: 'attributes.$parent.fieldName',  // Literal string, not evaluated
    type: 'body',
  },
}
```

**Fix:** Dynamic property paths must start with `=` and use `{{}}` for expressions:
```typescript
routing: {
  send: {
    property: '=attributes.{{$parent.fieldName}}',  // Evaluates to body.attributes[selectedField]
    type: 'body',
  },
}
```

Same for array indexing:
```typescript
property: '=items[{{$index}}].value',  // Not 'items[$index].value'
```

### 32. Missing ignoreHttpStatusErrors for custom error postReceive

**Wrong:**
```typescript
routing: {
  request: {
    method: 'DELETE',
    url: '=/items/{{$parameter.itemId}}',
    // Missing ignoreHttpStatusErrors — n8n throws before postReceive runs
  },
  output: {
    postReceive: [handleErrors],  // Never reached on 4xx/5xx
  },
}
```

**Fix:** Add `ignoreHttpStatusErrors: true` so your custom postReceive function can inspect the response:
```typescript
routing: {
  request: {
    method: 'DELETE',
    url: '=/items/{{$parameter.itemId}}',
    ignoreHttpStatusErrors: true,
  },
  output: {
    postReceive: [handleErrors],  // Now receives 4xx/5xx responses
  },
}
```

### 33. Offset pagination missing rootProperty

**Wrong:**
```typescript
operations: {
  pagination: {
    type: 'offset',
    properties: {
      limitParameter: 'limit',
      offsetParameter: 'offset',
      pageSize: 100,
      type: 'query',
      // Missing rootProperty — pagination can't find items in nested response
    },
  },
}
// API returns: { data: { items: [...] } }
```

**Fix:** Set `rootProperty` to the JSON path where the items array lives:
```typescript
operations: {
  pagination: {
    type: 'offset',
    properties: {
      limitParameter: 'limit',
      offsetParameter: 'offset',
      pageSize: 100,
      rootProperty: 'data.items',
      type: 'query',
    },
  },
}
```

### 34. Generic pagination continue expression always true

**Wrong:**
```typescript
operations: {
  pagination: {
    type: 'generic',
    properties: {
      continue: '={{ $response.body.nextPageToken }}',  // Non-empty string is truthy
      request: { qs: { pageToken: '={{ $response.body.nextPageToken }}' } },
    },
  },
}
```

**Fix:** Use `!!` to coerce to boolean, so empty strings and undefined become `false`:
```typescript
operations: {
  pagination: {
    type: 'generic',
    properties: {
      continue: '={{ !!$response.body?.nextPageToken }}',
      request: { qs: { pageToken: '={{ $response.body?.nextPageToken ?? "" }}' } },
    },
  },
}
```

### 35. Custom pagination function missing makeRoutingRequest

**Wrong:**
```typescript
// Using httpRequest directly in pagination — skips auth, preSend, postReceive
operations: {
  pagination: async function(this, requestOptions) {
    const response = await this.helpers.httpRequest(requestOptions.options);  // Wrong
    // ...
  },
}
```

**Fix:** Use `this.makeRoutingRequest()` which delegates to n8n's routing engine (handles auth, preSend, postReceive automatically):
```typescript
operations: {
  pagination: async function(this, requestOptions) {
    const responseData = await this.makeRoutingRequest(requestOptions);  // Correct
    // ...
  },
}
```

### 36. Using propertyInDotNotation when dots are literal

**Wrong:**
```typescript
// API field name contains a literal dot: "custom.field"
routing: {
  send: {
    property: 'custom.field',  // Creates body.custom.field (nested) instead of body["custom.field"]
    type: 'body',
  },
}
```

**Fix:** Set `propertyInDotNotation: false` when property names contain literal dots:
```typescript
routing: {
  send: {
    property: 'custom.field',
    propertyInDotNotation: false,  // Treats "custom.field" as a flat key
    type: 'body',
  },
}
```

## Linter Errors

### 20. Using deprecated request APIs

**Wrong:**
```typescript
import { IRequestOptions } from 'n8n-workflow';

const options: IRequestOptions = {
  method: 'GET',
  uri: 'https://api.example.com/items',
  json: true,
};
const response = await this.helpers.requestWithAuthentication.call(this, 'myServiceApi', options);
```

**Fix:** Use `IHttpRequestOptions` and `httpRequestWithAuthentication`:
```typescript
import type { IHttpRequestOptions } from 'n8n-workflow';

const options: IHttpRequestOptions = {
  method: 'GET',
  url: 'https://api.example.com/items',  // 'url' not 'uri'
  // No 'json: true' needed — JSON is the default
};
const response = await this.helpers.httpRequestWithAuthentication.call(this, 'myServiceApi', options);
```

### 21. Wrong list operation naming

**Wrong:**
```typescript
{ name: 'Get All', value: 'getAll', action: 'Get all contacts', description: 'Get all contacts' }
```

**Fix:** The linter enforces "Get Many":
```typescript
{ name: 'Get Many', value: 'getAll', action: 'Get many contacts', description: 'Get many contacts' }
```

### 22. Missing `import type` for type-only imports

The linter enforces `import type` for symbols used only as types (not as runtime values).

**Wrong:**
```typescript
import { INodeType, INodeTypeDescription, INodeExecutionData } from 'n8n-workflow';
// INodeExecutionData only used in type annotations, not at runtime
```

**Fix:**
```typescript
import type { INodeExecutionData } from 'n8n-workflow';
import { INodeType, INodeTypeDescription } from 'n8n-workflow';
```

**Rule of thumb:** If a symbol is only used in `: TypeName` annotations, function signatures, or `as TypeName` casts, import it with `import type`. If it's used as a value (e.g., `throw new NodeOperationError(...)`, `NodeConnectionType.Main`), use a regular import.

### 23. `no-credential-reuse` false positive on Windows

The `no-credential-reuse` rule has a bug when the project sits at the first directory level under a Windows drive root (e.g., `D:\my-project`).

**Workaround:** Either move the project deeper (e.g., `D:\projects\my-project`) or add an eslint-disable block:
```typescript
/* eslint-disable @n8n/community-nodes/no-credential-reuse */
credentials: [
  { name: 'myServiceApi', required: true },
],
/* eslint-enable @n8n/community-nodes/no-credential-reuse */
```

## Publishing Errors

### 24. `prepublishOnly` script blocks `npm publish`

The n8n-nodes-starter includes a `prepublishOnly` script that runs `n8n-node prerelease`, which blocks direct `npm publish`.

**Options:**
1. Use `npm run release` (uses release-it for versioning + publish)
2. Remove the `prepublishOnly` script from `package.json` and run `npm publish --access public` directly

## Quick Fix Reference

| Error | Fix |
|-------|-----|
| Node not appearing in editor | Check `package.json` n8n.nodes paths, rebuild, restart |
| "Cannot find credential" | Check credential `name` matches between node and credential file |
| Empty response data | Check `postReceive` rootProperty extracts correct JSON path |
| Item linking broken | Add `constructExecutionMetaData` with `{ itemData: { item: i } }` |
| displayOptions not working | Verify resource/operation values match exactly (case-sensitive) |
| Expression not resolving | Use `=` prefix: `'=/path/{{$parameter.id}}'` not `'/path/{{$parameter.id}}'` |
| `requestWithAuthentication` deprecated | Switch to `httpRequestWithAuthentication` with `IHttpRequestOptions` |
| `uri` property error | Use `url` instead of `uri` in `IHttpRequestOptions` |
| Missing `usableAsTool` lint warning | Add `usableAsTool: true` to node description |
| "Get All" lint error | Change to "Get Many" / "Get many" in name, action, description |
| `no-credential-reuse` false positive | Move project deeper than drive root, or eslint-disable |
| `prepublishOnly` blocks publish | Remove the script or use `npm run release` |
| `NodeConnectionType` type-only error | Use string `'main'` as fallback |
| `execute()` ignored in declarative node | Remove execute or remove requestDefaults — can't use both |
| `$credential` not resolving | Use `$credentials` (plural) in expressions |
| Return type error in execute | Return `[returnData]` not `returnData` |
| Delete returns `{ success: true }` | Use `{ deleted: true }` per n8n UX guidelines |
| preSend not modifying request | Return the modified `requestOptions` — forgetting to return is a common error |
| postReceive not receiving headers | Add `returnFullResponse: true` to the operation's `routing.request` |
| resourceLocator returns object | Use `.value` on the result or pass `{ extractValue: true }` to `getCurrentNodeParameter` |
| Create/Update triggering pagination | Add `paginate: false` to `routing.send` on non-list operations |
| Custom postReceive wrong signature | Use `(items: INodeExecutionData[], response: IN8nHttpFullResponse)` not `(requestOptions)` |
| URL breaks with special characters | Use `encodeURIComponent()` in routing URL expressions for user values |
| Dynamic property path not evaluated | Use `=` prefix and `{{}}`: `'=attributes.{{$parent.fieldName}}'` not `'attributes.$parent.fieldName'` |
| Custom error handler never reached | Add `ignoreHttpStatusErrors: true` to the operation's `routing.request` |
| Offset pagination returns no data | Set `rootProperty` to the JSON path of the items array in the response |
| Generic pagination loops forever | Use `!!` in `continue` expression: `'={{ !!$response.body?.nextToken }}'` |
| Custom pagination skips auth | Use `this.makeRoutingRequest()` not `this.helpers.httpRequest()` |
| Dot in property name creates nesting | Set `propertyInDotNotation: false` on `routing.send` for literal dots |
