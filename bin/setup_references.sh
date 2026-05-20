#!/bin/bash
# bin/setup_references.sh

# 1. Define where databases should live
DB_DIR="${HOME}/databases"
HELIXER_DIR="${DB_DIR}/helixer_models/land_plant"

echo "Provisioning databases..."

# 2. Ensure directories exist
mkdir -p "${HELIXER_DIR}"

# 3. Use 'curl' or 'aws s3 sync' to pull the files
# Pro-tip: Check if files already exist so we don't redownload unnecessarily
if [ ! -f "${HELIXER_DIR}/model.h5" ]; then
    echo "Downloading Helixer land_plant model..."
    curl -L -o "${HELIXER_DIR}/model.h5" "https://github.com/weberlab-hhu/Helixer/releases/download/v0.3.3/land_plant.h5"
else
    echo "Model already exists. Skipping download."
fi

echo "All databases ready at ${DB_DIR}"