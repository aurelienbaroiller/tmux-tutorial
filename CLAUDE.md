# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Single-file interactive tmux tutorial (`tmux-tutorial.sh`) — a Bash script that teaches tmux by creating real tmux sessions for the user to practice in. It has 8 chapters covering sessions, windows, panes, copy mode, command mode, customization, and a capstone exercise.

## Running

```bash
bash tmux-tutorial.sh          # Interactive menu
bash tmux-tutorial.sh 4        # Jump to chapter 4
bash tmux-tutorial.sh cheat    # Print cheat sheet only
```

Must be run **outside** of tmux (the script checks for `$TMUX` and exits if nested). Requires tmux to be installed.

## Architecture

The script follows a linear structure:

- **Constants & colors** (lines 14–34): `TUTORIAL_PREFIX="tut-"` is used to namespace all tutorial sessions so they can be cleaned up without affecting user sessions.
- **Utility functions** (lines 36–261): Printing helpers (`print_header`, `print_key`, `print_challenge`, etc.), tmux verification functions (`verify_session_exists`, `verify_window_count`, `verify_pane_count`), progress persistence (`save_progress`/`load_progress` writing to `~/.tmux-tutorial-progress`).
- **`pane_cmd()`** (line 136): Key helper — writes messages to a temp file and returns a shell command string that displays them then drops into the user's shell. Used with `tmux new-session -d -s name "$(pane_cmd ...)"`.
- **Chapter functions** (lines 265–1207): `chapter_1()` through `chapter_8()`, each self-contained. Pattern: explain → create tmux session(s) → attach user → verify results after detach → cleanup.
- **Main/menu** (lines 1209–1370): CLI arg parsing, interactive menu with progress tracking, trap-based cleanup on exit.

## Key Conventions

- All tutorial tmux sessions are prefixed with `tut-` (`TUTORIAL_PREFIX`) and cleaned up via `cleanup_tutorial_sessions()`.
- `set -euo pipefail` is enforced.
- Color output uses ANSI escape codes via `readonly` variables.
- User progress is a single integer (last completed chapter) stored in `~/.tmux-tutorial-progress`.
- Challenges are verified by inspecting tmux state after the user detaches (session names, window names, pane counts).

## Testing Changes

There are no automated tests. To verify changes, run the script and step through the affected chapter(s) manually. After detaching from a tutorial session, the script validates results — check that verification logic still passes.
