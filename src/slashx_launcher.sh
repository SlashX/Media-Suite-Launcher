#!/usr/bin/env bash
# =========================================================
# SLASHX MEDIA SUITE - MASTER LAUNCHER (bash) v4.1.1
# Cross-platform: Termux / Linux / macOS / Windows (Git Bash, MSYS2, Cygwin)
# =========================================================

# ── Bash version guard (sh / dash incompatible) ──────────
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Please run with bash, not sh/dash." >&2
    exit 1
fi

# Recomandam bash 4+ pentru ${var,,} si alte features moderne
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "WARNING: bash $BASH_VERSION detected. Some features need bash 4+." >&2
    case "$(uname -s 2>/dev/null)" in
        Darwin) echo "  macOS: brew install bash" >&2 ;;
    esac
    # nu iesim — doar avertizam
fi

# =========================================================
# CONFIGURATION MAP
# =========================================================
SUITE_VERSION="4.1.1"

AV_ROOT="AV-Encoder-Suite"
PHOTO_ROOT="Photo-Encoder-Suite"

AV_REPO_URL="https://github.com/SlashX/AV-Encoder-Suite.git"
PHOTO_REPO_URL="https://github.com/SlashX/Photo-Encoder-Suite.git"

AV_TOOLS_DIR="$AV_ROOT/tools"
PHOTO_TOOLS_DIR="$PHOTO_ROOT/tools"
AV_TESTS_DIR="$AV_ROOT/tests"
PHOTO_TESTS_DIR="$PHOTO_ROOT/tests"
AV_LAUNCHER="av_launcher.sh"
PHOTO_LAUNCHER="photo_launcher.sh"

DEBUG="${SLASHX_DEBUG:-0}"   # export SLASHX_DEBUG=1 pentru log verbos
# =========================================================

# ── CLI args (--help / --version) ────────────────────────
case "${1:-}" in
    -h|--help|help)
        cat <<EOF
SlashX Media Suite Launcher v$SUITE_VERSION

Usage:
  $(basename "$0") [options]

Options:
  -h, --help       Show this help message
  -v, --version    Show version

Environment:
  SLASHX_DEBUG=1   Enable verbose debug logging

Without arguments, the interactive menu is launched.
EOF
        exit 0 ;;
    -v|--version|version)
        echo "SlashX Media Suite Launcher v$SUITE_VERSION (bash)"
        exit 0 ;;
    "") : ;;  # invocare normala
    *)
        echo "Argument necunoscut: $1" >&2
        echo "Foloseste --help pentru ajutor." >&2
        exit 2 ;;
esac

# ── ANSI Colors (suprimate cand stdout nu e TTY) ─────────
if [ -t 1 ]; then
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE_BG='\033[44;97m'
    MAGENTA_BG='\033[45;97m'
    NC='\033[0m'
else
    CYAN='' GREEN='' YELLOW='' RED='' BLUE_BG='' MAGENTA_BG='' NC=''
fi

# Wrapper pentru `clear` — emite escape codes doar in TTY
clear_screen() {
    if [ -t 1 ]; then
        clear 2>/dev/null || true
    fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Repo-urile AV/Photo se cloneaza un nivel mai sus de src/ (in root-ul Media-Suite-Launcher)
# astfel incat structura finala e:
#   Media-Suite-Launcher/
#   |-- src/slashx_launcher.sh   <- acest script
#   |-- AV-Encoder-Suite/        <- clonat de [5]
#   +-- Photo-Encoder-Suite/     <- clonat de [5]
BASE_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

# ── OS detection (Termux / macOS / Linux / Windows) ──────
detect_os() {
    if [[ "${PREFIX:-}" == *"/com.termux/"* ]] || [ -n "${TERMUX_VERSION:-}" ]; then
        echo "Termux (Android)"; return
    fi
    case "$(uname -s 2>/dev/null)" in
        Darwin)              echo "macOS" ;;
        Linux)               echo "Linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "Windows (Git Bash/MSYS)" ;;
        *)                   echo "Unknown OS" ;;
    esac
}
CURRENT_OS=$(detect_os)

dbg() { [ "$DEBUG" = "1" ] && echo "[DEBUG] $*" >&2; }

# ── SIGINT/SIGTERM trap (Ctrl+C curat) ───────────────────
_on_interrupt() {
    echo ""
    echo -e "${YELLOW}[!] Iesire pe Ctrl+C — la revedere.${NC}"
    exit 130
}
trap _on_interrupt INT TERM

# ── Pause portabil ───────────────────────────────────────
pause_enter() {
    local msg="${1:-Press Enter to continue...}"
    read -r -p "$msg" _ </dev/tty 2>/dev/null || read -r -p "$msg" _
}

