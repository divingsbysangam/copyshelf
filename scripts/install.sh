#!/bin/bash
# Owner-run only: installs the already-built Release app, retaining a rollback copy.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DEST="/Applications/CopyShelf.app"
APP_SOURCE="$PROJECT_DIR/build/DerivedData/Build/Products/Release/CopyShelf.app"
SIGN_IDENTITY="CopyShelf Self-Signed"
BACKUP_DIR="$PROJECT_DIR/build/rollback"
BACKUP_APP="$BACKUP_DIR/CopyShelf-previous.app"

if [ ! -d "$APP_SOURCE" ]; then
    echo "Build and inspect the Release app first: ./scripts/build.sh Release" >&2; exit 1
fi

verify_signature() {
    local app_path="$1" signature requirement
    codesign --verify --deep --strict "$app_path"
    signature="$(codesign -dv --verbose=4 "$app_path" 2>&1 || true)"
    requirement="$(codesign -d -r- "$app_path" 2>&1)"
    printf '%s\n' "$signature" | grep -E '^(Authority|Signature|Identifier)=' || true
    if ! printf '%s\n' "$signature" | grep -qxF 'Identifier=com.sangam.copyshelf'; then
        echo "Unexpected app identifier; aborting install/launch." >&2; return 1
    fi
    if printf '%s\n' "$signature" | grep -qxF 'Signature=adhoc'; then
        if [ "${ALLOW_ADHOC_SIGN:-}" = "1" ]; then
            echo "WARNING: explicitly requested ad-hoc install; privacy grants may not persist." >&2
            return 0
        fi
        echo "Refusing ad-hoc install/launch without ALLOW_ADHOC_SIGN=1." >&2; return 1
    fi
    if ! printf '%s\n' "$signature" | grep -qxF "Authority=$SIGN_IDENTITY" || \
       ! printf '%s\n' "$requirement" | grep -qE 'certificate (root|leaf) = H"'; then
        echo "Expected stable '$SIGN_IDENTITY' authority and certificate requirement." >&2; return 1
    fi
}

# Validate the product before touching an installed copy.
verify_signature "$APP_SOURCE"
if [ -L "$APP_DEST" ]; then
    echo "Refusing to replace a symlink at $APP_DEST." >&2; exit 1
fi
if [ -e "$APP_DEST" ]; then
    verify_signature "$APP_DEST"
    source_requirement="$(codesign -d -r- "$APP_SOURCE" 2>&1 | sed -n 's/^designated => //p')"
    installed_requirement="$(codesign -d -r- "$APP_DEST" 2>&1 | sed -n 's/^designated => //p')"
    if [ -z "$source_requirement" ] || [ "$source_requirement" != "$installed_requirement" ]; then
        echo "Installed and prepared app requirements differ; refusing replacement." >&2; exit 1
    fi
    if [ -e "$BACKUP_APP" ]; then
        if [ "${KEEP_EXISTING_ROLLBACK:-0}" != "1" ]; then
            echo "Rollback copy already exists at $BACKUP_APP; preserve or move it before installing." >&2; exit 1
        fi
        verify_signature "$BACKUP_APP"
        backup_requirement="$(codesign -d -r- "$BACKUP_APP" 2>&1 | sed -n 's/^designated => //p')"
        if [ "$backup_requirement" != "$source_requirement" ]; then
            echo "Rollback copy has a different signing requirement; refusing replacement." >&2; exit 1
        fi
        echo "Keeping existing rollback copy at $BACKUP_APP"
    else
        mkdir -p "$BACKUP_DIR"
        ditto "$APP_DEST" "$BACKUP_APP"
        verify_signature "$BACKUP_APP"
        echo "Previous installed app backed up to $BACKUP_APP"
    fi
fi
for process_id in $(pgrep -f '^/Applications/CopyShelf.app/Contents/MacOS/CopyShelf' || true); do kill "$process_id"; done
for attempt in 1 2 3 4 5; do
    if ! pgrep -f '^/Applications/CopyShelf.app/Contents/MacOS/CopyShelf' >/dev/null; then break; fi
    sleep 1
done
if pgrep -f '^/Applications/CopyShelf.app/Contents/MacOS/CopyShelf' >/dev/null; then
    echo "CopyShelf is still running; quit it and retry." >&2; exit 1
fi
rm -rf "$APP_DEST"
if ! ditto "$APP_SOURCE" "$APP_DEST"; then
    echo "Install copy failed. Restore the rollback copy from $BACKUP_APP if available." >&2
    exit 1
fi
xattr -dr com.apple.quarantine "$APP_DEST"
verify_signature "$APP_DEST"
open "$APP_DEST"
echo "Installed and launched $APP_DEST. Finish with capture paused."
echo "Grant Accessibility once to this installed copy in System Settings > Privacy & Security > Accessibility."
echo "Do not grant a build-folder copy or run tccutil reset."
echo "Verify later rebuilds retain the grant; stable signing alone is a proxy for that check."
