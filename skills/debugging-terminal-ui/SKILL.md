---
name: debugging-terminal-ui
description: >
  Debug and interact with terminal UI programs (vim, htop, ncurses apps, etc.) using tmux as a TTY proxy.
  Use when verifying TUI configuration, testing keybindings, or interacting with any interactive terminal program.
  Also trigger when the user asks to "open" or "use" an interactive program like vim, nano, less, top, etc.
user-invocable: false
---

# Debugging Terminal UIs via tmux

## The Problem

The Bash tool runs commands non-interactively — there is no TTY. Interactive terminal programs
(vim, htop, nano, less, etc.) require a TTY for real-time keystroke input and screen output.
You cannot start vim and type into it directly.

## The Solution: tmux as a TTY Proxy

Use tmux to provide a virtual terminal. The workflow is:

1. **Start** the TUI program inside a detached tmux session
2. **Send keystrokes** with `tmux send-keys`
3. **Read the screen** with `tmux capture-pane`
4. **Repeat** steps 2-3 as needed
5. **Clean up** with `tmux kill-session`

Programs not available in PATH can be brought in via `nix-shell -p`.

## Core Commands

### Start a session
```bash
# Wrap in nix-shell if the program isn't installed
nix-shell -p tmux PROGRAM --run "tmux new-session -d -s SESSION_NAME -x 80 -y 24 'PROGRAM ARGS'"
```

The `-x 80 -y 24` sets a predictable terminal size for consistent screen captures.

### Send keystrokes
```bash
nix-shell -p tmux PROGRAM --run "tmux send-keys -t SESSION_NAME 'keys here' Enter"
```

Key reference for `send-keys`:
- `Enter`, `Escape`, `Space`, `Tab`, `BSpace` (backspace)
- `Up`, `Down`, `Left`, `Right`
- `C-a` (Ctrl+a), `M-x` (Alt+x)
- Literal text is sent character by character
- Separate keys with spaces: `'i' 'hello' Escape` (enter insert mode, type hello, press Esc)

### Read the screen
```bash
nix-shell -p tmux PROGRAM --run "tmux capture-pane -t SESSION_NAME -p"
```

The `-p` flag prints to stdout. Without it, the capture goes to a tmux buffer.

### Clean up
```bash
nix-shell -p tmux PROGRAM --run "tmux kill-session -t SESSION_NAME"
```

## Important Notes

- **Always use the same `nix-shell -p` wrapper** for every tmux command in a session,
  because the tmux server socket lives inside the nix-shell environment. If you drop
  the wrapper, tmux won't find the running session.
- **Add a `sleep 1`** after starting a program if it has a slow startup, before
  sending keys or capturing the pane.
- **Vim-specific**: use `vim -es -c` for non-interactive scripted checks when you
  don't need to see the UI (e.g. querying a setting value). Use tmux only when you
  need to verify visual output or test interactive keybindings.
- **Screen capture is a snapshot** — if an action triggers an animation or async
  update, wait briefly before capturing.

## Case Study: Verifying Vim Configuration

### Check settings non-interactively (fast path)
```bash
nix-shell -p vim --run "vim -es -c 'set number?' -c 'set keywordprg?' -c 'q'"
# Output: nonumber\n  keywordprg=man
```

### Full interactive verification via tmux
```bash
# 1. Start vim in tmux
nix-shell -p tmux vim --run "tmux new-session -d -s vimtest -x 80 -y 24 'vim /tmp/test.txt'"

# 2. See the initial screen (tildes = empty file)
nix-shell -p tmux vim --run "tmux capture-pane -t vimtest -p"

# 3. Enter insert mode, type text, return to normal mode
nix-shell -p tmux vim --run "tmux send-keys -t vimtest 'i' 'Hello world' Escape"

# 4. Verify text appeared
nix-shell -p tmux vim --run "tmux capture-pane -t vimtest -p"

# 5. Test a setting — enable line numbers
nix-shell -p tmux vim --run "tmux send-keys -t vimtest ':set number' Enter"
nix-shell -p tmux vim --run "tmux capture-pane -t vimtest -p"
# Should show "  1 Hello world" with number on the left

# 6. Test K keybinding — move cursor to a word and press K
nix-shell -p tmux vim --run "tmux send-keys -t vimtest '0'"  # move to start
nix-shell -p tmux vim --run "tmux send-keys -t vimtest 'K'"  # press K
sleep 2
nix-shell -p tmux vim --run "tmux capture-pane -t vimtest -p"
# Check what K opened (man page? hoogle? error?)

# 7. Clean up
nix-shell -p tmux vim --run "tmux kill-session -t vimtest"
```

## Other TUI Examples

### htop — check if a process is running
```bash
nix-shell -p tmux htop --run "tmux new-session -d -s mon -x 120 -y 30 'htop'"
sleep 1
nix-shell -p tmux htop --run "tmux capture-pane -t mon -p"
nix-shell -p tmux htop --run "tmux kill-session -t mon"
```

### less — verify file content navigation
```bash
nix-shell -p tmux --run "tmux new-session -d -s pager -x 80 -y 24 'less /path/to/file'"
sleep 1
# Page down
nix-shell -p tmux --run "tmux send-keys -t pager Space"
nix-shell -p tmux --run "tmux capture-pane -t pager -p"
# Search for a pattern
nix-shell -p tmux --run "tmux send-keys -t pager '/pattern' Enter"
nix-shell -p tmux --run "tmux capture-pane -t pager -p"
nix-shell -p tmux --run "tmux kill-session -t pager"
```

### General pattern for any TUI
```bash
DEPS="tmux programname"  # nix packages needed
SESSION="mysession"

# Start
nix-shell -p $DEPS --run "tmux new-session -d -s $SESSION -x 80 -y 24 'programname'"
sleep 1

# Interact (repeat as needed)
nix-shell -p $DEPS --run "tmux send-keys -t $SESSION 'keystroke' Enter"
nix-shell -p $DEPS --run "tmux capture-pane -t $SESSION -p"

# Clean up
nix-shell -p $DEPS --run "tmux kill-session -t $SESSION"
```