# ── Helper: process unul singur repo (la nivel global, nu nested) ─
_slashx_process_repo() {
    local name="$1" url="$2" path="$BASE_DIR/$1"
    if [ -d "$path/.git" ]; then
        echo -e "${YELLOW}--> Updating $name...${NC}"
        if ! git -C "$path" pull --ff-only; then
            echo -e "${RED}[!] Update esuat pentru $name (posibil conflict local sau retea)${NC}"
            echo -e "${YELLOW}    Verifica: git -C \"$path\" status${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}--> Installing $name from GitHub...${NC}"
        if ! git clone "$url" "$path"; then
            echo -e "${RED}[!] Clone esuat pentru $name${NC}"
            return 1
        fi
    fi
    echo ""
    return 0
}

# ── Git install/update ───────────────────────────────────
manage_git_repos() {
    clear_screen
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${BLUE_BG}           SUITE INSTALLER & UPDATER             ${NC}"
    echo -e "${CYAN}=================================================${NC}\n"

    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}[!] Eroare: 'git' nu este instalat.${NC}"
        echo -e "${YELLOW}    Termux : pkg install git${NC}"
        echo -e "${YELLOW}    Debian : sudo apt install git${NC}"
        echo -e "${YELLOW}    macOS  : brew install git${NC}\n"
        pause_enter
        return 1
    fi

    local rc=0
    _slashx_process_repo "$AV_ROOT"    "$AV_REPO_URL"    || rc=1
    _slashx_process_repo "$PHOTO_ROOT" "$PHOTO_REPO_URL" || rc=1

    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}Process complete.${NC}"
    else
        echo -e "${YELLOW}Process complete cu erori — vezi mesajele de mai sus.${NC}"
    fi
    pause_enter
    return $rc
}

