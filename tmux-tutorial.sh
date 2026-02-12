#!/usr/bin/env bash
# =============================================================================
# Interactive tmux Tutorial
# Learn tmux by doing -- the script creates real sessions for you to practice in.
#
# Usage:
#   bash tmux-tutorial.sh          # Interactive menu
#   bash tmux-tutorial.sh 4        # Jump to chapter 4
#   bash tmux-tutorial.sh cheat    # Print cheat sheet only
# =============================================================================

set -euo pipefail

# ─── Constants & Colors ──────────────────────────────────────────────────────

readonly VERSION="1.0.1"
readonly REPO_URL="https://github.com/aurelienbaroiller/tmux-tutorial"
readonly TUTORIAL_PREFIX="tut-"
readonly PROGRESS_FILE="$HOME/.tmux-tutorial-progress"
readonly TOTAL_CHAPTERS=8
readonly USER_SHELL="${SHELL:-bash}"
TEMP_FILES=()

# Colors
readonly RESET='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BG_BLUE='\033[44m'
readonly BG_GREEN='\033[42m'
readonly BG_MAGENTA='\033[45m'

# ─── Utility Functions ───────────────────────────────────────────────────────

print_header() {
    local title="$1"
    local width=70
    echo ""
    echo -e "${BG_BLUE}${WHITE}$(printf '═%.0s' $(seq 1 "$width"))${RESET}"
    printf "${BG_BLUE}${WHITE}  %-$((width - 2))s${RESET}\n" "$title"
    echo -e "${BG_BLUE}${WHITE}$(printf '═%.0s' $(seq 1 "$width"))${RESET}"
    echo ""
}

print_subheader() {
    local title="$1"
    echo ""
    echo -e "${CYAN}${BOLD}── $title ──${RESET}"
    echo ""
}

print_info() {
    echo -e "  ${BLUE}ℹ${RESET}  $1"
}

print_key() {
    echo -e "  ${YELLOW}⌨${RESET}  ${BOLD}$1${RESET} — $2"
}

print_action() {
    echo -e "  ${GREEN}▶${RESET}  $1"
}

print_challenge() {
    echo -e ""
    echo -e "  ${BG_MAGENTA}${WHITE} CHALLENGE ${RESET} $1"
}

print_success() {
    echo -e "  ${GREEN}✓${RESET}  $1"
}

print_fail() {
    echo -e "  ${RED}✗${RESET}  $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${RESET}  $1"
}

print_separator() {
    echo -e "${DIM}$(printf '─%.0s' $(seq 1 70))${RESET}"
}

wait_for_enter() {
    local msg="${1:-Press Enter to continue...}"
    echo ""
    echo -ne "  ${DIM}$msg${RESET}"
    read -r
}

check_tmux_installed() {
    if ! command -v tmux &>/dev/null; then
        echo -e "${RED}Error: tmux is not installed.${RESET}"
        echo ""
        echo "Install it with:"
        echo "  macOS:   brew install tmux"
        echo "  Ubuntu:  sudo apt install tmux"
        echo "  Fedora:  sudo dnf install tmux"
        exit 1
    fi
}

check_not_inside_tmux() {
    if [[ -n "${TMUX:-}" ]]; then
        echo -e "${RED}Error: You're running this inside tmux!${RESET}"
        echo ""
        echo "This tutorial creates and attaches to tmux sessions, which gets"
        echo "confusing when nested. Please detach first:"
        echo ""
        echo -e "  ${YELLOW}Press Ctrl+B then d${RESET}  to detach from your current session"
        echo ""
        echo "Then run this script again from a regular terminal."
        exit 1
    fi
}

cleanup_tutorial_sessions() {
    local sessions s
    sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
    while IFS= read -r s; do
        if [[ -n "$s" && "$s" == "${TUTORIAL_PREFIX}"* ]]; then
            tmux kill-session -t "$s" 2>/dev/null || true
        fi
    done <<< "$sessions"

    # Clean up any leftover temp files
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        for tmpfile in "${TEMP_FILES[@]}"; do
            [[ -f "$tmpfile" ]] && rm -f "$tmpfile"
        done
        TEMP_FILES=()
    fi
}

# Write message to a temp file and return a shell command that displays it
# then drops into the user's interactive shell. Use with:
#   tmux new-session -d -s name "$(pane_cmd "line1" "line2" ...)"
#   tmux new-window -t session -n name "$(pane_cmd "line1" ...)"
#   tmux split-window -h -t session "$(pane_cmd "line1" ...)"
pane_cmd() {
    local tmpfile
    tmpfile=$(mktemp /tmp/tut-msg-XXXXXX)
    TEMP_FILES+=("$tmpfile")
    printf '%s\n' "$@" > "$tmpfile"
    echo "cat '${tmpfile}'; rm -f '${tmpfile}'; exec '${USER_SHELL}'"
}

attach_and_wait() {
    local session="$1"
    if ! tmux has-session -t "$session" 2>/dev/null; then
        print_warning "Session '$session' not found. Skipping attach."
        return 1
    fi
    tmux attach-session -t "$session" 2>/dev/null || true
}

verify_session_exists() {
    local session="$1"
    tmux has-session -t "$session" 2>/dev/null
}

verify_session_not_exists() {
    local session="$1"
    ! tmux has-session -t "$session" 2>/dev/null
}

verify_window_count() {
    local session="$1"
    local expected="$2"
    local actual
    actual=$(tmux list-windows -t "$session" 2>/dev/null | wc -l)
    [[ "$actual" -eq "$expected" ]]
}

verify_window_exists() {
    local session="$1"
    local window_name="$2"
    tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -qFx "$window_name"
}

verify_pane_count() {
    local session="$1"
    local expected="$2"
    local actual
    actual=$(tmux list-panes -t "$session" 2>/dev/null | wc -l)
    [[ "$actual" -ge "$expected" ]]
}

save_progress() {
    local chapter="$1"
    echo "$chapter" > "$PROGRESS_FILE"
}

load_progress() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        local progress
        progress=$(cat "$PROGRESS_FILE")
        if [[ "$progress" =~ ^[0-9]+$ ]] && (( progress >= 0 && progress <= TOTAL_CHAPTERS )); then
            echo "$progress"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

print_cheatsheet() {
    print_header "tmux Cheat Sheet"

    echo -e "${BOLD}  PREFIX KEY: Ctrl+B  (press Ctrl+B first, then the command key)${RESET}"
    echo ""

    echo -e "  ${CYAN}${BOLD}Sessions${RESET}"
    echo -e "  ────────────────────────────────────────────────────"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B d" "Detach from session"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B s" "List/switch sessions"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B \$" "Rename current session"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B (" "Previous session"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B )" "Next session"
    echo ""

    echo -e "  ${CYAN}${BOLD}Windows${RESET}"
    echo -e "  ────────────────────────────────────────────────────"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B c" "Create new window"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B n" "Next window"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B p" "Previous window"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B 0-9" "Switch to window N"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B w" "List all windows"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B ," "Rename current window"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B &" "Close current window"
    echo ""

    echo -e "  ${CYAN}${BOLD}Panes${RESET}"
    echo -e "  ────────────────────────────────────────────────────"
    printf "  ${YELLOW}%-18s${RESET} %s\n" 'Ctrl+B %' "Split vertically (left/right)"
    printf "  ${YELLOW}%-18s${RESET} %s\n" 'Ctrl+B "' "Split horizontally (top/bottom)"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B arrow" "Navigate between panes"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B o" "Cycle to next pane"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B q" "Show pane numbers"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B z" "Zoom/unzoom pane"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B x" "Close current pane"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B Ctrl+arrow" "Resize pane"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B Space" "Cycle layouts"
    echo ""

    echo -e "  ${CYAN}${BOLD}Copy Mode${RESET}"
    echo -e "  ────────────────────────────────────────────────────"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B [" "Enter copy mode (scroll)"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "q" "Exit copy mode"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "/" "Search forward"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "?" "Search backward"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Space" "Start selection"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Enter" "Copy selection"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B ]" "Paste"
    echo ""

    echo -e "  ${CYAN}${BOLD}Command Mode${RESET}"
    echo -e "  ────────────────────────────────────────────────────"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B :" "Open command prompt"
    printf "  ${YELLOW}%-18s${RESET} %s\n" "Ctrl+B ?" "List all keybindings"
    echo ""

    echo -e "  ${CYAN}${BOLD}CLI Commands${RESET}"
    echo -e "  ────────────────────────────────────────────────────"
    printf "  ${YELLOW}%-28s${RESET} %s\n" "tmux new -s name" "New named session"
    printf "  ${YELLOW}%-28s${RESET} %s\n" "tmux attach -t name" "Attach to session"
    printf "  ${YELLOW}%-28s${RESET} %s\n" "tmux ls" "List sessions"
    printf "  ${YELLOW}%-28s${RESET} %s\n" "tmux kill-session -t name" "Kill a session"
    printf "  ${YELLOW}%-28s${RESET} %s\n" "tmux kill-server" "Kill all sessions"
    echo ""
}

# ─── Chapter Functions ───────────────────────────────────────────────────────

chapter_1() {
    print_header "Chapter 1: What is tmux?"

    print_info "tmux is a ${BOLD}terminal multiplexer${RESET}. It lets you:"
    echo ""
    echo -e "    1. Run multiple terminal sessions inside one terminal"
    echo -e "    2. Detach from sessions and reattach later"
    echo -e "    3. Keep processes running after you disconnect"
    echo ""
    print_info "tmux uses a ${BOLD}client-server model${RESET}:"
    echo -e "    • The ${CYAN}server${RESET} runs in the background, managing all sessions"
    echo -e "    • The ${CYAN}client${RESET} is your terminal window that connects to a session"
    echo -e "    • When you detach, the server keeps running -- your work persists!"
    echo ""

    print_separator
    print_subheader "Let's Try It"

    print_action "Creating a tmux session called '${TUTORIAL_PREFIX}basics'..."
    cleanup_tutorial_sessions
    tmux new-session -d -s "${TUTORIAL_PREFIX}basics" \
        "$(pane_cmd \
            "" \
            "  Welcome to your first tmux session!" \
            "" \
            "  This session will persist even after you detach." \
            "" \
            "  Try typing some commands, then detach with: Ctrl+B d" \
            "")"

    echo ""
    print_info "You're about to be dropped into a real tmux session."
    print_info "Type some commands, look around, then:"
    echo ""
    print_key "Ctrl+B d" "Detach from the session (press Ctrl+B, release, then d)"
    echo ""
    wait_for_enter "Press Enter to attach to the session... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}basics"

    echo ""
    print_success "You detached! You're back in the tutorial script."
    echo ""

    print_subheader "The Session is Still Alive"
    print_info "Even though you left, the session is still running:"
    echo ""
    echo -e "  ${DIM}\$ tmux list-sessions${RESET}"
    if tmux list-sessions 2>/dev/null | grep -q .; then
        tmux list-sessions 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${RESET}"
        done
    else
        echo -e "  ${DIM}(no sessions)${RESET}"
    fi
    echo ""

    print_info "Now let's kill it to see the difference:"
    tmux kill-session -t "${TUTORIAL_PREFIX}basics" 2>/dev/null || true
    echo -e "  ${DIM}\$ tmux kill-session -t ${TUTORIAL_PREFIX}basics${RESET}"
    echo ""

    if verify_session_not_exists "${TUTORIAL_PREFIX}basics"; then
        print_success "Session killed. It's gone now."
    fi
    echo ""
    print_info "Key takeaway: sessions persist when you ${BOLD}detach${RESET}, but die when you ${BOLD}kill${RESET} them."
    echo ""

    print_separator
    echo -e "  ${BOLD}Keys learned this chapter:${RESET}"
    print_key "Ctrl+B d" "Detach from current session"
    echo ""

    save_progress 1
    wait_for_enter
}

chapter_2() {
    print_header "Chapter 2: Session Management"

    print_info "You can run multiple named sessions simultaneously."
    print_info "This is great for organizing different projects or contexts."
    echo ""

    print_action "Creating 3 sessions: project-a, project-b, project-c..."
    cleanup_tutorial_sessions

    for name in project-a project-b project-c; do
        tmux new-session -d -s "${TUTORIAL_PREFIX}${name}" \
            "$(pane_cmd \
                "" \
                "  === Session: ${name} ===" \
                "" \
                "  Try switching between the 3 sessions:" \
                "    Ctrl+B s    List sessions (arrows to navigate, Enter to select)" \
                "    Ctrl+B )    Next session" \
                "    Ctrl+B (    Previous session" \
                "" \
                "  When done exploring: Ctrl+B d  to detach" \
                "")"
    done

    echo ""
    print_info "Three sessions are now running. Inside tmux you can:"
    echo ""
    print_key "Ctrl+B s" "Show session list (navigate with arrows, Enter to select)"
    print_key "Ctrl+B (" "Switch to previous session"
    print_key "Ctrl+B )" "Switch to next session"
    echo ""

    print_challenge "Switch between all 3 sessions using Ctrl+B s or Ctrl+B (/)"
    echo ""
    print_info "When done exploring, detach with Ctrl+B d."
    echo ""
    wait_for_enter "Press Enter to attach to project-a... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}project-a"

    echo ""
    print_success "Back in the tutorial!"
    echo ""

    print_separator
    print_subheader "Challenge: Rename a Session"

    print_info "Let's test session renaming."
    print_action "Creating session '${TUTORIAL_PREFIX}rename-me'..."
    tmux new-session -d -s "${TUTORIAL_PREFIX}rename-me" \
        "$(pane_cmd \
            "" \
            "  CHALLENGE: Rename this session" \
            "" \
            "  Steps:" \
            "    1. Press Ctrl+B \$" \
            "    2. Clear the current name, type: ${TUTORIAL_PREFIX}my-project" \
            "    3. Press Enter" \
            "    4. Ctrl+B d  to detach and check your answer" \
            "")"

    echo ""
    print_key "Ctrl+B \$" "Rename current session"
    echo ""
    print_challenge "Rename the session from '${TUTORIAL_PREFIX}rename-me' to '${TUTORIAL_PREFIX}my-project'"
    print_info "(Type '${TUTORIAL_PREFIX}my-project' when prompted for the new name)"
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}rename-me" || attach_and_wait "${TUTORIAL_PREFIX}my-project" || true

    echo ""
    if verify_session_exists "${TUTORIAL_PREFIX}my-project"; then
        print_success "Session renamed to '${TUTORIAL_PREFIX}my-project' -- well done!"
    else
        print_fail "Session wasn't renamed to '${TUTORIAL_PREFIX}my-project'."
        print_info "That's OK! The command is: Ctrl+B \$ then type the new name."
        print_info "You can practice this anytime."
    fi
    echo ""

    cleanup_tutorial_sessions

    print_separator
    echo -e "  ${BOLD}Keys learned this chapter:${RESET}"
    print_key "Ctrl+B s" "List/switch sessions"
    print_key "Ctrl+B \$" "Rename current session"
    print_key "Ctrl+B (" "Previous session"
    print_key "Ctrl+B )" "Next session"
    echo ""

    save_progress 2
    wait_for_enter
}

