# claude-gate

The end-of-turn gate for the vibes Claude Code container, as one Haskell binary.

It replaces the three bash hooks that used to live in `../hooks`
(`record-edit.sh`, `reset-turn-state.sh`, `stop-gate.sh`). The logic was about
600 lines of bash with embedded `jq`, mostly the transcript walking and JSON
shuffling, which had become hard to read and impossible to test. Here that logic
is typed and unit tested.

## Subcommands

The binary reads one hook JSON object on stdin and dispatches on its argument.
`../settings.json` wires each Claude Code hook to a subcommand:

| Subcommand          | Hook event   | What it does                                                        |
| ------------------- | ------------ | ------------------------------------------------------------------- |
| `claude-gate record` | PostToolUse  | Append the edit to the per-turn review stack (filters binaries etc.) |
| `claude-gate reset`  | UserPromptSubmit | Wipe the previous turn's per-turn state                          |
| `claude-gate stop-gate` | Stop      | Phase A rule review, then Phase B verification nudge                 |

## Phases of the Stop gate

- **Working-hours check (before everything).** A plain clock check, no
  model: when the Stop fires outside CLAUDE.md's rest windows (22:45-07:00
  NL, or Sunday) the gate injects one warning per turn ("warning outside
  working hours, see claude.md") and the worker decides what to do with
  it. The Amsterdam clock is computed from the EU DST rule in code because
  the containers ship no zoneinfo and a named TZ silently falls back to
  UTC. Disable with `CLAUDE_SKIP_HOURS_CHECK=1`.
- **Phase A (rule review).** Claim the turn's review stack and review every diff
  in one reviewer call against the rules corpus (global and project `CLAUDE.md`
  plus the skills matching the touched file types). Violations block the Stop
  with the findings so the main-loop model can fix or rebut, and the loop
  repeats until clean.
- **Phase B (verification).** Once review is clean, and only if the turn touched
  state, ask the model to verify its work through external observation. A
  one-shot flag makes it fire at most once per turn.

Disable rule review with `CLAUDE_SKIP_RULE_CHECK=1`, verification with
`CLAUDE_SKIP_VERIFY_CHECK=1`.

## Build and test

```
nix-build nix/ci.nix    # builds the binary, runs the tests, runs hlint
```

The container builds this via `callCabal2nix ./gate` in the top-level
`../default.nix`, so the binary ships on `PATH` inside the image.
