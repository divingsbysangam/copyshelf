#!/bin/bash
# Build locally; never install, launch, or mutate keychain/permission state.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIGURATION="${1:-Debug}"
SIGN_IDENTITY="CopyShelf Self-Signed"
case "$CONFIGURATION" in Debug|Release) ;; *) echo "Usage: $0 [Debug|Release]" >&2; exit 2 ;; esac
if [ "$#" -gt 1 ]; then echo "Usage: $0 [Debug|Release]" >&2; exit 2; fi
cd "$PROJECT_DIR"

# Match the exact name and resolve to the fingerprint, avoiding substring matches
# or an ambiguous name selecting an unrelated application's identity.
IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null)"
MATCHES="$(printf '%s\n' "$IDENTITIES" | awk -F '"' -v name="$SIGN_IDENTITY" '$2 == name {split($1, parts, " "); print parts[2]}')"
IDENTITY_COUNT="$(printf '%s\n' "$MATCHES" | awk 'NF {n++} END {print n+0}')"
if [ "$IDENTITY_COUNT" -gt 1 ]; then
    echo "Multiple '$SIGN_IDENTITY' identities found; resolve the duplicate identities." >&2
    exit 1
elif [ "$IDENTITY_COUNT" -eq 1 ]; then
    CODESIGN_ID="$MATCHES"
elif [ "${ALLOW_ADHOC_SIGN:-}" = "1" ]; then
    CODESIGN_ID="-"
    echo "WARNING: ALLOW_ADHOC_SIGN=1; ad-hoc fixture build. Privacy grants may not persist across rebuilds." >&2
else
    echo "Stable identity '$SIGN_IDENTITY' not found. Refusing ad-hoc signing." >&2
    echo "Run ./scripts/create-signing-cert.sh once, then ./scripts/build.sh." >&2
    echo "Fixture-only override: ALLOW_ADHOC_SIGN=1 ./scripts/build.sh" >&2
    exit 1
fi

if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
else
    echo "WARNING: XcodeGen unavailable; using committed CopyShelf.xcodeproj." >&2
fi
mkdir -p build
BUILD_LOG="$PROJECT_DIR/build/build-$CONFIGURATION.log"
if ! xcodebuild -project CopyShelf.xcodeproj -scheme CopyShelf \
        -configuration "$CONFIGURATION" -derivedDataPath "$PROJECT_DIR/build/DerivedData" \
        build >"$BUILD_LOG" 2>&1; then
    tail -60 "$BUILD_LOG" >&2
    echo "Build failed. Full log: $BUILD_LOG" >&2
    exit 1
fi
grep -E '(warning:|BUILD SUCCEEDED)' "$BUILD_LOG" || true
APP_PATH="$PROJECT_DIR/build/DerivedData/Build/Products/$CONFIGURATION/CopyShelf.app"

# A self-signed identity has no Team ID for library validation. The app must have
# one Mach-O, with the core statically linked and debug dylib splitting disabled.
NESTED_CODE="$(find "$APP_PATH/Contents" \( -name '*.dylib' -o -name '*.framework' -o -name '*.xpc' \) -print)"
if [ -n "$NESTED_CODE" ]; then
    echo "Unexpected nested code: $NESTED_CODE. Check static linking / ENABLE_DEBUG_DYLIB=NO." >&2
    exit 1
fi
codesign --force --deep --options runtime --timestamp=none --sign "$CODESIGN_ID" "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
REQUIREMENT="$(codesign -d -r- "$APP_PATH" 2>&1)"
printf '%s\n' "$REQUIREMENT"
SIGNATURE="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
if ! printf '%s\n' "$SIGNATURE" | grep -qxF 'Identifier=com.sangam.copyshelf'; then
    echo "Unexpected signing identifier." >&2; exit 1
fi
if [ "$CODESIGN_ID" != "-" ]; then
    if ! printf '%s\n' "$REQUIREMENT" | grep -qF 'identifier "com.sangam.copyshelf"'; then
        echo "Unexpected identifier in stable designated requirement." >&2; exit 1
    fi
    if ! printf '%s\n' "$REQUIREMENT" | grep -qE 'certificate (root|leaf) = H"'; then
        echo "Designated requirement does not anchor the stable certificate." >&2; exit 1
    fi
    # Display can return nonzero for self-signed identities; verification above
    # is authoritative. Do not hide codesign verification failures here.
    if ! printf '%s\n' "$SIGNATURE" | grep -qxF "Authority=$SIGN_IDENTITY"; then
        echo "Unexpected signing authority." >&2; exit 1
    fi
fi
echo "Artifact: $APP_PATH"