# ── Status repo (commit local, branch, ahead/behind) ─────
show_repo_status() {
    clear_screen
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${BLUE_BG}              REPO STATUS                        ${NC}"
    echo -e "${CYAN}=================================================${NC}\n"

    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}[!] git nu este instalat.${NC}"
        pause_enter; return
    fi

    for r in "$AV_ROOT" "$PHOTO_ROOT"; do
        local p="$BASE_DIR/$r"
        echo -e "${YELLOW}── $r ──${NC}"
        if [ ! -d "$p/.git" ]; then
            echo -e "  ${RED}Nu este instalat (foloseste optiunea [5])${NC}\n"
            continue
        fi
        local branch
        branch=$(git -C "$p" rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo -e "  Branch : $branch"
        echo -e "  Commit : $(git -C "$p" log -1 --pretty=format:'%h %s (%ar)' 2>/dev/null)"
        local local_changes
        local_changes=$(git -C "$p" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$local_changes" -gt 0 ]; then
            echo -e "  ${YELLOW}Modificari locale: $local_changes fisier(e) — pull poate esua${NC}"
        else
            echo -e "  ${GREEN}Tree curat${NC}"
        fi
        # Verificare ahead/behind fata de remote (fetch silent, best-effort)
        git -C "$p" fetch --quiet 2>/dev/null || true
        local ab
        ab=$(git -C "$p" rev-list --left-right --count "@{u}...HEAD" 2>/dev/null)
        if [ -n "$ab" ]; then
            local behind ahead
            behind=$(echo "$ab" | awk '{print $1}')
            ahead=$(echo "$ab"  | awk '{print $2}')
            [[ "$behind" =~ ^[0-9]+$ ]] && [ "$behind" -gt 0 ] && \
                echo -e "  ${YELLOW}$behind commit(s) noi pe remote (fa pull)${NC}"
            [[ "$ahead"  =~ ^[0-9]+$ ]] && [ "$ahead"  -gt 0 ] && \
                echo -e "  ${YELLOW}$ahead commit(s) locale necommit-uite remote${NC}"
        fi
        echo ""
    done
    pause_enter
}

# ── Submeniu Tools/Tests (mapped) ────────────────────────
show_sub_menu() {
    local menu_title="$1" av_dir="$2" photo_dir="$3" bg_color="$4"

    while true; do
        clear_screen
        echo -e "${CYAN}=================================================${NC}"
        echo -e "${bg_color}                 ${menu_title}                      ${NC}"
        echo -e "${CYAN}=================================================${NC}"

        local file_list=()
        # nullglob safe — daca nu exista fisiere, glob-ul devine empty array
        local prev_nullglob; prev_nullglob=$(shopt -p nullglob)
        shopt -s nullglob
        if [ -d "$BASE_DIR/$av_dir" ]; then
            for f in "$BASE_DIR/$av_dir"/*.sh; do
                [ -f "$f" ] && file_list+=("$f")
            done
        fi
        if [ -d "$BASE_DIR/$photo_dir" ]; then
            for f in "$BASE_DIR/$photo_dir"/*.sh; do
                [ -f "$f" ] && file_list+=("$f")
            done
        fi
        eval "$prev_nullglob"

        if [ ${#file_list[@]} -eq 0 ]; then
            echo -e "  ${RED}[!] Nu am gasit fisiere .sh in director.${NC}"
            echo -e "  ${YELLOW}    Foloseste [5] din meniul principal pentru a instala suitele,${NC}"
            echo -e "  ${YELLOW}    sau ruleaza versiunea .ps1 daca ai doar fisiere PowerShell.${NC}"
            echo -e "${CYAN}=================================================${NC}"
            pause_enter " [0] Back: "
            return
        fi

        local i
        for i in "${!file_list[@]}"; do
            local filepath="${file_list[$i]}"
            local prefix="[Unknown]"
            [[ "$filepath" == *"/$AV_ROOT/"* ]]    && prefix="[AV]"
            [[ "$filepath" == *"/$PHOTO_ROOT/"* ]] && prefix="[Photo]"
            echo -e "  [${YELLOW}$((i+1))${NC}] $prefix $(basename "$filepath")"
        done

        echo -e "\n  [${RED}0${NC}] Back to Main Menu"
        echo -e "${CYAN}=================================================${NC}"
        local t_choice
        read -r -p " Select item: " t_choice
        [ "$t_choice" = "0" ] && return

        if [[ "$t_choice" =~ ^[0-9]+$ ]] && [ "$t_choice" -gt 0 ] && [ "$t_choice" -le "${#file_list[@]}" ]; then
            local target_file="${file_list[$((t_choice-1))]}"
            local suite_root="$AV_ROOT"
            [[ "$target_file" == *"/$PHOTO_ROOT/"* ]] && suite_root="$PHOTO_ROOT"

            [ ! -x "$target_file" ] && chmod +x "$target_file" 2>/dev/null

            echo -e "\n${GREEN}--> Running $(basename "$target_file") ...${NC}\n"
            dbg "Target: $target_file | CWD: $BASE_DIR/$suite_root"

            # cd in suite root pentru contextul corect (CLAUDE.md, src/, etc.)
            # subshell () izoleaza failure-ul de procesul parinte
            (
                cd "$BASE_DIR/$suite_root" || exit 1
                bash "$target_file"
            )
            local sub_rc=$?
            [ $sub_rc -ne 0 ] && echo -e "${YELLOW}[!] Script-ul s-a incheiat cu exit code $sub_rc${NC}"
            pause_enter "Execution finished. Press Enter..."
        else
            echo -e "${RED}[!] Selectie invalida.${NC}"
            sleep 1
        fi
    done
}

# ── Run main launcher (AV sau Photo) ─────────────────────
run_main_launcher() {
    local root="$1" launcher="$2"
    local full_path="$BASE_DIR/$root/$launcher"

    if [ ! -f "$full_path" ]; then
        echo -e "${RED}Error: $root nu este instalat. Foloseste [5] din meniu.${NC}"
        sleep 2
        return 1
    fi

    [ ! -x "$full_path" ] && chmod +x "$full_path" 2>/dev/null

    dbg "Launching: $full_path"
    (
        cd "$BASE_DIR/$root" || exit 1
        bash "./$launcher"
    )
    local rc=$?
    [ $rc -ne 0 ] && echo -e "${YELLOW}[!] Launcher terminat cu cod $rc${NC}" && sleep 1
    return $rc
}

# ── Main Menu ────────────────────────────────────────────
while true; do
    clear_screen
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${BLUE_BG}            SLASHX MEDIA SUITE v${SUITE_VERSION}            ${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo -e " Host OS : ${GREEN}$CURRENT_OS${NC}"
    [ "$DEBUG" = "1" ] && echo -e " Debug   : ${YELLOW}ON${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo -e "  [${YELLOW}1${NC}] Video Processing ($AV_ROOT)"
    echo -e "  [${YELLOW}2${NC}] Photo Processing ($PHOTO_ROOT)"
    echo -e "  [${YELLOW}3${NC}] Tools & Updaters (Mapped)"
    echo -e "  [${YELLOW}4${NC}] Tests & Diagnostics (Mapped)"
    echo -e "  [${GREEN}5${NC}] Install / Update Suite (Git)"
    echo -e "  [${YELLOW}6${NC}] Repo Status"
    echo ""
    echo -e "  [${RED}0${NC}] Exit"
    echo -e "${CYAN}=================================================${NC}"
    read -r -p " Select option: " choice

    case "$choice" in
        1) run_main_launcher "$AV_ROOT"    "$AV_LAUNCHER" ;;
        2) run_main_launcher "$PHOTO_ROOT" "$PHOTO_LAUNCHER" ;;
        3) show_sub_menu "TOOLS MENU" "$AV_TOOLS_DIR" "$PHOTO_TOOLS_DIR" "$BLUE_BG" ;;
        4) show_sub_menu "TESTS MENU" "$AV_TESTS_DIR" "$PHOTO_TESTS_DIR" "$MAGENTA_BG" ;;
        5) manage_git_repos ;;
        6) show_repo_status ;;
        0) echo -e "\n${GREEN}Exiting SlashX Media Suite. Have a great day!${NC}\n"; exit 0 ;;
        "") : ;;  # Enter gol — re-deseneaza meniul
        *) echo -e "${RED}[!] Selectie invalida.${NC}"; sleep 1 ;;
    esac
done
