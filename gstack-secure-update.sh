#!/usr/bin/env bash
set -uo pipefail

# ============================================================================
# gstack-secure-update.sh
# Secure update workflow for gstack skills with automated security audit
# ============================================================================

# --- Configuration -----------------------------------------------------------
UPSTREAM_REPO="git@github.com:garrytan/gstack.git"
AUDIT_DIR="$HOME/.gstack-dev/upstream-audit"
SKILLS_DIR="$HOME/.claude/skills/gstack"
REPORT_DIR="$HOME/.gstack-dev/audit-reports"
DIFF_FILE=""
SKIP_FETCH=false
AUTO_MODE=false
VERBOSE=false

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Helpers -----------------------------------------------------------------
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
alert() { echo -e "${RED}[ALERT]${NC} $*"; }
header(){ echo -e "\n${BOLD}${CYAN}═══ $* ═══${NC}\n"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Secure gstack skill updater with automated security audit.

OPTIONS:
    -r, --repo URL       Upstream repo URL (default: $UPSTREAM_REPO)
    -s, --skills DIR     Skills install dir (default: $SKILLS_DIR)
    -a, --audit DIR      Audit working dir (default: $AUDIT_DIR)
    --skip-fetch         Skip git fetch (use existing audit dir)
    --auto               Non-interactive mode (abort on any ALERT)
    -v, --verbose        Show full diff output
    -h, --help           Show this help

WORKFLOW:
    1. Fetches latest gstack from upstream
    2. Diffs against your installed skills
    3. Scans for suspicious patterns (security audit)
    4. Generates a timestamped report
    5. Asks for confirmation before deploying

EXAMPLES:
    $(basename "$0")                          # Standard update check
    $(basename "$0") --verbose                # Show full diffs
    $(basename "$0") --skip-fetch             # Re-audit without fetching
    $(basename "$0") --auto                   # CI mode: abort on alerts
EOF
    exit 0
}

# --- Parse args --------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)      UPSTREAM_REPO="$2"; shift 2 ;;
        -s|--skills)    SKILLS_DIR="$2"; shift 2 ;;
        -a|--audit)     AUDIT_DIR="$2"; shift 2 ;;
        --skip-fetch)   SKIP_FETCH=true; shift ;;
        --auto)         AUTO_MODE=true; shift ;;
        -v|--verbose)   VERBOSE=true; shift ;;
        -h|--help)      usage ;;
        *)              echo "Unknown option: $1"; usage ;;
    esac
done

# --- Counters ----------------------------------------------------------------
ALERT_COUNT=0
WARN_COUNT=0
OK_COUNT=0

inc_alert() { ((ALERT_COUNT++)); }
inc_warn()  { ((WARN_COUNT++)); }
inc_ok()    { ((OK_COUNT++)); }

# =============================================================================
# PHASE 1: Fetch upstream
# =============================================================================
phase_fetch() {
    header "Phase 1: Fetch upstream gstack"

    if $SKIP_FETCH && [[ -d "$AUDIT_DIR/.git" ]]; then
        info "Skipping fetch (--skip-fetch), using existing: $AUDIT_DIR"
        return 0
    fi

    mkdir -p "$(dirname "$AUDIT_DIR")"

    if [[ -d "$AUDIT_DIR/.git" ]]; then
        info "Updating existing audit clone..."
        git -C "$AUDIT_DIR" fetch origin --prune
        git -C "$AUDIT_DIR" reset --hard origin/main
    else
        info "Cloning upstream: $UPSTREAM_REPO"
        git clone --depth=1 "$UPSTREAM_REPO" "$AUDIT_DIR"
    fi

    local commit
    commit=$(git -C "$AUDIT_DIR" log -1 --format="%h %s (%ci)")
    ok "Upstream at: $commit"
}

