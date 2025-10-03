#!/bin/bash
set -e
set -x

STAGING_TAR=$(cd $(dirname $1) && pwd)/$(basename $1)
BUILDROOT=$(cd $(dirname $2) && pwd)/$(basename $2)

echo "Creating staging tar: $STAGING_TAR"
echo "Target buildroot: $BUILDROOT"

# Create a temporary directory for staging
TEMP_STAGE=$(mktemp -d)
echo "Using temporary staging directory: $TEMP_STAGE"

{STAGE_DATA}

echo "Creating tar archive from staged files..."
cd "$TEMP_STAGE"
tar -cf "$STAGING_TAR" .

echo "Extracting tar to buildroot..."
mkdir -p "$BUILDROOT"
cd "$BUILDROOT"
tar -xf "$STAGING_TAR"

echo "Cleaning up temporary staging directory"
rm -rf "$TEMP_STAGE"

echo "Final buildroot contents:"
find "$BUILDROOT" -type f -exec file {} \;