chapter_3() {
    local passed=0

    print_header "Chapter 3: Windows (Like Browser Tabs)"

    print_info "Inside a session, you can have multiple ${BOLD}windows${RESET}."
    print_info "Think of them like browser tabs -- each is a full terminal."
    echo ""
    print_info "The status bar at the bottom shows your windows."
    echo ""

    _window_nav_msg() {
        pane_cmd \
            "" \
            "  === $1 ===" \
            "" \
            "  Navigate between the 3 windows:" \
            "    Ctrl+B n/p  Switch windows" \
            "    Ctrl+B 0-2  Jump to window by number" \
            "    Ctrl+B w    Window list (interactive)" \
            "    Ctrl+B d    Detach" \
            "" \
            "  Look at the status bar at the bottom -- it shows all windows." \
            ""
    }

    print_action "Creating a session with 3 named windows..."
    cleanup_tutorial_sessions

    tmux new-session -d -s "${TUTORIAL_PREFIX}windows" -n "editor" \
        "$(_window_nav_msg "EDITOR WINDOW (0)")"

    tmux new-window -t "${TUTORIAL_PREFIX}windows" -n "server" \
        "$(_window_nav_msg "SERVER WINDOW (1)")"

    tmux new-window -t "${TUTORIAL_PREFIX}windows" -n "logs" \
        "$(_window_nav_msg "LOGS WINDOW (2)")"

    tmux select-window -t "${TUTORIAL_PREFIX}windows:editor"

    echo ""
    print_info "Navigate between windows with:"
    echo ""
    print_key "Ctrl+B n" "Next window"
    print_key "Ctrl+B p" "Previous window"
    print_key "Ctrl+B 0" "Go to window 0 (editor)"
    print_key "Ctrl+B 1" "Go to window 1 (server)"
    print_key "Ctrl+B 2" "Go to window 2 (logs)"
    print_key "Ctrl+B w" "List all windows (interactive picker)"
    echo ""
    print_info "Look at the ${BOLD}status bar at the bottom${RESET} -- it shows all windows."
    echo ""
    wait_for_enter "Press Enter to attach (start in 'editor' window)... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}windows"

    echo ""
    print_success "Good! Now let's try creating and managing windows."
    echo ""

    print_separator
    print_subheader "Challenge: Create, Rename, and Close Windows"

    print_action "Re-creating the session for the challenge..."
    cleanup_tutorial_sessions

    tmux new-session -d -s "${TUTORIAL_PREFIX}windows" -n "keep-me" \
        "$(pane_cmd \
            "" \
            "  CHALLENGE: Create, Rename, and Close Windows" \
            "" \
            "    1. Ctrl+B c    Create a new window" \
            "    2. Ctrl+B ,    Rename it to: new-window" \
            "    3. Ctrl+B n/p  Navigate to the 'delete-me' window" \
            "    4. Ctrl+B &    Close it (confirm with y)" \
            "    5. Ctrl+B d    Detach to check your answers" \
            "")"

    tmux new-window -t "${TUTORIAL_PREFIX}windows" -n "delete-me" \
        "$(pane_cmd \
            "" \
            "  Close this window with: Ctrl+B &  (then confirm with y)" \
            "  Then: Ctrl+B d  to detach" \
            "")"

    tmux select-window -t "${TUTORIAL_PREFIX}windows:keep-me"

    echo ""
    print_key "Ctrl+B c" "Create a new window"
    print_key "Ctrl+B ," "Rename current window"
    print_key "Ctrl+B &" "Close current window (confirm with y)"
    echo ""
    print_challenge "Do all three:"
    print_key "Ctrl+B c" "Create a new window"
    print_key "Ctrl+B ," "Rename it to 'new-window'"
    print_key "Ctrl+B n/p then Ctrl+B &" "Switch to 'delete-me' and close it (confirm with y)"
    print_key "Ctrl+B d" "Detach to check your answers"
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}windows"

    echo ""
    # Verify
    if verify_window_exists "${TUTORIAL_PREFIX}windows" "new-window"; then
        print_success "Window 'new-window' exists -- great job creating and renaming!"
        passed=$((passed + 1))
    else
        print_fail "Didn't find a window named 'new-window'."
        print_info "Remember: Ctrl+B c creates, Ctrl+B , renames."
    fi

    if ! verify_window_exists "${TUTORIAL_PREFIX}windows" "delete-me"; then
        print_success "Window 'delete-me' was closed -- nice!"
        passed=$((passed + 1))
    else
        print_fail "Window 'delete-me' still exists."
        print_info "Remember: Ctrl+B & closes a window (confirm with y)."
    fi

    if [[ $passed -eq 2 ]]; then
        echo ""
        print_success "${BOLD}Perfect! All challenges completed!${RESET}"
    fi
    echo ""

    cleanup_tutorial_sessions

    print_separator
    echo -e "  ${BOLD}Keys learned this chapter:${RESET}"
    print_key "Ctrl+B c" "Create new window"
    print_key "Ctrl+B n / p" "Next / previous window"
    print_key "Ctrl+B 0-9" "Switch to window by number"
    print_key "Ctrl+B w" "List all windows"
    print_key "Ctrl+B ," "Rename current window"
    print_key "Ctrl+B &" "Close current window"
    echo ""

    save_progress 3
    wait_for_enter
}