# =============================================================================
# PHASE 2: Diff against installed skills
# =============================================================================
phase_diff() {
    header "Phase 2: Diff against installed skills"

    if [[ ! -d "$SKILLS_DIR" ]]; then
        warn "Skills directory not found: $SKILLS_DIR"
        warn "This looks like a fresh install. All files will be new."
        return 0
    fi

    mkdir -p "$REPORT_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    DIFF_FILE="$REPORT_DIR/diff-${timestamp}.patch"

    # Generate diff (ignore .git, dist/, node_modules/)
    diff -ruN \
        --exclude='.git' \
        --exclude='dist' \
        --exclude='node_modules' \
        --exclude='bun.lock' \
        "$SKILLS_DIR" "$AUDIT_DIR" > "$DIFF_FILE" 2>/dev/null || true

    local lines
    lines=$(wc -l < "$DIFF_FILE" | tr -d ' ')

    if [[ "$lines" -eq 0 ]]; then
        ok "No differences found — skills are up to date!"
        rm -f "$DIFF_FILE"
        exit 0
    fi

    info "Diff: $lines lines → $DIFF_FILE"

    # Summary of changed files
    local changed_files
    changed_files=$(grep -c '^diff ' "$DIFF_FILE" 2>/dev/null || echo "0")
    info "Files changed: $changed_files"

    if $VERBOSE; then
        echo ""
        cat "$DIFF_FILE"
        echo ""
    fi

    # Show changed file list (abbreviated)
    echo ""
    local file_list
    file_list=$(grep '^diff ' "$DIFF_FILE" | sed 's|.*/upstream-audit/||' | head -30)
    info "Changed files (top 30 of $changed_files):"
    echo "$file_list" | while read -r f; do
        echo "  - $f"
    done
    [[ "$changed_files" -gt 30 ]] && echo "  ... and $((changed_files - 30)) more"
    echo ""
}

