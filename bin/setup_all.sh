#!/bin/bash
# =============================================================================
# OmniDomain — Master Database Setup Script
# Calls all pipeline-specific setup scripts in the correct order
#
# Usage:
#   bash setup_all.sh                        # download everything
#   bash setup_all.sh --skip-eggnog          # skip the 47GB eggNOG database
#   bash setup_all.sh --db-root /mnt/data    # custom database root
#   bash setup_all.sh --pipeline fungal      # FungalFlow + shared only
#   bash setup_all.sh --pipeline plant       # PhytoFlow + shared only
#   bash setup_all.sh --pipeline amr         # NextAMR only (no shared)
#   bash setup_all.sh --pipeline meta        # Metacflow only (development)
#
# Individual pipeline scripts:
#   bash setup_shared.sh      ← eggNOG + BUSCO
#   bash setup_fungalflow.sh  ← Funannotate + dbCAN
#   bash setup_phytoflow.sh   ← Helixer + NLR + CheckM2
#   bash setup_nextamr.sh     ← ResFinder + PointFinder + PlasmidFinder
#   bash setup_metacflow.sh   ← Kraken2 + HUMAnN3 (development)
# =============================================================================

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ── Argument parsing ──────────────────────────────────────────────────────────
DB_ROOT="${OMNI_DB_ROOT:-/home/naoue/databases}"
SKIP_EGGNOG=false
PIPELINE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-eggnog)  SKIP_EGGNOG=true;    EXTRA_ARGS+=("--skip-eggnog") ;;
        --pipeline)     PIPELINE="$2";       shift ;;
        --pipeline=*)   PIPELINE="${1#*=}" ;;
        --db-root)      DB_ROOT="$2";        EXTRA_ARGS+=("--db-root" "$2"); shift ;;
        --db-root=*)    DB_ROOT="${1#*=}";   EXTRA_ARGS+=("$1") ;;
        --help|-h)      usage; exit 0 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
    shift
done

mkdir -p "$DB_ROOT"
LOG_FILE="${DB_ROOT}/setup_databases.log"
touch "$LOG_FILE"

# ── Banner ────────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         OmniDomain — Master Database Setup              ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf  "║  DB Root:  %-46s║\n" "$DB_ROOT"
printf  "║  Log:      %-46s║\n" "$LOG_FILE"
printf  "║  Started:  %-46s║\n" "$(date '+%Y-%m-%d %H:%M:%S')"
[[ -n "$PIPELINE" ]]   && printf "║  Pipeline: %-46s║\n" "$PIPELINE"
[[ "$SKIP_EGGNOG" == true ]] && printf "║  eggNOG:   %-46s║\n" "SKIPPED"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Individual scripts available:"
echo "║    bash setup_shared.sh      ← eggNOG + BUSCO"
echo "║    bash setup_fungalflow.sh  ← Funannotate + dbCAN"
echo "║    bash setup_phytoflow.sh   ← Helixer + NLR + CheckM2"
echo "║    bash setup_nextamr.sh     ← ResFinder + PointFinder"
echo "║    bash setup_metacflow.sh   ← Kraken2 + HUMAnN3 (dev)"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Run scripts ───────────────────────────────────────────────────────────────
run_script() {
    local script="$1"
    local label="$2"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Running: $label"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "${SCRIPT_DIR}/${script}" "${EXTRA_ARGS[@]}" || {
        echo -e "\033[0;31m❌  ${label} failed — check ${LOG_FILE}\033[0m"
        exit 1
    }
}