chapter_4() {
    local pane_count

    print_header "Chapter 4: Panes (Split Screen)"

    print_info "Panes let you split a single window into multiple terminals."
    print_info "This is one of tmux's most powerful features."
    echo ""

    _pane_info_msg() {
        pane_cmd \
            "" \
            "  === $1 ===" \
            "" \
            "  Navigate between the 3 panes:" \
            "    Ctrl+B arrow    Move to adjacent pane" \
            "    Ctrl+B o        Cycle to next pane" \
            "    Ctrl+B q        Show pane numbers" \
            "" \
            "  Try also:" \
            "    Ctrl+B z          Zoom/unzoom current pane" \
            "    Ctrl+B Ctrl+arrow Resize pane" \
            "    Ctrl+B Space      Cycle layouts" \
            "" \
            "  When done: Ctrl+B d  to detach" \
            ""
    }

    print_action "Creating a session with pre-split panes..."
    cleanup_tutorial_sessions

    tmux new-session -d -s "${TUTORIAL_PREFIX}panes" -x 120 -y 40 \
        "$(_pane_info_msg "PANE 0 (top-left)")"

    tmux split-window -h -t "${TUTORIAL_PREFIX}panes" \
        "$(_pane_info_msg "PANE 1 (top-right)")"

    tmux split-window -v -t "${TUTORIAL_PREFIX}panes" \
        "$(_pane_info_msg "PANE 2 (bottom-right)")"

    tmux select-pane -t "${TUTORIAL_PREFIX}panes.0"

    echo ""
    print_info "Navigation:"
    print_key "Ctrl+B arrow" "Move to adjacent pane"
    print_key "Ctrl+B o" "Cycle to next pane"
    print_key "Ctrl+B q" "Flash pane numbers (press number to jump)"
    echo ""
    print_info "Resizing:"
    print_key "Ctrl+B Ctrl+arrow" "Resize pane in that direction"
    echo ""
    print_info "Zoom:"
    print_key "Ctrl+B z" "Zoom pane to full window (toggle)"
    echo ""
    print_info "Layouts:"
    print_key "Ctrl+B Space" "Cycle through preset layouts"
    echo ""
    print_info "Try navigating between the 3 panes and experimenting with zoom."
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}panes"

    echo ""
    print_success "Great! Now let's learn to create panes."
    echo ""

    print_separator
    print_subheader "Creating Panes"

    print_action "Creating a fresh session for splitting practice..."
    cleanup_tutorial_sessions

    tmux new-session -d -s "${TUTORIAL_PREFIX}panes" -x 120 -y 40 \
        "$(pane_cmd \
            "" \
            "  CHALLENGE: Create 4+ panes" \
            "" \
            "    Ctrl+B %    Split left/right" \
            "    Ctrl+B \"    Split top/bottom" \
            "" \
            "  Goal: split until you have at least 4 panes total." \
            "  Then: Ctrl+B d  to detach and check your count" \
            "")"

    echo ""
    print_key 'Ctrl+B %' "Split vertically (left/right)"
    print_key 'Ctrl+B "' "Split horizontally (top/bottom)"
    print_key "Ctrl+B x" "Close current pane"
    echo ""

    print_challenge "Create at least 4 panes total using splits, then detach."
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}panes"

    echo ""
    pane_count=$(tmux list-panes -t "${TUTORIAL_PREFIX}panes" 2>/dev/null | wc -l)
    if [[ "$pane_count" -ge 4 ]]; then
        print_success "You created $pane_count panes -- excellent!"
    elif [[ "$pane_count" -gt 1 ]]; then
        print_info "You have $pane_count panes. Try creating more next time (need 4+)."
    else
        print_info "Only 1 pane detected. Remember: Ctrl+B % and Ctrl+B \" create splits."
    fi
    echo ""

    cleanup_tutorial_sessions

    print_separator
    echo -e "  ${BOLD}Keys learned this chapter:${RESET}"
    print_key 'Ctrl+B %' "Split left/right"
    print_key 'Ctrl+B "' "Split top/bottom"
    print_key "Ctrl+B arrow" "Navigate panes"
    print_key "Ctrl+B o" "Cycle panes"
    print_key "Ctrl+B q" "Show pane numbers"
    print_key "Ctrl+B z" "Zoom/unzoom"
    print_key "Ctrl+B x" "Close pane"
    print_key "Ctrl+B Ctrl+arrow" "Resize pane"
    print_key "Ctrl+B Space" "Cycle layouts"
    echo ""

    save_progress 4
    wait_for_enter
}

