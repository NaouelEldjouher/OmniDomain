#!/bin/bash
# =============================================================================
# OmniDomain — FungalFlow Databases
# Downloads: Funannotate + dbCAN
#
# Usage:
#   bash setup_fungalflow.sh
#   bash setup_fungalflow.sh --only funannotate
#   bash setup_fungalflow.sh --only dbcan
#   bash setup_fungalflow.sh --db-root /mnt/data/databases
# =============================================================================

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    echo "Usage: $0 [--only funannotate|dbcan] [--db-root PATH]"
}

parse_args "$@"
print_header "OmniDomain — FungalFlow Databases"
check_docker

# =============================================================================
# Funannotate Database
# Size: ~8GB
# Issue: setupDB.py has a broken MEROPS URL — patched automatically here
# =============================================================================
section "Funannotate  (~8GB)"

if should_run "funannotate"; then
    FUNDB="${DB_ROOT}/funannotate"
    mkdir -p "$FUNDB"

    if already_exists "${FUNDB}/Pfam-A.hmm"; then
        warn "Funannotate already exists — skipping ($(du -sh $FUNDB | cut -f1))"
    else
        # Step 1: extract setupDB.py from container
        log "Extracting setupDB.py from container..."
        TMPNAME="fundb_extract_$$"
        docker create --name "$TMPNAME" nextgenusfs/funannotate:latest > /dev/null
        docker cp \
            "${TMPNAME}":/venv/lib/python3.8/site-packages/funannotate/setupDB.py \
            "${FUNDB}/setupDB_orig.py"
        docker rm "$TMPNAME" > /dev/null

        # Step 2: patch — replace all info.get('x') unpacking with null-safe version
        # The MEROPS database URL returns None — causes TypeError on all setups
        log "Patching setupDB.py (fixing MEROPS URL bug)..."
        python3 << PYEOF
import re
with open('${FUNDB}/setupDB_orig.py', 'r') as f:
    lines = f.readlines()
new_lines = []
for line in lines:
    m = re.match(r'^(\s*)type, name, version, date, records, checksum = info\.get\(\'(\w+)\'\)\s*$', line)
    if m:
        indent, key = m.group(1), m.group(2)
        new_lines += [
            f"{indent}_tmp_{key} = info.get('{key}')\n",
            f"{indent}if not _tmp_{key}: return\n",
            f"{indent}type, name, version, date, records, checksum = _tmp_{key}\n"
        ]
    else:
        new_lines.append(line)
with open('${FUNDB}/setupDB_patched.py', 'w') as f:
    f.writelines(new_lines)
print('Patch applied successfully')
PYEOF

        python3 -m py_compile "${FUNDB}/setupDB_patched.py" \
            && log "setupDB.py syntax verified" \
            || error "setupDB.py patch failed — check ${FUNDB}/setupDB_patched.py"

        # Step 3: run setup with patched script
        info "Downloading Funannotate database (~8GB, 10-20 min)..."
        docker run --rm \
            -v "${FUNDB}:/database" \
            -e FUNANNOTATE_DB=/database \
            nextgenusfs/funannotate:latest \
            bash -c "
                cp /database/setupDB_patched.py \
                    /venv/lib/python3.8/site-packages/funannotate/setupDB.py
                funannotate setup -d /database -b dikarya \
                    --database uniprot,pfam,dbCAN,repeat,go,mibig,interpro,busco_outgroups,gene2product
            " 2>&1 | tee -a "$LOG_FILE"

        log "Funannotate database complete"
    fi
fi

# =============================================================================
# dbCAN Database
# Size: ~2GB
# Builds: DIAMOND index + HMMer profiles
# =============================================================================
section "dbCAN  (~2GB)"

if should_run "dbcan"; then
    DBCANDB="${DB_ROOT}/dbcan"
    mkdir -p "$DBCANDB"

    if already_exists "${DBCANDB}/CAZy.dmnd"; then
        warn "dbCAN already exists — skipping ($(du -sh $DBCANDB | cut -f1))"
    else
        log "Downloading dbCAN via run_dbcan database..."
        docker run --rm \
            -v "${DBCANDB}:/db" \
            quay.io/biocontainers/dbcan:4.1.4--pyhdfd78af_0 \
            bash -c "cd /db && run_dbcan database --db_dir /db" \
            2>&1 | tee -a "$LOG_FILE"

        # Build DIAMOND index if not built by run_dbcan
        if ! already_exists "${DBCANDB}/CAZy.dmnd"; then
            CAZYFASTA=$(ls "${DBCANDB}"/CAZyDB*.fa 2>/dev/null | head -1 || true)
            if [[ -n "$CAZYFASTA" ]]; then
                log "Building DIAMOND index..."
                docker run --rm \
                    -v "${DBCANDB}:/db" \
                    quay.io/biocontainers/dbcan:4.1.4--pyhdfd78af_0 \
                    diamond makedb \
                        --in "/db/$(basename $CAZYFASTA)" \
                        -d /db/CAZy --quiet \
                    2>&1 | tee -a "$LOG_FILE"
            else
                warn "CAZyDB FASTA not found — DIAMOND index not built"
            fi
        fi

        log "dbCAN complete"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "── FungalFlow Databases Status ──────────────────────────────"
print_status "Funannotate"  "${DB_ROOT}/funannotate"  "Pfam-A.hmm"
print_status "dbCAN"        "${DB_ROOT}/dbcan"         "CAZy.dmnd"
echo ""
echo "── nextflow.config params ───────────────────────────────────"
echo "    funannotate_db = '${DB_ROOT}/funannotate'"
echo "    dbcan_db       = '${DB_ROOT}/dbcan'"

print_footer
