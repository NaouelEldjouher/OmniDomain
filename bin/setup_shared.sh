#!/bin/bash
# =============================================================================
# OmniDomain — Shared Databases
# Downloads: eggNOG + BUSCO lineages
# Used by:   FungalFlow + PhytoFlow
#
# Usage:
#   bash setup_shared.sh
#   bash setup_shared.sh --skip-eggnog
#   bash setup_shared.sh --only eggnog
#   bash setup_shared.sh --only busco
#   bash setup_shared.sh --db-root /mnt/data/databases
# =============================================================================

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    echo "Usage: $0 [--skip-eggnog] [--only eggnog|busco] [--db-root PATH]"
}

parse_args "$@"
print_header "OmniDomain — Shared Databases"
check_docker

# =============================================================================
# eggNOG Database
# Size: ~47GB — largest database in the platform
# =============================================================================
section "eggNOG  (~47GB)"

if should_run "eggnog"; then
    EGGNOG="${DB_ROOT}/eggnog"
    mkdir -p "$EGGNOG"

    if [[ "$SKIP_EGGNOG" == true ]]; then
        warn "eggNOG skipped — run separately when disk space available:"
        warn "  bash setup_shared.sh --only eggnog"
    elif already_exists "${EGGNOG}/eggnog.db"; then
        warn "eggNOG already exists — skipping ($(du -sh $EGGNOG | cut -f1))"
    else
        info "This will take 30-60 minutes and requires ~47GB disk space"
        docker run --rm \
            -v "${EGGNOG}:/eggnog_db" \
            quay.io/biocontainers/eggnog-mapper:2.1.12--pyhdfd78af_0 \
            bash -c "download_eggnog_data.py --data_dir /eggnog_db -y -f" \
            2>&1 | tee -a "$LOG_FILE"
        log "eggNOG complete"
    fi
fi

# =============================================================================
# BUSCO Lineages
# fungi_odb10     — FungalFlow
# embryophyta_odb10 — PhytoFlow
# Size: ~200MB each
# =============================================================================
section "BUSCO Lineages  (~500MB)"

if should_run "busco"; then
    BUSCODB="${DB_ROOT}/busco"
    mkdir -p "$BUSCODB"

    for lineage in fungi_odb10 embryophyta_odb10; do
        if already_exists "${BUSCODB}/lineages/${lineage}"; then
            warn "BUSCO ${lineage} already exists — skipping"
        else
            log "Downloading BUSCO lineage: ${lineage}..."
            docker run --rm \
                -v "${BUSCODB}:/busco_db" \
                ezlabgva/busco:v5.8.0_cv1 \
                busco --download ${lineage} --download_path /busco_db \
                2>&1 | tee -a "$LOG_FILE"
            log "BUSCO ${lineage} done"
        fi
    done
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "── Shared Databases Status ──────────────────────────────────"
print_status "eggNOG"        "${DB_ROOT}/eggnog"         "eggnog.db"
print_status "BUSCO fungi"   "${DB_ROOT}/busco/lineages"  "fungi_odb10"
print_status "BUSCO plants"  "${DB_ROOT}/busco/lineages"  "embryophyta_odb10"
echo ""
echo "── nextflow.config params ───────────────────────────────────"
echo "    eggnog_db_dir  = '${DB_ROOT}/eggnog'"
echo "    busco_db_path  = '${DB_ROOT}/busco'"

print_footer