chapter_5() {
    local content_file i

    print_header "Chapter 5: Copy Mode & Scrollback"

    print_info "By default, you can't scroll in tmux with your mouse or trackpad."
    print_info "Instead, you use ${BOLD}copy mode${RESET} to scroll, search, and copy text."
    echo ""

    print_action "Creating a session with 100 lines of output..."
    cleanup_tutorial_sessions

    # Generate 100 lines into a temp file, then display them cleanly
    content_file=$(mktemp /tmp/tut-msg-XXXXXX)
    for i in $(seq 1 100); do
        echo "Line $i: The quick brown fox jumps over the lazy dog" >> "$content_file"
    done
    echo "" >> "$content_file"
    echo ">>> CHALLENGE: Find \"Line 50\" <<<" >> "$content_file"
    echo "" >> "$content_file"
    echo "  1. Ctrl+B [    Enter copy mode" >> "$content_file"
    echo "  2. /Line 50    Search forward (then Enter)" >> "$content_file"
    echo "  3. q           Exit copy mode" >> "$content_file"
    echo "  4. Ctrl+B d    Detach when done" >> "$content_file"

    tmux new-session -d -s "${TUTORIAL_PREFIX}copymode" -x 120 -y 40 \
        "cat '${content_file}'; rm -f '${content_file}'; exec ${USER_SHELL}"

    echo ""
    print_info "There are 100 lines of output in this session."
    echo ""
    print_subheader "Copy Mode Controls"
    print_key "Ctrl+B [" "Enter copy mode"
    print_key "q" "Exit copy mode"
    print_key "Up/Down/PgUp/PgDn" "Scroll in copy mode"
    print_key "/" "Search forward"
    print_key "?" "Search backward"
    print_key "n" "Next search match"
    print_key "N" "Previous search match"
    echo ""
    print_subheader "Selecting & Copying"
    print_key "Space" "Start selection (in copy mode)"
    print_key "Enter" "Copy selection and exit copy mode"
    print_key "Ctrl+B ]" "Paste copied text"
    echo ""

    print_challenge "Enter copy mode and search for 'Line 50' using /"
    echo ""
    print_info "Steps: Ctrl+B [  then type  /Line 50  then Enter"
    print_info "Press q to exit copy mode, then Ctrl+B d to detach."
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}copymode"

    echo ""
    print_success "Copy mode is essential for working with long output."
    print_info "Tip: You can enable mouse scrolling in copy mode with:"
    echo -e "  ${DIM}set -g mouse on${RESET}  (in .tmux.conf or via Ctrl+B :)"
    echo ""

    cleanup_tutorial_sessions

    print_separator
    echo -e "  ${BOLD}Keys learned this chapter:${RESET}"
    print_key "Ctrl+B [" "Enter copy mode"
    print_key "q" "Exit copy mode"
    print_key "/" "Search forward"
    print_key "?" "Search backward"
    print_key "Space" "Start selection"
    print_key "Enter" "Copy selection"
    print_key "Ctrl+B ]" "Paste"
    echo ""

    save_progress 5
    wait_for_enter
}

