#!/bin/bash
# =============================================================================
# OmniDomain — PhytoFlow Databases
# Downloads: Helixer model + NLR-Annotator assets + CheckM2
#
# Usage:
#   bash setup_phytoflow.sh
#   bash setup_phytoflow.sh --only helixer
#   bash setup_phytoflow.sh --only nlr
#   bash setup_phytoflow.sh --only checkm2
#   bash setup_phytoflow.sh --db-root /mnt/data/databases
# =============================================================================

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    echo "Usage: $0 [--only helixer|nlr|checkm2] [--db-root PATH]"
}

parse_args "$@"
print_header "OmniDomain — PhytoFlow Databases"
check_docker
check_wget

# =============================================================================
# Helixer Model
# Model: land_plant_v0.3_a_0080.h5
# Size: ~500MB
# Covers: Arabidopsis, wheat, barley, tomato, maize, Brassica
# =============================================================================
section "Helixer Model  (~500MB)"

if should_run "helixer"; then
    HELIXER="${DB_ROOT}/helixer"
    mkdir -p "$HELIXER"
    MODEL="land_plant_v0.3_a_0080.h5"

    if already_exists "${HELIXER}/${MODEL}"; then
        warn "Helixer model already exists — skipping ($(du -sh ${HELIXER}/${MODEL} | cut -f1))"
    else
        log "Downloading Helixer land_plant model (~500MB)..."

        # Primary: fetch via Helixer Docker container
        docker run --rm \
            -v "${HELIXER}:/models" \
            gglyptodon/helixer-docker:helixer_v0.3.3_cuda_11.8.0-cudnn8 \
            fetch_helixer_models.py --lineage land_plant --dest /models \
            2>&1 | tee -a "$LOG_FILE" || {

            # Fallback: direct Zenodo download
            warn "Docker model fetch failed — trying Zenodo direct download..."
            wget -q --show-progress \
                "https://zenodo.org/record/8287677/files/${MODEL}" \
                -O "${HELIXER}/${MODEL}" \
                2>&1 | tee -a "$LOG_FILE"
        }

        already_exists "${HELIXER}/${MODEL}" \
            && log "Helixer model complete" \
            || error "Helixer model download failed — check ${HELIXER}"
    fi
fi

# =============================================================================
# NLR-Annotator Assets
# Contains: HMM profiles for NBS-LRR resistance gene detection
# Size: ~50MB
# =============================================================================
section "NLR-Annotator Assets  (~50MB)"

if should_run "nlr"; then
    NLRDB="${DB_ROOT}/nlr"
    mkdir -p "$NLRDB"

    if already_exists "${NLRDB}/NLR_Annotator_v2_assets"; then
        warn "NLR-Annotator assets already exist — skipping"
    else
        log "Downloading NLR-Annotator v2 assets..."

        wget -q --show-progress \
            "https://github.com/steuernb/NLR-Annotator/releases/download/v2.1/NLR_Annotator_v2_assets.zip" \
            -O "${NLRDB}/NLR_Annotator_v2_assets.zip" \
            2>&1 | tee -a "$LOG_FILE"

        unzip -q "${NLRDB}/NLR_Annotator_v2_assets.zip" -d "${NLRDB}/"
        rm "${NLRDB}/NLR_Annotator_v2_assets.zip"

        log "NLR-Annotator assets complete"
    fi
fi

# =============================================================================
# CheckM2 Database
# Used for: eukaryotic assembly completeness validation
# Size: ~3GB
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
    fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "── PhytoFlow Databases Status ───────────────────────────────"
print_status "Helixer model"    "${DB_ROOT}/helixer"  "land_plant_v0.3_a_0080.h5"
print_status "NLR-Annotator"   "${DB_ROOT}/nlr"       "NLR_Annotator_v2_assets"
print_status "CheckM2"         "${DB_ROOT}/checkm2"   "CheckM2_database/uniref100.KO.1.dmnd"
echo ""
echo "── nextflow.config params ───────────────────────────────────"
echo "    helixer_model = '${DB_ROOT}/helixer/land_plant_v0.3_a_0080.h5'"
echo "    nlr_assets    = '${DB_ROOT}/nlr/NLR_Annotator_v2_assets'"
echo "    checkm2_db    = '${DB_ROOT}/checkm2'"

print_footer

# ── NLR-Annotator ─────────────────────────────────────────────────────────────
NLR_DIR="${DB_BASE}/nlr"
mkdir -p "$NLR_DIR"
if [ ! -s "$NLR_DIR/NLR-Annotator-v2.1b.jar" ]; then
    log "Downloading NLR-Annotator v2.1b..."
    wget -q "https://github.com/steuernb/NLR-Annotator/raw/master/NLR-Annotator-v2.1b.jar" \
        -O "$NLR_DIR/NLR-Annotator-v2.1b.jar"
    wget -q "https://github.com/steuernb/NLR-Annotator/raw/master/src/mot.txt" \
        -O "$NLR_DIR/mot.txt"
    wget -q "https://github.com/steuernb/NLR-Annotator/raw/master/src/store.txt" \
        -O "$NLR_DIR/store.txt"
    log "NLR-Annotator ready at $NLR_DIR"
    log "Pass to pipeline: --nlr_jar $NLR_DIR/NLR-Annotator-v2.1b.jar"
else
    log "NLR-Annotator already present — skipping"
fi
