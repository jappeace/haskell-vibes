---
name: write-skill
description: Create a new Claude Code skill. Use when the user asks to write, create, or make a skill, slash command, or custom command for Claude Code.
argument-hint: <skill-name> [description]
---

# Writing a Claude Code Skill

You are creating a new skill for Claude Code. Read the reference below thoroughly, then build the skill the user described.

## Step 1: Gather requirements

Before writing anything, determine:

1. **Skill name**: from `$ARGUMENTS[0]`, or ask the user. Must be lowercase letters, numbers, and hyphens only (max 64 chars).
2. **Purpose**: What should the skill do? From `$ARGUMENTS[1..]` or ask the user.
3. **Scope**: Where should it live?
   - **Personal** (`~/.claude/skills/<name>/SKILL.md`) — available across all projects for this user.
   - **Project** (`.claude/skills/<name>/SKILL.md`) — committed to version control, shared with the team.
4. **Invocation model**: Who triggers it?
   - Both user and Claude (default)
   - User only (`disable-model-invocation: true`) — for workflows with side effects like deploy, commit, send messages.
   - Claude only (`user-invocable: false`) — for background knowledge/context.
5. **Execution context**: Where does it run?
   - Inline (default) — runs in the current conversation, has access to conversation history.
   - Forked subagent (`context: fork`) — runs in isolation, no conversation history. Good for heavy tasks. Optionally set `agent: Explore`, `agent: Plan`, `agent: general-purpose`, or a custom agent name.
6. **Does it need arguments?** If so, use `$ARGUMENTS`, `$ARGUMENTS[N]`, or `$N` placeholders.
7. **Does it need dynamic context?** Use `` !`command` `` syntax for shell commands that run before the prompt is sent.
8. **Does it need supporting files?** Templates, examples, scripts — put them in the skill directory and reference from SKILL.md.

## Step 2: Write the SKILL.md

Create the directory and write the file. Follow this structure:

### Frontmatter (YAML between `---` markers)

All fields are optional. Only `description` is recommended.

| Field                      | Description                                                                                         |
|:---------------------------|:----------------------------------------------------------------------------------------------------|
| `name`                     | Display name. If omitted, uses directory name. Lowercase, numbers, hyphens only, max 64 chars.      |
| `description`              | What the skill does and when to use it. Claude uses this to decide when to load it automatically.    |
| `argument-hint`            | Hint shown during autocomplete. Example: `[issue-number]` or `[filename] [format]`.                 |
| `disable-model-invocation` | `true` to prevent Claude from auto-loading. For manual `/name` invocation only.                     |
| `user-invocable`           | `false` to hide from `/` menu. For background knowledge Claude loads when relevant.                  |
| `allowed-tools`            | Tools Claude can use without permission when this skill is active. E.g. `Read, Grep, Glob`.         |
| `model`                    | Model to use when skill is active.                                                                  |
| `effort`                   | Effort level: `low`, `medium`, `high`, `max`.                                                       |
| `context`                  | `fork` to run in an isolated subagent.                                                              |
| `agent`                    | Subagent type when `context: fork`. Options: `Explore`, `Plan`, `general-purpose`, or custom agent. |
| `hooks`                    | Hooks scoped to this skill's lifecycle.                                                             |

### Content (markdown after frontmatter)

The body contains instructions Claude follows when the skill is invoked. Two types:

- **Reference content**: Knowledge Claude applies to current work (conventions, patterns, style guides). Runs inline.
- **Task content**: Step-by-step instructions for a specific action. Often `disable-model-invocation: true`.

### String substitutions available in content

| Variable               | Description                                              |
|:-----------------------|:---------------------------------------------------------|
| `$ARGUMENTS`           | All arguments passed when invoking.                      |
| `$ARGUMENTS[N]`       | Specific argument by 0-based index.                      |
| `$N`                   | Shorthand for `$ARGUMENTS[N]`.                           |
| `${CLAUDE_SESSION_ID}` | Current session ID.                                      |
| `${CLAUDE_SKILL_DIR}`  | Directory containing the SKILL.md file.                  |

### Dynamic context injection

Use `` !`command` `` to run shell commands before the skill content is sent to Claude:

```
## Current branch info
- Branch: !`git branch --show-current`
- Status: !`git status --short`
```

The command output replaces the placeholder. This is preprocessing — Claude only sees the result.

## Step 3: Add supporting files (if needed)

For complex skills, keep SKILL.md under 500 lines. Move detailed reference material to separate files:

```
my-skill/
├── SKILL.md           # Main instructions (required)
├── reference.md       # Detailed docs (loaded when needed)
├── template.md        # Template for Claude to fill in
├── examples/
│   └── sample.md      # Example output
└── scripts/
    └── helper.sh      # Script Claude can execute
```

Reference them from SKILL.md so Claude knows when to load them:

```markdown
## Additional resources
- For complete API details, see [reference.md](reference.md)
- For usage examples, see [examples.md](examples.md)
```

## Step 4: Verify

After writing the skill:
1. Confirm the SKILL.md file exists at the correct path.
2. Read it back to check for syntax errors in the frontmatter.
3. Tell the user how to test it (e.g. `/skill-name` or by asking something that matches the description).
4. Mention that skill descriptions are loaded into context so Claude knows what's available, but full content only loads when invoked.

## Guidelines

- Keep descriptions specific so Claude triggers the skill at the right time (not too broad, not too narrow).
- Use `disable-model-invocation: true` for anything with side effects (deploy, commit, send messages, delete).
- Use `context: fork` for heavy tasks that don't need conversation history.
- Use `allowed-tools` to restrict what Claude can do (e.g. read-only skills).
- Include the word "ultrathink" in skill content to enable extended thinking.
- Skills sharing the same name: enterprise > personal > project precedence.
- Plugin skills use `plugin-name:skill-name` namespace.
- Tip for generating visual output: bundle a script (Python, etc.) that generates an HTML file and have the skill instruct Claude to run it.