chapter_6() {
    print_header "Chapter 6: Command Mode"

    print_info "tmux has a built-in command prompt, like vim's ':' mode."
    print_info "You can run any tmux command interactively."
    echo ""

    print_key "Ctrl+B :" "Open tmux command prompt"
    print_key "Ctrl+B ?" "List ALL keybindings"
    echo ""

    print_action "Creating session for command mode practice..."
    cleanup_tutorial_sessions

    tmux new-session -d -s "${TUTORIAL_PREFIX}commands" -x 120 -y 40 \
        "$(pane_cmd \
            "" \
            "  Welcome to Command Mode practice!" \
            "" \
            "  Press Ctrl+B : to open the command prompt." \
            "  Try these commands:" \
            "" \
            "    display-panes       -- flash pane numbers" \
            "    clock-mode          -- show a clock (q to exit)" \
            "    new-window -n test  -- create window named test" \
            "    split-window -h     -- split horizontally" \
            "    list-keys           -- show all key bindings" \
            "" \
            "  Press q to exit clock mode / list-keys viewer" \
            "" \
            "  CHALLENGE: Change the status bar color" \
            "    Ctrl+B :  then type:  set status-style bg=red" \
            "" \
            "  When done experimenting: Ctrl+B d  to detach" \
            "")"

    echo ""
    print_subheader "Useful Commands to Try"
    echo ""
    echo -e "  ${CYAN}display-panes${RESET}       Flash pane numbers on screen"
    echo -e "  ${CYAN}clock-mode${RESET}          Show a big clock (press q to exit)"
    echo -e "  ${CYAN}new-window -n test${RESET}  Create a new window named 'test'"
    echo -e "  ${CYAN}split-window -h${RESET}     Split pane left/right"
    echo -e "  ${CYAN}list-keys${RESET}           Show all keybindings"
    echo -e "  ${CYAN}list-commands${RESET}       Show all available commands"
    echo ""

    print_challenge "Use Ctrl+B : then type:  set status-style bg=red"
    print_info "This changes your status bar color live! (Resets when session ends)"
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}commands"

    echo ""
    print_success "Command mode is powerful for one-off adjustments and exploration."
    print_info "Tip: Ctrl+B ? shows ALL keybindings -- great for discovering features."
    echo ""

    cleanup_tutorial_sessions

    print_separator
    echo -e "  ${BOLD}Keys learned this chapter:${RESET}"
    print_key "Ctrl+B :" "Open command prompt"
    print_key "Ctrl+B ?" "List all keybindings"
    echo ""

    save_progress 6
    wait_for_enter
}

