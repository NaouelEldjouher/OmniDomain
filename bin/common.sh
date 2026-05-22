#!/bin/bash
# =============================================================================
# OmniDomain — Shared Database Library
# Source this file from every setup_*.sh script
# =============================================================================

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
log()     { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅  $1${NC}" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️   $1${NC}" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[$(date '+%H:%M:%S')] ❌  $1${NC}" | tee -a "$LOG_FILE"; exit 1; }
section() { echo -e "\n${CYAN}══ $1 ══${NC}" | tee -a "$LOG_FILE"; }
info()    { echo -e "${BOLD}[$(date '+%H:%M:%S')]    $1${NC}" | tee -a "$LOG_FILE"; }

# ── Argument parsing ──────────────────────────────────────────────────────────
# Call parse_args "$@" at the top of each script
# Sets: DB_ROOT, SKIP_EGGNOG, ONLY
parse_args() {
    DB_ROOT="${OMNI_DB_ROOT:-/home/naoue/databases}"
    SKIP_EGGNOG=false
    ONLY=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-eggnog)  SKIP_EGGNOG=true ;;
            --only)         ONLY="$2"; shift ;;
            --db-root)      DB_ROOT="$2"; shift ;;
            --db-root=*)    DB_ROOT="${1#*=}" ;;
            --help|-h)      usage; exit 0 ;;
            *) echo "Unknown argument: $1"; exit 1 ;;
        esac
        shift
    done

    mkdir -p "$DB_ROOT"
    LOG_FILE="${DB_ROOT}/setup_databases.log"
    touch "$LOG_FILE"

    export DB_ROOT LOG_FILE SKIP_EGGNOG ONLY
}

# ── Guards ────────────────────────────────────────────────────────────────────
check_docker() {
    command -v docker &>/dev/null || error "Docker not found — install Docker first"
    docker info &>/dev/null       || error "Docker daemon not running — start Docker first"
    log "Docker available"
}

check_git() {
    command -v git &>/dev/null || error "Git not found — required for AMR databases"
}

check_wget() {
    command -v wget &>/dev/null || error "wget not found — install wget first"
}

# ── Skip logic ────────────────────────────────────────────────────────────────
# Returns 0 = run this db, 1 = skip it
should_run() {
    local name="$1"
    [[ -n "$ONLY" ]] && [[ "$ONLY" != "$name" ]] && return 1
    return 0
}

# ── Existence check ───────────────────────────────────────────────────────────
already_exists() {
    [[ -e "$1" ]]
}

# ── Summary printer ───────────────────────────────────────────────────────────
print_status() {
    local label="$1"
    local path="$2"
    local check="$3"

    if [[ -e "${path}/${check}" ]]; then
        SIZE=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "?")
        echo -e "  ${GREEN}✅  ${label}${NC}  (${SIZE})  →  ${path}"
    else
        echo -e "  ${RED}❌  ${label}${NC}  →  not found at ${path}"
    fi
}

# ── Banner helpers ────────────────────────────────────────────────────────────
print_header() {
    local title="$1"
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    printf  "║  %-56s║\n" "$title"
    echo "╠══════════════════════════════════════════════════════════╣"
    printf  "║  Root:     %-46s║\n" "$DB_ROOT"
    printf  "║  Log:      %-46s║\n" "$LOG_FILE"
    printf  "║  Started:  %-46s║\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$ONLY" ]] && printf "║  Only:     %-46s║\n" "$ONLY"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}

print_footer() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    printf  "║  %-56s║\n" "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
    printf  "║  %-56s║\n" "Log: $LOG_FILE"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}
