#!/bin/bash
set -e
set -x

BUILDROOT=$(cd $(dirname $1) && pwd)/$(basename $1)
TARBALL_OUTPUT=$(cd $(dirname {TARBALL_OUTPUT}) && pwd)/$(basename {TARBALL_OUTPUT})

echo "Target buildroot: $BUILDROOT"
echo "Source tarball: $TARBALL_OUTPUT"

# Create a temporary directory for staging
TEMP_STAGE=$(mktemp -d)
echo "Using temporary staging directory: $TEMP_STAGE"

{STAGE_DATA}

echo "Creating compressed source tarball..."
cd "$TEMP_STAGE"
tar -czf "$TARBALL_OUTPUT" .

echo "Extracting to buildroot..."
mkdir -p "$BUILDROOT"
cp -r * "$BUILDROOT/"

echo "Cleaning up temporary staging directory"
rm -rf "$TEMP_STAGE"

echo "Final buildroot contents:"
find "$BUILDROOT" -type f -exec file {} \;