chapter_7() {
    print_header "Chapter 7: Customization (.tmux.conf)"

    print_info "tmux is configured via ${BOLD}~/.tmux.conf${RESET}."
    print_info "Changes take effect on new sessions or after sourcing the file."
    echo ""
    print_warning "This tutorial will NOT modify your config. We'll just show examples."
    echo ""

    print_separator
    print_subheader "Sample ~/.tmux.conf"
    echo ""

    cat << 'SAMPLE'
    # ─── General ─────────────────────────────────────────────
    set -g default-terminal "screen-256color"  # Better colors
    set -g history-limit 50000                 # Scrollback buffer
    set -g mouse on                            # Enable mouse support
    set -g base-index 1                        # Windows start at 1
    setw -g pane-base-index 1                  # Panes start at 1
    set -g renumber-windows on                 # Renumber on close

    # ─── Intuitive Splits ────────────────────────────────────
    bind | split-window -h -c "#{pane_current_path}"  # | for vertical
    bind - split-window -v -c "#{pane_current_path}"  # - for horizontal

    # ─── Pane Navigation (vim-style) ─────────────────────────
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R

    # ─── Status Bar ──────────────────────────────────────────
    set -g status-position top
    set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
    set -g status-left "#[bold] #S "
    set -g status-right " %H:%M %d-%b "

    # ─── Reload Config ───────────────────────────────────────
    bind r source-file ~/.tmux.conf \; display "Config reloaded!"
SAMPLE

    echo ""
    print_info "Key customizations explained:"
    echo ""
    echo -e "  ${CYAN}set -g mouse on${RESET}"
    echo -e "  Enables mouse click to select panes, scroll, resize."
    echo ""
    echo -e "  ${CYAN}bind | split-window -h -c \"#{pane_current_path}\"${RESET}"
    echo -e "  Maps Ctrl+B | to split (more intuitive than Ctrl+B %)."
    echo -e "  The -c flag keeps the same working directory."
    echo ""
    echo -e "  ${CYAN}bind r source-file ~/.tmux.conf${RESET}"
    echo -e "  Maps Ctrl+B r to reload your config without restarting."
    echo ""

    print_separator
    print_subheader "Popular Plugins"
    echo ""
    echo -e "  ${CYAN}tmux-resurrect${RESET}     Save/restore sessions across reboots"
    echo -e "  ${CYAN}tmux-continuum${RESET}      Automatic saving of sessions"
    echo -e "  ${CYAN}tmux-sensible${RESET}       Sensible defaults everyone agrees on"
    echo -e "  ${CYAN}tmux-yank${RESET}           System clipboard integration"
    echo -e "  ${CYAN}tpm${RESET}                 Tmux Plugin Manager"
    echo ""
    print_info "Install tpm: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
    echo ""

    print_separator
    print_subheader "Try Live Customization"

    print_action "Creating a session to experiment with live settings..."
    cleanup_tutorial_sessions

    tmux new-session -d -s "${TUTORIAL_PREFIX}config" -x 120 -y 40 \
        "$(pane_cmd \
            "" \
            "  Experiment with live settings via Ctrl+B :" \
            "" \
            "  Try these (via Ctrl+B :):" \
            "    set -g mouse on" \
            "    set -g status-position top" \
            "    set -g status-style bg=blue" \
            "" \
            "  These are temporary -- they reset when the session ends." \
            "" \
            "  When done: Ctrl+B d  to detach" \
            "")"

    echo ""
    print_info "Try some live settings via Ctrl+B : and detach when done."
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}config"

    echo ""
    print_success "Remember: put your permanent settings in ~/.tmux.conf"
    echo ""

    cleanup_tutorial_sessions

    save_progress 7
    wait_for_enter
}