case "$PIPELINE" in
    "fungal"|"fungalflow")
        run_script "setup_shared.sh"     "Shared (eggNOG + BUSCO)"
        run_script "setup_fungalflow.sh" "FungalFlow (Funannotate + dbCAN)"
        ;;
    "plant"|"phytoflow")
        run_script "setup_shared.sh"    "Shared (eggNOG + BUSCO)"
        run_script "setup_phytoflow.sh" "PhytoFlow (Helixer + NLR + CheckM2)"
        ;;
    "amr"|"nextamr")
        run_script "setup_nextamr.sh"   "NextAMR (ResFinder + PointFinder + PlasmidFinder)"
        ;;
    "meta"|"metacflow")
        run_script "setup_metacflow.sh" "Metacflow (Kraken2 + HUMAnN3)"
        ;;
    "")
        # No pipeline flag — run everything
        run_script "setup_shared.sh"     "Shared (eggNOG + BUSCO)"
        run_script "setup_fungalflow.sh" "FungalFlow (Funannotate + dbCAN)"
        run_script "setup_phytoflow.sh"  "PhytoFlow (Helixer + NLR + CheckM2)"
        run_script "setup_nextamr.sh"    "NextAMR (ResFinder + PointFinder + PlasmidFinder)"
        # Metacflow skipped by default — still in development
        echo ""
        echo -e "\033[1;33m⚠️   Metacflow databases skipped — run separately when Metacflow is built:\033[0m"
        echo "    bash setup_metacflow.sh"
        ;;
    *)
        echo "Unknown pipeline: $PIPELINE"
        echo "Valid options: fungal | plant | amr | meta"
        exit 1
        ;;
esac

# ── Final summary ─────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                 All Databases Summary                   ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  SHARED"
print_status "eggNOG"           "${DB_ROOT}/eggnog"             "eggnog.db"
print_status "BUSCO fungi"      "${DB_ROOT}/busco/lineages"     "fungi_odb10"
print_status "BUSCO plants"     "${DB_ROOT}/busco/lineages"     "embryophyta_odb10"
echo "║"
echo "║  FUNGALFLOW"
print_status "Funannotate"      "${DB_ROOT}/funannotate"        "Pfam-A.hmm"
print_status "dbCAN"            "${DB_ROOT}/dbcan"              "CAZy.dmnd"
echo "║"
echo "║  PHYTOFLOW"
print_status "Helixer"          "${DB_ROOT}/helixer"            "land_plant_v0.3_a_0080.h5"
print_status "NLR-Annotator"    "${DB_ROOT}/nlr"                "NLR_Annotator_v2_assets"
print_status "CheckM2"          "${DB_ROOT}/checkm2"            "CheckM2_database/uniref100.KO.1.dmnd"
echo "║"
echo "║  NEXTAMR"
print_status "ResFinder"        "${DB_ROOT}/resfinder"          "resfinder_db"
print_status "PointFinder"      "${DB_ROOT}/pointfinder"        "pointfinder_db"
print_status "PlasmidFinder"    "${DB_ROOT}/plasmidfinder"       "plasmidfinder_db"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Add to nextflow.config params {}:"
echo "║    funannotate_db   = '${DB_ROOT}/funannotate'"
echo "║    dbcan_db         = '${DB_ROOT}/dbcan'"
echo "║    eggnog_db_dir    = '${DB_ROOT}/eggnog'"
echo "║    busco_db_path    = '${DB_ROOT}/busco'"
echo "║    helixer_model    = '${DB_ROOT}/helixer/land_plant_v0.3_a_0080.h5'"
echo "║    nlr_assets       = '${DB_ROOT}/nlr/NLR_Annotator_v2_assets'"
echo "║    checkm2_db       = '${DB_ROOT}/checkm2'"
echo "║    resfinder_db     = '${DB_ROOT}/resfinder/resfinder_db'"
echo "║    pointfinder_db   = '${DB_ROOT}/pointfinder/pointfinder_db'"
echo "║    plasmidfinder_db = '${DB_ROOT}/plasmidfinder/plasmidfinder_db'"
echo "╠══════════════════════════════════════════════════════════╣"
printf  "║  Completed: %-45s║\n" "$(date '+%Y-%m-%d %H:%M:%S')"
printf  "║  Log:       %-45s║\n" "$LOG_FILE"
echo "╚══════════════════════════════════════════════════════════╝"
