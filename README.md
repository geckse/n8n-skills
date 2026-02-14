# n8n-skills

Agent Skills for building custom [n8n](https://n8n.io) community nodes.

## Skills

| Skill | Description |
|-------|-------------|
| [building-n8n-nodes](skills/building-n8n-nodes/) | Scaffolds, implements, tests, and publishes custom n8n nodes using official best practices. Covers declarative and programmatic styles, all credential/auth patterns, trigger nodes, and verification requirements. |

## Install via Claude Code Plugin Marketplace

Add this marketplace and install the plugin:

```
/plugin marketplace add geckse/n8n-skills
/plugin install n8n-skills@n8n-skills
```

Once installed, Claude will automatically activate the skill when you ask about building n8n nodes.

## Manual Usage

Copy or symlink a skill directory from `skills/` into your agent's skills folder. The agent will discover it automatically via the `SKILL.md` frontmatter.

## Format

Skills follow the [Agent Skills](https://agentskills.io) open specification and are packaged as a [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code).
