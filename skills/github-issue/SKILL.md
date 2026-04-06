---
name: github-issue
description: >
  Write GitHub issues that stay in the problem domain. Use when creating issues,
  filing bug reports, or requesting features on any repository. Ensures issues
  describe what's wrong or needed without prescribing implementation details.
argument-hint: "[owner/repo] [brief topic]"
disable-model-invocation: false
allowed-tools: Bash, Read, Grep, Glob, Agent, WebFetch
---

# Writing a GitHub Issue

Create a GitHub issue on `$0` about: `$1`.

If arguments are missing, ask the user which repository and what the issue is about.

## Core Principle

**Stay in the problem domain.** Describe *what* is wrong or *what* is needed.
Never prescribe *how* to fix it — implementation is the maintainer's decision.

## Process

1. **Research**: Read relevant source files to understand the current state. Use Grep/Glob/Read to find code related to the topic. Understand what exists before writing.
2. **Draft** the issue following the structure below.
3. **Review the draft**: Remove any sentence that tells the maintainer *how* to implement something. Keep sentences that describe *what* the problem or need is.
4. **Create**: Use `gh issue create --repo <owner/repo>` with the final content.
5. **Report**: Show the user the issue URL.

## Issue Structure

```markdown
## Problem

[1-3 paragraphs: what is wrong or missing.
Observable behaviour, limitations, pain points.
No suggested fixes.]

## Use case

[Who runs into this, what they're trying to do,
why the current state blocks or degrades their workflow.
Include a concrete real scenario.]

## Current behaviour

[What happens now. Error messages, log output if applicable.
For feature requests: the current workaround or why none exists.]

## Expected behaviour

[The desired *outcome*, not the mechanism to achieve it.]
```

Add `## Environment` (versions, OS, config) only for bug reports where it matters.

## What's acceptable

- Locating the problem area: "This affects `Widget.hs` and the C bridge layer"
- Describing a limitation: "The `TextInput` constructor has no way to express this"
- Platform context: "Android's `EditText` supports numeric keyboards" — helps frame the problem without dictating the solution

## What to avoid

- Suggesting types, data structures, or API shapes
- Proposing specific libraries or dependencies to adopt
- Including code patches or diffs
- Dictating file layouts or architectural decisions
- Phrases like "the fix is to...", "I suggest adding...", "here's a patch..."
