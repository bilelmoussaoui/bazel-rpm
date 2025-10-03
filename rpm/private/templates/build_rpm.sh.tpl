#!/bin/bash
set -e
set -x

SPEC_FILE="{SPEC_FILE}"
SOURCE_BUILDROOT="$(pwd)/{BUILDROOT_PATH}"
RPM_OUTPUT="{RPM_OUTPUT}"

echo "Building RPM with isolated /tmp buildroot:"
echo "  Spec file: $SPEC_FILE"
echo "  Source buildroot: $SOURCE_BUILDROOT"
echo "  Output: $RPM_OUTPUT"

# Create isolated directories in /tmp
WORK_DIR=$(mktemp -d -t rpm_build_XXXXXX)
ISOLATED_BUILDROOT=$WORK_DIR/buildroot
echo "  Work directory: $WORK_DIR"
echo "  Isolated buildroot: $ISOLATED_BUILDROOT"

mkdir -p "$WORK_DIR/rpmbuild/BUILD"
mkdir -p "$WORK_DIR/rpmbuild/RPMS"
mkdir -p "$WORK_DIR/rpmbuild/SOURCES"
mkdir -p "$WORK_DIR/rpmbuild/SPECS"
mkdir -p "$WORK_DIR/rpmbuild/SRPMS"
export HOME="$WORK_DIR"

# Copy our buildroot content to isolated location
echo "Copying buildroot content to isolated location..."
mkdir -p "$ISOLATED_BUILDROOT"
if [ -d "$SOURCE_BUILDROOT" ] && [ "$(ls -A "$SOURCE_BUILDROOT" 2>/dev/null)" ]; then
    echo "Copying buildroot with symlink dereferencing..."
    cp -rL "$SOURCE_BUILDROOT"/* "$ISOLATED_BUILDROOT/"
else
    echo "Warning: Source buildroot is empty or doesn't exist"
fi

# Copy spec file
cp "$SPEC_FILE" "$WORK_DIR/rpmbuild/SPECS/"

echo "Contents of isolated buildroot:"
find "$ISOLATED_BUILDROOT" -type f -exec file {} \;

echo "Building RPM package..."
rpmbuild \
  --define "_topdir $WORK_DIR/rpmbuild" \
  --define "_tmppath $WORK_DIR/tmp" \
  --define "_builddir $WORK_DIR/rpmbuild/BUILD" \
  --buildroot "$ISOLATED_BUILDROOT" \
  -bb \
  "$WORK_DIR/rpmbuild/SPECS/{SPEC_BASENAME}"

echo "RPM build completed. Looking for generated RPM files:"
find "$WORK_DIR/rpmbuild/RPMS" -name '*.rpm' -ls

# Copy the resulting RPM
RPM_FOUND=$(find "$WORK_DIR/rpmbuild/RPMS" -name '*.rpm' | head -1)
if [ -n "$RPM_FOUND" ]; then
    echo "Copying $RPM_FOUND to $RPM_OUTPUT"
    cp "$RPM_FOUND" "$RPM_OUTPUT"
else
    echo "ERROR: No RPM file found!"
    exit 1
fi

# Cleanup
rm -rf "$WORK_DIR"

echo "RPM build successful: $RPM_OUTPUT"