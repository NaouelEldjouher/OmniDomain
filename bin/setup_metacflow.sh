#!/bin/bash
# =============================================================================
# OmniDomain — Metacflow Databases
# Downloads: Kraken2 standard + Bracken + HUMAnN3 (ChocoPhlAn + UniRef)
#
# Status: Metacflow is in development — databases listed here are planned
#
# Usage:
#   bash setup_metacflow.sh
#   bash setup_metacflow.sh --only kraken2
#   bash setup_metacflow.sh --only bracken
#   bash setup_metacflow.sh --only humann3
#   bash setup_metacflow.sh --db-root /mnt/data/databases
# =============================================================================

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    echo "Usage: $0 [--only kraken2|bracken|humann3] [--db-root PATH]"
}

parse_args "$@"
print_header "OmniDomain — Metacflow Databases"
check_docker
check_wget

warn "Metacflow is in development — databases are downloaded but pipeline is not yet built"

# =============================================================================
# Kraken2 Standard Database
# Used for: taxonomic profiling of metagenomic reads
# Size: ~70GB (standard) or ~8GB (minikraken — use for testing)
# =============================================================================
section "Kraken2 Standard Database  (~70GB)"

if should_run "kraken2"; then
    KRAKENDB="${DB_ROOT}/kraken2"
    mkdir -p "$KRAKENDB"

    if already_exists "${KRAKENDB}/hash.k2d"; then
        warn "Kraken2 database already exists — skipping ($(du -sh $KRAKENDB | cut -f1))"
    else
        info "Downloading Kraken2 standard database (~70GB)..."
        info "For testing use minikraken: --only kraken2_mini"

        docker run --rm \
            -v "${KRAKENDB}:/kraken2_db" \
            staphb/kraken2:latest \
            bash -c "
                kraken2-build --standard --db /kraken2_db --threads 8
            " 2>&1 | tee -a "$LOG_FILE"

        log "Kraken2 database complete"
    fi
fi

# ── Kraken2 mini (for testing only) ─────────────────────────────────────────
if should_run "kraken2_mini"; then
    KRAKENDB="${DB_ROOT}/kraken2_mini"
    mkdir -p "$KRAKENDB"

    if already_exists "${KRAKENDB}/hash.k2d"; then
        warn "Kraken2 mini already exists — skipping"
    else
        log "Downloading Kraken2 MiniKraken (~8GB — for testing only)..."
        wget -q --show-progress \
            "https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20231009.tar.gz" \
            -O "${KRAKENDB}/k2_standard_08gb.tar.gz" \
            2>&1 | tee -a "$LOG_FILE"

        tar -xzf "${KRAKENDB}/k2_standard_08gb.tar.gz" -C "$KRAKENDB"
        rm "${KRAKENDB}/k2_standard_08gb.tar.gz"
        log "Kraken2 mini complete"
    fi
fi

# =============================================================================
# Bracken Database
# Used for: abundance re-estimation from Kraken2 output
# Size: built from Kraken2 database — no separate download
# =============================================================================
section "Bracken Database  (built from Kraken2)"

if should_run "bracken"; then
    KRAKENDB="${DB_ROOT}/kraken2"

    if ! already_exists "${KRAKENDB}/hash.k2d"; then
        warn "Kraken2 database not found — build Kraken2 first"
        warn "  bash setup_metacflow.sh --only kraken2"
    elif already_exists "${KRAKENDB}/database150mers.kmer_distrib"; then
        warn "Bracken database already exists — skipping"
    else
        log "Building Bracken database from Kraken2..."
        docker run --rm \
            -v "${KRAKENDB}:/kraken2_db" \
            staphb/bracken:latest \
            bash -c "
                bracken-build -d /kraken2_db -t 8 -l 150
            " 2>&1 | tee -a "$LOG_FILE"

        log "Bracken database complete"
    fi
fi

 
# =============================================================================
# CheckM2 Database
# Used for: MAG quality assessment (completeness + contamination)
# Size: ~3GB
# Pass to pipeline: --checkm2_db /path/to/checkm2/
# =============================================================================
section "CheckM2 Database  (~3GB)"
 
if should_run "checkm2"; then
    CHECKM2="${DB_ROOT}/checkm2"
    mkdir -p "$CHECKM2"
 
    if already_exists "${CHECKM2}/CheckM2_database/uniref100.KO.1.dmnd"; then
        warn "CheckM2 already exists — skipping ($(du -sh $CHECKM2 | cut -f1))"
    else
        log "Downloading CheckM2 database (~3GB)..."
        docker run --rm \
            -v "${CHECKM2}:/checkm2_db" \
            quay.io/biocontainers/checkm2:1.0.1--pyh7cba7a3_0 \
            checkm2 database --download --path /checkm2_db \
            2>&1 | tee -a "$LOG_FILE"
 
        log "CheckM2 complete"
        log "Pass to pipeline: --checkm2_db ${CHECKM2}"
    fi
fi
 
# =============================================================================
# ResFinder Database
# Used for: AMR gene detection in MAGs
# Size: ~200MB
# Pass to pipeline: --resfinder_db /path/to/resfinder_db/
# =============================================================================
section "ResFinder Database  (~200MB)"
 
if should_run "resfinder"; then
    RESFINDERDB="${DB_ROOT}/resfinder/resfinder_db"
    mkdir -p "${DB_ROOT}/resfinder"
 
    if already_exists "${RESFINDERDB}"; then
        warn "ResFinder database already exists — skipping"
    else
        log "Cloning ResFinder database from CGE..."
        git clone \
            https://git@bitbucket.org/genomicepidemiology/resfinder_db.git \
            "${RESFINDERDB}" \
            2>&1 | tee -a "$LOG_FILE"
 
        log "Indexing ResFinder database..."
        cd "${RESFINDERDB}"
        python INSTALL.py
        cd -
 
        log "ResFinder complete"
        log "Pass to pipeline: --resfinder_db ${RESFINDERDB}"
    fi
fi
 
# =============================================================================
# Summary
# =============================================================================
echo ""
echo "── MetaCflow Databases Status ───────────────────────────────"
print_status "Kraken2 standard" "${DB_ROOT}/kraken2"      "hash.k2d"
print_status "Kraken2 mini"     "${DB_ROOT}/kraken2_mini" "hash.k2d"
print_status "Bracken"          "${DB_ROOT}/kraken2"      "database150mers.kmer_distrib"
print_status "CheckM2"          "${DB_ROOT}/checkm2"      "CheckM2_database/uniref100.KO.1.dmnd"
print_status "ResFinder"        "${DB_ROOT}/resfinder"    "resfinder_db"
echo ""
echo "── Pass to MetaCflow pipeline ───────────────────────────────"
echo "    --kraken2_db  '${DB_ROOT}/kraken2'"
echo "    --checkm2_db  '${DB_ROOT}/checkm2'"
echo "    --resfinder_db '${DB_ROOT}/resfinder/resfinder_db'"
echo ""
echo "── Note on Prokka ───────────────────────────────────────────"
echo "    Prokka downloads its own databases at runtime."
echo "    No pre-download needed."
 

print_footer
