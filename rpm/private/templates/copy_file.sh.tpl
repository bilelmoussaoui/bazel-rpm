echo "Staging {FILE_TYPE}: {SOURCE_PATH} -> $TEMP_STAGE{TARGET_DIR}/{BASENAME}"
# Copy actual file content, following symlinks
if [ -L "{SOURCE_PATH}" ]; then
    REAL_FILE=$(readlink -f "{SOURCE_PATH}")
    echo "Dereferencing symlink: $REAL_FILE"
    cp "$REAL_FILE" "$TEMP_STAGE{TARGET_DIR}/{BASENAME}"
else
    cp "{SOURCE_PATH}" "$TEMP_STAGE{TARGET_DIR}/{BASENAME}"
fi