# =============================================================================
# PHASE 3: Security audit
# =============================================================================
phase_security() {
    header "Phase 3: Security Audit"

    local target="$AUDIT_DIR"

    # --- 3a. Suspicious shell commands in SKILL.md files ---
    info "Scanning SKILL.md files for suspicious commands..."

    local suspicious_cmds=(
        'curl\s'
        'wget\s'
        'nc\s'
        'ncat\s'
        'netcat'
        'bash\s*-c'
        'eval\s'
        'base64\s'
        'openssl\s.*enc'
        'python.*-c'
        'ruby.*-e'
        'perl.*-e'
        'xargs.*sh'
        'dd\s.*if='
        '>\s*/dev/'
        'mkfifo'
        'socat'
        '/dev/tcp/'
        '/dev/udp/'
    )

    for pattern in "${suspicious_cmds[@]}"; do
        local matches
        matches=$(grep -rn --include='*.md' --include='*.tmpl' -E "$pattern" "$target" 2>/dev/null | grep -v '^\s*#' || true)
        if [[ -n "$matches" ]]; then
            warn "Found pattern '$pattern':"
            echo "$matches" | head -5 | while read -r line; do
                echo "    $line"
            done
            inc_warn
        fi
    done

    # --- 3b. External URLs (new or changed) ---
    info "Scanning for external URLs..."

    local url_patterns=(
        'https?://[^ "'"'"')>]+'
    )

    local new_urls
    new_urls=$(grep -rohE 'https?://[^ "'"'"')>]+' "$target"/*.md "$target"/**/*.md 2>/dev/null | sort -u || true)

    local known_safe_domains=(
        'github.com/anthropics'
        'github.com/garrettrowell'
        'claude.ai'
        'anthropic.com'
        'npmjs.com'
        'bun.sh'
        'playwright.dev'
        'nodejs.org'
        'example.com'
        'localhost'
        '127.0.0.1'
    )

    if [[ -n "$new_urls" ]]; then
        local unknown_urls=""
        while IFS= read -r url; do
            local is_safe=false
            for domain in "${known_safe_domains[@]}"; do
                if [[ "$url" == *"$domain"* ]]; then
                    is_safe=true
                    break
                fi
            done
            if ! $is_safe; then
                unknown_urls+="    $url"$'\n'
            fi
        done <<< "$new_urls"

        if [[ -n "$unknown_urls" ]]; then
            warn "URLs pointing to non-allowlisted domains:"
            echo "$unknown_urls"
            inc_warn
        else
            ok "All URLs point to known-safe domains"
            inc_ok
        fi
    else
        ok "No external URLs found"
        inc_ok
    fi

    # --- 3c. New executables or binaries ---
    info "Scanning for new executables..."

    local new_execs
    new_execs=$(find "$target" -type f \( -perm +111 -o -name '*.sh' -o -name '*.bash' \) \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/dist/*' 2>/dev/null || true)

    if [[ -n "$new_execs" ]]; then
        info "Executable files found:"
        echo "$new_execs" | while read -r f; do
            echo "    $f"
        done
        inc_warn
    fi

    # --- 3d. Prompt injection patterns ---
    info "Scanning for prompt injection patterns..."

    local injection_patterns=(
        'ignore previous instructions'
        'ignore all previous'
        'disregard your instructions'
        'override safety'
        'you are now'
        'act as.*admin'
        'system prompt'
        'IMPORTANT:.*override'
        'new instructions'
        'forget everything'
        '<system>'
        '</system>'
        'anthropic.*internal'
    )

    for pattern in "${injection_patterns[@]}"; do
        local matches
        matches=$(grep -rni --include='*.md' --include='*.tmpl' "$pattern" "$target" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            alert "PROMPT INJECTION PATTERN: '$pattern'"
            echo "$matches" | head -3 | while read -r line; do
                echo "    $line"
            done
            inc_alert
        fi
    done

    # --- 3e. Data exfiltration patterns ---
    info "Scanning for data exfiltration patterns..."

    local exfil_patterns=(
        'ANTHROPIC_API_KEY'
        'OPENAI_API_KEY'
        'API_KEY'
        'SECRET_KEY'
        'ACCESS_TOKEN'
        'PASSWORD'
        '\$HOME/\.ssh'
        '\$HOME/\.aws'
        '\$HOME/\.env'
        'id_rsa'
        'credentials'
        '/etc/passwd'
        '/etc/shadow'
    )

    for pattern in "${exfil_patterns[@]}"; do
        local matches
        matches=$(grep -rn --include='*.md' --include='*.tmpl' --include='*.sh' --include='*.ts' \
            -E "$pattern" "$target" 2>/dev/null \
            | grep -v 'ANTHROPIC_API_KEY.*required\|needs.*API_KEY\|example\|\.env\.example\|test/' || true)
        if [[ -n "$matches" ]]; then
            warn "Sensitive keyword '$pattern' referenced:"
            echo "$matches" | head -3 | while read -r line; do
                echo "    $line"
            done
            inc_warn
        fi
    done

    # --- 3f. New MCP tool references ---
    info "Scanning for new MCP tool references..."

    local mcp_refs
    mcp_refs=$(grep -roh --include='*.md' --include='*.tmpl' 'mcp__[a-zA-Z0-9_-]*__[a-zA-Z0-9_]*' "$target" 2>/dev/null | sort -u || true)

    if [[ -n "$mcp_refs" ]]; then
        info "MCP tool references found:"
        echo "$mcp_refs" | while read -r ref; do
            echo "    $ref"
        done
        inc_warn
    else
        ok "No MCP tool references"
        inc_ok
    fi

    # --- 3g. File permission changes ---
    info "Scanning for chmod/chown commands..."

    local perm_changes
    perm_changes=$(grep -rn --include='*.md' --include='*.tmpl' --include='*.sh' \
        -E 'chmod\s|chown\s|chgrp\s' "$target" 2>/dev/null || true)

    if [[ -n "$perm_changes" ]]; then
        warn "Permission modification commands found:"
        echo "$perm_changes" | while read -r line; do
            echo "    $line"
        done
        inc_warn
    else
        ok "No permission modifications"
        inc_ok
    fi
}

# =============================================================================
# PHASE 4: Report
# =============================================================================
phase_report() {
    header "Phase 4: Audit Report"

    local timestamp
    timestamp=$(date +%Y-%m-%d\ %H:%M:%S)
    local upstream_commit
    upstream_commit=$(git -C "$AUDIT_DIR" log -1 --format="%H %s" 2>/dev/null || echo "unknown")

    echo -e "${BOLD}Audit Summary — $timestamp${NC}"
    echo "Upstream commit: $upstream_commit"
    echo ""
    echo -e "  ${RED}ALERTS:   $ALERT_COUNT${NC}"
    echo -e "  ${YELLOW}WARNINGS: $WARN_COUNT${NC}"
    echo -e "  ${GREEN}OK:       $OK_COUNT${NC}"
    echo ""

    # Save report
    local report_file="$REPORT_DIR/report-$(date +%Y%m%d-%H%M%S).txt"
    mkdir -p "$REPORT_DIR"
    cat > "$report_file" <<EOF
gstack Security Audit Report
=============================
Date:     $timestamp
Upstream: $upstream_commit
Skills:   $SKILLS_DIR

Alerts:   $ALERT_COUNT
Warnings: $WARN_COUNT
OK:       $OK_COUNT

Diff:     ${DIFF_FILE:-"(no diff)"}
EOF
    info "Report saved: $report_file"

    if [[ $ALERT_COUNT -gt 0 ]]; then
        alert "═══════════════════════════════════════════════════"
        alert " $ALERT_COUNT ALERT(s) FOUND — Review carefully before deploying!"
        alert "═══════════════════════════════════════════════════"
    fi
}

# =============================================================================
# PHASE 5: Deploy (with confirmation)
# =============================================================================
phase_deploy() {
    header "Phase 5: Deploy"

    if $AUTO_MODE && [[ $ALERT_COUNT -gt 0 ]]; then
        alert "Auto mode: aborting due to $ALERT_COUNT alert(s)"
        exit 1
    fi

    if [[ $ALERT_COUNT -gt 0 ]]; then
        echo -e "${RED}${BOLD}⚠ There are $ALERT_COUNT ALERT(s). Deploying is risky.${NC}"
        echo ""
    fi

    echo -e "${BOLD}Deploy upstream to $SKILLS_DIR ?${NC}"
    echo ""
    echo "  [y] Yes, deploy"
    echo "  [d] Show full diff first"
    echo "  [n] No, abort"
    echo ""
    read -rp "Choice: " choice

    case $choice in
        d|D)
            if [[ -n "$DIFF_FILE" && -f "$DIFF_FILE" ]]; then
                less "$DIFF_FILE"
            else
                diff -ruN --exclude='.git' --exclude='dist' --exclude='node_modules' \
                    "$SKILLS_DIR" "$AUDIT_DIR" | less
            fi
            echo ""
            read -rp "Deploy now? [y/N]: " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                info "Aborted."
                exit 0
            fi
            ;;
        y|Y)
            ;;
        *)
            info "Aborted."
            exit 0
            ;;
    esac

    info "Deploying..."

    # Backup current install
    local backup_dir="$REPORT_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    if [[ -d "$SKILLS_DIR" ]]; then
        info "Backing up current install → $backup_dir"
        cp -r "$SKILLS_DIR" "$backup_dir"
    fi

    # Sync files (exclude .git, dist, node_modules)
    rsync -a --delete \
        --exclude='.git' \
        --exclude='dist/' \
        --exclude='node_modules/' \
        --exclude='bun.lock' \
        "$AUDIT_DIR/" "$SKILLS_DIR/"

    # Rebuild if setup exists
    if [[ -x "$SKILLS_DIR/setup" ]]; then
        info "Running setup (build binaries)..."
        (cd "$SKILLS_DIR" && ./setup --no-prefix 2>&1) || warn "Setup had issues — check manually"
    fi

    ok "Deploy complete!"
    ok "Backup at: $backup_dir"
    echo ""
    info "To rollback: rm -rf '$SKILLS_DIR' && cp -r '$backup_dir' '$SKILLS_DIR'"
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo -e "${BOLD}${CYAN}"
    echo "  ┌─────────────────────────────────────────┐"
    echo "  │   gstack Secure Update                   │"
    echo "  │   Fetch → Diff → Audit → Deploy          │"
    echo "  └─────────────────────────────────────────┘"
    echo -e "${NC}"

    phase_fetch
    phase_diff
    phase_security
    phase_report
    phase_deploy
}

main "$@"
