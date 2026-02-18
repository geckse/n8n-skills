#!/usr/bin/env bash
#
# refresh-node-registry.sh
#
# Downloads the n8n node registries (official + community) and caches them
# locally as lightweight JSON files for the n8n-workflow-sdk skill.
#
# Run this periodically to keep the cache fresh:
#   bash plugins/n8n-workflow-sdk/skills/n8n-workflow-sdk/scripts/refresh-node-registry.sh
#
# What it does:
#   1. Fetches all pages from https://api.n8n.io/api/nodes (official nodes)
#   2. Fetches https://api.n8n.io/api/community-nodes
#   3. Strips heavy fields (icon buffers) to keep the index files small
#   4. Saves slim JSON index caches + a JSONL properties file to references/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS_DIR="$SCRIPT_DIR/../references"
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "$TEMP_DIR"' EXIT

echo "==> Fetching official n8n nodes registry..."

# Fetch all pages (pageSize=500 gets most in 2 requests)
PAGE=1
TOTAL_PAGES=1

while [ "$PAGE" -le "$TOTAL_PAGES" ]; do
  echo "    Fetching page $PAGE..."
  curl -s "https://api.n8n.io/api/nodes?pagination%5BpageSize%5D=500&pagination%5Bpage%5D=$PAGE" \
    -o "$TEMP_DIR/official_page_$PAGE.json"

  if [ "$PAGE" -eq 1 ]; then
    TOTAL_PAGES=$(python3 -c "
import json
with open('$TEMP_DIR/official_page_1.json') as f:
    data = json.load(f)
print(data['meta']['pagination']['pageCount'])
")
    echo "    Total pages: $TOTAL_PAGES"
  fi

  PAGE=$((PAGE + 1))
done

echo "==> Processing official nodes into slim cache..."

TEMP_DIR="$TEMP_DIR" REFS_DIR="$REFS_DIR" python3 << 'PYEOF'
import json, glob, os

temp_dir = os.environ.get("TEMP_DIR", "/tmp")
refs_dir = os.environ.get("REFS_DIR", ".")

# Collect all entries from all pages
all_nodes = []
for page_file in sorted(glob.glob(f"{temp_dir}/official_page_*.json")):
    with open(page_file) as f:
        data = json.load(f)
        all_nodes.extend(data.get("data", []))

# Build slim cache: only fields agents need
slim_nodes = []
for entry in all_nodes:
    attrs = entry.get("attributes", {})
    slim_nodes.append({
        "name": attrs.get("name", ""),
        "displayName": attrs.get("displayName", ""),
        "version": attrs.get("version"),
        "description": attrs.get("description", ""),
        "group": attrs.get("group", "[]"),
        "alias": ((attrs.get("codex") or {}).get("data") or {}).get("alias", []),
        "categories": ((attrs.get("codex") or {}).get("data") or {}).get("categories", []),
    })

# Sort by displayName for easy browsing
slim_nodes.sort(key=lambda n: n["displayName"].lower())

output = {
    "_meta": {
        "source": "https://api.n8n.io/api/nodes",
        "total": len(slim_nodes),
        "description": "Cached n8n official node registry. Run refresh-node-registry.sh to update.",
    },
    "nodes": slim_nodes,
}

output_path = f"{refs_dir}/node-registry-official.json"
with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"    Saved {len(slim_nodes)} official nodes to {output_path}")

# --- Also build JSONL properties file (one greppable line per node) ---

def slim_option(opt):
    if isinstance(opt, dict):
        result = {}
        if 'name' in opt: result['name'] = opt['name']
        if 'value' in opt: result['value'] = opt['value']
        if 'description' in opt: result['description'] = opt['description']
        if 'options' in opt:
            result['options'] = [slim_option(o) for o in opt['options']]
        if 'values' in opt:
            result['values'] = [slim_prop(v) for v in opt['values']]
        return result
    return opt

def slim_prop(prop):
    result = {}
    for key in ['name', 'type', 'default', 'required', 'description']:
        if key in prop:
            result[key] = prop[key]
    if 'options' in prop:
        result['options'] = [slim_option(o) for o in prop['options']]
    if 'displayOptions' in prop:
        result['displayOptions'] = prop['displayOptions']
    return result

props_entries = []
for entry in all_nodes:
    attrs = entry.get("attributes", {})
    name = attrs.get("name", "")
    raw_props = attrs.get("properties", {}).get("data", [])
    if raw_props:
        props_entries.append({"node": name, "properties": [slim_prop(p) for p in raw_props]})

props_entries.sort(key=lambda e: e["node"])

props_path = f"{refs_dir}/node-registry-properties.jsonl"
with open(props_path, "w") as f:
    for entry in props_entries:
        f.write(json.dumps(entry) + "\n")

print(f"    Saved {len(props_entries)} node property sets to {props_path}")
PYEOF

echo "==> Fetching community nodes registry..."

curl -s "https://api.n8n.io/api/community-nodes" -o "$TEMP_DIR/community.json"

echo "==> Processing community nodes into slim cache..."

TEMP_DIR="$TEMP_DIR" REFS_DIR="$REFS_DIR" python3 << 'PYEOF'
import json, os

temp_dir = os.environ.get("TEMP_DIR", "/tmp")
refs_dir = os.environ.get("REFS_DIR", ".")

with open(f"{temp_dir}/community.json") as f:
    data = json.load(f)

entries = data.get("data", [])

slim_nodes = []
for entry in entries:
    attrs = entry.get("attributes", {})
    node_desc = attrs.get("nodeDescription", {})
    slim_nodes.append({
        "name": node_desc.get("name", node_desc.get("originalName", "")),
        "displayName": attrs.get("displayName", node_desc.get("displayName", "")),
        "packageName": attrs.get("packageName", ""),
        "version": node_desc.get("version"),
        "description": node_desc.get("description", attrs.get("description", "")),
        "authorName": attrs.get("authorName", ""),
        "isOfficialNode": attrs.get("isOfficialNode", False),
    })

slim_nodes.sort(key=lambda n: n["displayName"].lower())

output = {
    "_meta": {
        "source": "https://api.n8n.io/api/community-nodes",
        "total": len(slim_nodes),
        "description": "Cached n8n community node registry. Run refresh-node-registry.sh to update.",
    },
    "nodes": slim_nodes,
}

output_path = f"{refs_dir}/node-registry-community.json"
with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"    Saved {len(slim_nodes)} community nodes to {output_path}")
PYEOF

echo ""
echo "==> Done! Registry caches updated:"
echo "    $REFS_DIR/node-registry-official.json      (slim index for lookups)"
echo "    $REFS_DIR/node-registry-community.json     (community nodes index)"
echo "    $REFS_DIR/node-registry-properties.jsonl   (node properties, one line per node)"