chapter_8() {
    local win_count pane_count
    local passed=0

    print_header "Chapter 8: Putting It All Together"

    print_info "Let's build a complete dev workspace programmatically."
    print_info "This shows you how to script tmux for repeatable setups."
    echo ""

    print_separator
    print_subheader "The Script"
    echo ""
    print_info "Here are the exact commands we'll run:"
    echo ""

    cat << 'SCRIPT'
    # Create session with first window named "editor"
    tmux new-session -d -s workspace -n editor -x 120 -y 40

    # Window 2: Server (2 panes - server + api)
    tmux new-window -t workspace -n server
    tmux split-window -h -t workspace:server

    # Window 3: Monitor (4-pane grid)
    tmux new-window -t workspace -n monitor
    tmux split-window -h -t workspace:monitor
    tmux split-window -v -t workspace:monitor
    tmux select-pane -t workspace:monitor.0
    tmux split-window -v -t workspace:monitor
    tmux select-layout -t workspace:monitor tiled

    # Start in editor window
    tmux select-window -t workspace:editor
SCRIPT

    echo ""
    print_action "Building the workspace now..."
    cleanup_tutorial_sessions

    # Actually build it
    _workspace_pane_msg() {
        pane_cmd \
            "" \
            "  === $1 ===" \
            "" \
            "  Explore this scripted workspace:" \
            "    3 windows: editor, server (2 panes), monitor (4 panes)" \
            "    Ctrl+B n/p    Switch windows" \
            "    Ctrl+B arrow  Switch panes (in server/monitor)" \
            "    Ctrl+B Space  Cycle layouts (try on monitor window)" \
            "" \
            "  When done: Ctrl+B d  to detach" \
            ""
    }

    tmux new-session -d -s "${TUTORIAL_PREFIX}workspace" -n editor -x 120 -y 40 \
        "$(_workspace_pane_msg "EDITOR")"

    tmux new-window -t "${TUTORIAL_PREFIX}workspace" -n server \
        "$(_workspace_pane_msg "MAIN SERVER")"
    tmux split-window -h -t "${TUTORIAL_PREFIX}workspace:server" \
        "$(_workspace_pane_msg "API SERVER")"

    tmux new-window -t "${TUTORIAL_PREFIX}workspace" -n monitor \
        "$(_workspace_pane_msg "CPU MONITOR")"
    tmux split-window -h -t "${TUTORIAL_PREFIX}workspace:monitor" \
        "$(_workspace_pane_msg "MEMORY MONITOR")"
    tmux split-window -v -t "${TUTORIAL_PREFIX}workspace:monitor" \
        "$(_workspace_pane_msg "NETWORK MONITOR")"
    tmux select-pane -t "${TUTORIAL_PREFIX}workspace:monitor.0"
    tmux split-window -v -t "${TUTORIAL_PREFIX}workspace:monitor" \
        "$(_workspace_pane_msg "DISK MONITOR")"
    tmux select-layout -t "${TUTORIAL_PREFIX}workspace:monitor" tiled

    tmux select-window -t "${TUTORIAL_PREFIX}workspace:editor"

    echo ""
    print_success "Workspace built! 3 windows: editor, server (2 panes), monitor (4 panes)"
    echo ""
    print_info "Explore all windows and panes. Use what you've learned!"
    print_info "Cycle layouts on the monitor window with Ctrl+B Space."
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}workspace"

    echo ""
    print_success "You've explored a scripted workspace!"
    echo ""

    print_separator
    print_subheader "Final Challenge: Build Your Own"

    cleanup_tutorial_sessions
    tmux new-session -d -s "${TUTORIAL_PREFIX}final" -x 120 -y 40 \
        "$(pane_cmd \
            "" \
            "  Build your own workspace!" \
            "" \
            "  Create at least:" \
            "    - 2 windows  (Ctrl+B c)" \
            "    - 3 panes total  (Ctrl+B % and Ctrl+B \")" \
            "" \
            "  Then detach with Ctrl+B d" \
            "")"

    echo ""
    print_challenge "Build a workspace with at least 2 windows and 3 total panes."
    echo ""
    wait_for_enter "Press Enter to attach... (instructions will be shown inside)"

    attach_and_wait "${TUTORIAL_PREFIX}final"

    echo ""
    # Check results
    if verify_session_exists "${TUTORIAL_PREFIX}final"; then
        win_count=$(tmux list-windows -t "${TUTORIAL_PREFIX}final" 2>/dev/null | wc -l)
        pane_count=$(tmux list-panes -a -t "${TUTORIAL_PREFIX}final" 2>/dev/null | wc -l)

        passed=0
        if [[ "$win_count" -ge 2 ]]; then
            print_success "Windows: $win_count (needed 2+) -- great!"
            passed=$((passed + 1))
        else
            print_fail "Windows: $win_count (needed 2+)"
        fi

        if [[ "$pane_count" -ge 3 ]]; then
            print_success "Panes: $pane_count total (needed 3+) -- great!"
            passed=$((passed + 1))
        else
            print_fail "Panes: $pane_count total (needed 3+)"
        fi

        if [[ $passed -eq 2 ]]; then
            echo ""
            echo -e "  ${BG_GREEN}${WHITE} CONGRATULATIONS! ${RESET} You've completed the tmux tutorial!"
        fi
    else
        print_info "Session not found -- that's OK if you killed it."
    fi
    echo ""

    cleanup_tutorial_sessions

    save_progress 8
}

