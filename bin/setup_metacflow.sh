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
# HUMAnN3 Databases
# Used for: functional pathway annotation of metagenomes
# ChocoPhlAn: ~15GB — marker gene database
# UniRef90:   ~20GB — protein function database
# =============================================================================
section "HUMAnN3 Databases  (~35GB)"

if should_run "humann3"; then
    HUMANN3DB="${DB_ROOT}/humann3"
    mkdir -p "$HUMANN3DB"

    if already_exists "${HUMANN3DB}/chocophlan" && \
       already_exists "${HUMANN3DB}/uniref"; then
        warn "HUMAnN3 databases already exist — skipping ($(du -sh $HUMANN3DB | cut -f1))"
    else
        log "Downloading HUMAnN3 databases (~35GB)..."
        docker run --rm \
            -v "${HUMANN3DB}:/humann3_db" \
            biobakery/humann:latest \
            bash -c "
                humann_databases --download chocophlan full /humann3_db
                humann_databases --download uniref uniref90_diamond /humann3_db
            " 2>&1 | tee -a "$LOG_FILE"

        log "HUMAnN3 databases complete"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "── Metacflow Databases Status ───────────────────────────────"
print_status "Kraken2"       "${DB_ROOT}/kraken2"   "hash.k2d"
print_status "Bracken"       "${DB_ROOT}/kraken2"   "database150mers.kmer_distrib"
print_status "HUMAnN3"       "${DB_ROOT}/humann3"   "chocophlan"
echo ""
echo "── nextflow.config params (add when Metacflow is built) ─────"
echo "    kraken2_db    = '${DB_ROOT}/kraken2'"
echo "    humann3_db    = '${DB_ROOT}/humann3'"

print_footer
