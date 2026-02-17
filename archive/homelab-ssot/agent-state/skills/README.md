# Shared Skills

This directory contains reusable skill definitions that any agent can invoke.

Skills are defined as markdown files with:
- **Description**: What the skill does
- **Required MCPs**: Which MCP servers must be active
- **Steps**: How to execute the skill
- **Example**: A concrete usage example

## Adding a New Skill

1. Create a new `.md` file in this directory
2. Follow the format above
3. Commit to `main`
4. All agents will pick it up on next sync
