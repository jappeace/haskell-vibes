---
name: ci-watch
description: >
  Watch a GitHub Actions CI run without burning through API rate limits.
  Use when waiting for CI to pass, monitoring a PR's checks, or watching
  a specific workflow run. Prevents the common mistake of polling too
  frequently and exhausting the 5000 requests/hour GitHub API budget.
argument-hint: "[PR-number-or-run-URL]"
disable-model-invocation: true
allowed-tools: Bash, Read
---

# CI Watch — Rate-Limit-Aware CI Monitoring

You are monitoring a GitHub Actions CI run. Follow these rules strictly to
avoid exhausting the GitHub REST API rate limit (5000 requests/hour).

## Step 1: Identify what to watch

Use the argument `<args>` to determine the target:

- **PR number** (e.g. `170`): watch checks on that PR
- **Run URL** (e.g. `https://github.com/.../actions/runs/12345`): watch that run
- **No argument**: find the most recent run for the current branch

Determine the repo from the current git remote:
```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

## Step 2: Check rate limit FIRST

Before ANY `gh` API call, always check remaining quota:

```bash
gh api rate_limit --jq '.resources.core | "remaining: \(.remaining)/\(.limit), resets: \(.reset | todate)"'
```

- If **remaining < 100**: STOP. Tell the user the rate limit is low and when it resets. Do NOT make further API calls.
- If **remaining < 500**: Use minimal polling (single status check only, no log fetching).
- If **remaining >= 500**: Normal operation.

## Step 3: Get initial status

Make ONE call to get the current state:

**For a PR:**
```bash
gh pr checks <number> 2>&1 || true
```

**For a run:**
```bash
gh run view <run-id> 2>&1 || true
```

## Step 4: Determine wait strategy

Based on the current status:

| Status | Action |
|--------|--------|
| All checks passed | Report success, done |
| Any check failed | Report failure, offer to fetch logs (1 API call) |
| Checks still running | Wait and re-check (see intervals below) |
| Checks not started / queued | Wait longer before first check |

### Polling intervals (MANDATORY)

- **First check**: wait **3 minutes** after push before first status check
- **Subsequent checks**: wait **5 minutes** between polls
- **If queued (not started)**: wait **8 minutes**
- **Near completion (>75% jobs done)**: can reduce to **3 minutes**
- **NEVER poll more frequently than every 2 minutes**

Use `sleep` in the background or tell the user when to check back. Each poll
costs 1 API call. A typical CI run of 30 minutes = 6-10 API calls total.

## Step 5: Report results

When CI finishes (all jobs complete):

**On success:**
```
CI passed: all N jobs green.
```

**On failure:**
Fetch the failed job's log with ONE call:
```bash
gh run view <run-id> --log-failed 2>&1 | tail -100
```

Report the failure reason concisely.

## Budget accounting

Keep a mental count of API calls made during this watch session.
Each of these costs 1+ calls:
- `gh pr checks` — 1 call
- `gh run view` — 1 call
- `gh run view --log` — 1-3 calls (fetches log artifacts)
- `gh run view --log-failed` — 1-2 calls
- `gh api rate_limit` — 1 call (but doesn't count against core limit)

**Target: complete an entire CI watch in under 15 API calls.**

## Anti-patterns (DO NOT DO)

- Polling every 30 seconds or every minute
- Fetching full logs (`--log`) just to check status — use `--log-failed` only on failure
- Running `gh pr checks` in a tight loop
- Fetching logs for ALL jobs when only one failed
- Making API calls without checking rate limit first
- Using `gh api` for things `gh run view` already provides

## Example session

```
# 1. Check rate limit
$ gh api rate_limit --jq '.resources.core | ...'
remaining: 4892/5000

# 2. Initial status
$ gh pr checks 170
✓ nix-build        pass    2m30s
* android           in_progress
* android-emulator  in_progress
✓ ios              pass    4m10s
* watchos           queued

# 3. Two jobs still running, one queued. Wait 5 minutes.
#    (Tell the user: "3 jobs still in progress, checking again in 5 minutes")

# ... 5 minutes later ...

# 4. Re-check rate limit, then status
$ gh pr checks 170
✓ All checks passed

# Total API calls: 5 (2 rate checks + 2 status checks + 1 initial repo query)
```
