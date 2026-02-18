# n8n-skills

Agent Skills for building custom [n8n](https://n8n.io) community nodes and creating n8n workflows programmatically.

## Plugins

| Plugin | Description |
|--------|-------------|
| [n8n-node-builder](plugins/n8n-node-builder/) | Scaffolds, implements, tests, and publishes custom n8n nodes using official best practices. Covers declarative and programmatic styles, all credential/auth patterns, trigger nodes, and verification requirements. |
| [n8n-workflow-sdk](plugins/n8n-workflow-sdk/) | Builds, tests, validates, and manages n8n workflows programmatically using the `@n8n/workflow-sdk`. Covers workflow creation, JSON import/export, validation, code generation, AI agent workflows, and the full SDK API. |

## Install via Claude Code Plugin Marketplace

Add this marketplace and install the plugins:

```
/plugin marketplace add geckse/n8n-skills
/plugin install n8n-node-builder@n8n-skills
/plugin install n8n-workflow-sdk@n8n-skills
```

Once installed, Claude will automatically activate the appropriate skill — `n8n-node-builder` when you ask about building custom n8n nodes, and `n8n-workflow-sdk` when you ask about creating or managing n8n workflows with code.

## Manual Usage

Copy or symlink a skill directory from `plugins/<plugin-name>/skills/` into your agent's skills folder. The agent will discover it automatically via the `SKILL.md` frontmatter.

## Format

Skills follow the [Agent Skills](https://agentskills.io) open specification and are packaged as a [Claude Code plugin](https://code.claude.com/docs/en/plugins).