# ─── Main ────────────────────────────────────────────────────────────────────

show_welcome() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}"
    cat << 'BANNER'
    ████████╗███╗   ███╗██╗   ██╗██╗  ██╗
    ╚══██╔══╝████╗ ████║██║   ██║╚██╗██╔╝
       ██║   ██╔████╔██║██║   ██║ ╚███╔╝
       ██║   ██║╚██╔╝██║██║   ██║ ██╔██╗
       ██║   ██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗
       ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝
BANNER
    echo -e "${RESET}"
    echo -e "  ${BOLD}Interactive tmux Tutorial${RESET}"
    echo -e "  ${DIM}Learn by doing -- real sessions, real practice${RESET}"
    echo -e "  ${DIM}v${VERSION} · ${REPO_URL}${RESET}"
    echo ""
    echo -e "  tmux version: $(tmux -V 2>/dev/null || echo 'unknown')"
    echo ""
}

show_menu() {
    local saved_progress i
    saved_progress=$(load_progress)

    print_separator
    echo ""
    echo -e "  ${BOLD}Chapters:${RESET}"
    echo ""

    local chapters=(
        "What is tmux?"
        "Session Management"
        "Windows (Like Browser Tabs)"
        "Panes (Split Screen)"
        "Copy Mode & Scrollback"
        "Command Mode"
        "Customization (.tmux.conf)"
        "Putting It All Together"
    )

    for i in "${!chapters[@]}"; do
        local num=$((i + 1))
        local marker="  "
        if [[ $num -le $saved_progress ]]; then
            marker="${GREEN}✓${RESET} "
        fi
        printf "  %b ${BOLD}%d.${RESET} %s\n" "$marker" "$num" "${chapters[$i]}"
    done

    echo ""
    print_separator
    echo ""
    echo -e "  ${BOLD}Options:${RESET}"
    echo ""
    echo -e "  ${CYAN}a${RESET}  Start from the beginning"
    if [[ $saved_progress -gt 0 && $saved_progress -lt $TOTAL_CHAPTERS ]]; then
        echo -e "  ${CYAN}r${RESET}  Resume from Chapter $((saved_progress + 1))"
    fi
    echo -e "  ${CYAN}1-8${RESET}  Jump to a specific chapter"
    echo -e "  ${CYAN}c${RESET}  Print cheat sheet only"
    echo -e "  ${CYAN}q${RESET}  Quit"
    echo ""
    echo -ne "  ${BOLD}Choose: ${RESET}"
}

run_chapter() {
    local num="$1"
    clear
    case "$num" in
        1) chapter_1 ;;
        2) chapter_2 ;;
        3) chapter_3 ;;
        4) chapter_4 ;;
        5) chapter_5 ;;
        6) chapter_6 ;;
        7) chapter_7 ;;
        8) chapter_8 ;;
        *) print_fail "Invalid chapter: $num" ; return 1 ;;
    esac
}

run_all_from() {
    local start="${1:-1}"
    for ((i = start; i <= TOTAL_CHAPTERS; i++)); do
        run_chapter "$i"
    done
    # Final summary
    echo ""
    print_header "Tutorial Complete!"
    print_cheatsheet
    print_info "Your progress is saved. Run this script anytime to review."
    print_info "Happy tmuxing!"
    echo ""
}

main() {
    check_tmux_installed
    check_not_inside_tmux

    # Cleanup on exit
    trap cleanup_tutorial_sessions EXIT
    trap 'cleanup_tutorial_sessions; exit 130' INT TERM

    # CLI argument: jump to chapter or cheat sheet
    if [[ $# -gt 0 ]]; then
        case "$1" in
            cheat|cheatsheet|c)
                print_cheatsheet
                exit 0
                ;;
            [1-8])
                show_welcome
                run_all_from "$1"
                exit 0
                ;;
            *)
                echo "Usage: bash tmux-tutorial.sh [1-8|cheat]"
                exit 1
                ;;
        esac
    fi

    # Interactive menu
    show_welcome
    show_menu

    local choice
    read -r choice

    case "$choice" in
        a|A)
            run_all_from 1
            ;;
        r|R)
            local saved
            saved=$(load_progress)
            if [[ $saved -gt 0 && $saved -lt $TOTAL_CHAPTERS ]]; then
                run_all_from $((saved + 1))
            else
                run_all_from 1
            fi
            ;;
        [1-8])
            run_all_from "$choice"
            ;;
        c|C)
            print_cheatsheet
            ;;
        q|Q)
            echo ""
            print_info "Bye! Run this script anytime to practice."
            echo ""
            ;;
        *)
            print_fail "Invalid choice."
            ;;
    esac
}

main "$@"
