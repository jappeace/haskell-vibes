---
name: verify-test-fails
description: Before committing test code, verify new tests fail on master. Trigger when adding test files, adding test cases to existing files, implementing TDD, fixing bugs with regression tests, or adding tests for new features. Also trigger when running cabal test or nix-build after writing tests — the verification step should happen before the final commit.
---

# Verify tests fail on master

When writing tests for a change (bug fix or new feature), each test MUST fail on master. A test that passes on both master and the feature branch proves nothing — it does not distinguish "code works" from "code was already like that."

- **Bug fix**: test should fail on master (proving the bug exists), pass on your branch
- **New feature**: test should fail on master (feature doesn't exist yet), pass on your branch

Both cases reduce to: **test must fail on master, pass on your branch.**

## Procedure

1. **Write the tests on your branch** as normal.
2. **Before committing**, stash or note the source changes, check out the base (e.g. `master`), apply only the test file and wiring (cabal/Main.hs), and run the tests.
3. **Every test must fail** (crash, wrong result, compile error, or missing export) on master. If a test passes, it does not exercise the change.
4. **Investigate passing tests**: trace the code path with the specific test input. Find where it short-circuits, returns a default, or otherwise avoids the code you changed.
5. **Replace weak inputs** with ones that force execution through the changed code path.
6. Return to your branch, update the tests, and verify they pass with the change.

## Common trap: lazy evaluation short-circuits

In Haskell (and other lazy languages), expressions connected by `<$>`, `<*>`, `>>=`, or `>>` in `Maybe`/`Either`/parser monads short-circuit on failure. If an early step returns `Nothing`/`Left`, later steps containing the changed code are **never evaluated**.

### Example from mysql-haskell

The timestamp parser:
```haskell
LocalTime <$> dateParser bs <*> timeParser (B.unsafeDrop 11 bs)
```

Test input `"abc"`:
- `dateParser "abc"` calls `readDecimal "abc"` which returns `Nothing` (no digits)
- `fmap LocalTime Nothing` = `Nothing`
- `Nothing <*> timeParser (B.unsafeDrop 11 bs)` = `Nothing`
- `B.unsafeDrop 11 bs` is **never forced** — the bug is not exercised

Test input `"2024-01-01"` (10 bytes):
- `dateParser "2024-01-01"` succeeds, returns `Just date`
- `Just (LocalTime date) <*> timeParser (B.unsafeDrop 11 "2024-01-01")`
- `B.unsafeDrop 11` on 10 bytes is UB — the bug IS exercised

### The principle

Choose inputs that make code **succeed past the guarding steps** so execution reaches the changed operation. Inputs that fail early prove the early guard works, not that your change matters.

## Checklist

- [ ] Each test targets a specific changed operation (buggy code or new feature)
- [ ] Test input is designed to reach that operation (not short-circuit before it)
- [ ] Test fails on master (verified by running on base branch)
- [ ] Test passes on feature branch
- [ ] If a test passed on master, investigate why and fix the input
