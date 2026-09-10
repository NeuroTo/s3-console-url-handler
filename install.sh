#!/usr/bin/env bash

# BASH_SOURCE has no element when this script is piped directly into Bash.
set -eo pipefail
SCRIPT_FILE="${BASH_SOURCE[0]-}"
set -u

APP_ID="s3-console-handler.desktop"
DEFAULT_REGION="eu-west-1"
RAW_BASE_URL="${S3_CONSOLE_RAW_BASE_URL:-https://raw.githubusercontent.com/NeuroTo/s3-console-url-handler/main}"
SCRIPT_DIR=""
DOWNLOAD_DIR=""
if [[ -n "$SCRIPT_FILE" && -f "$SCRIPT_FILE" ]]; then
    SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$SCRIPT_FILE")" && pwd)"
fi
SOURCE_HANDLER="${SCRIPT_DIR:+$SCRIPT_DIR/}s3-console"
SOURCE_EXTENSION="${SCRIPT_DIR:+$SCRIPT_DIR/}chromium-extension"
BIN_DIR="${HOME:?HOME is not set}/.local/bin"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLICATIONS_DIR="$DATA_HOME/applications"
EXTENSION_DIR="$DATA_HOME/s3-console/chromium-extension"
HANDLER_PATH="$BIN_DIR/s3-console"
DESKTOP_PATH="$APPLICATIONS_DIR/$APP_ID"

usage() {
    cat <<EOF
Usage:
  ./install.sh install [--region REGION]
  ./install.sh uninstall

Installs or removes the Firefox handler and Chromium extension files.
The default region is $DEFAULT_REGION.
EOF
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Error: required command not found: %s\n' "$1" >&2
        exit 1
    fi
}

desktop_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

cleanup_downloads() {
    if [[ -z "$DOWNLOAD_DIR" ]]; then
        return
    fi

    rm -f \
        "$DOWNLOAD_DIR/s3-console" \
        "$DOWNLOAD_DIR/chromium-extension/manifest.json" \
        "$DOWNLOAD_DIR/chromium-extension/background.js"
    rmdir "$DOWNLOAD_DIR/chromium-extension" 2>/dev/null || true
    rmdir "$DOWNLOAD_DIR" 2>/dev/null || true
}

prepare_sources() {
    if [[ -n "$SCRIPT_DIR" ]]; then
        if [[ ! -f "$SOURCE_HANDLER" ]]; then
            printf 'Error: application file not found: %s\n' "$SOURCE_HANDLER" >&2
            exit 1
        fi
        if [[ ! -f "$SOURCE_EXTENSION/manifest.json" \
            || ! -f "$SOURCE_EXTENSION/background.js" ]]; then
            printf 'Error: Chromium extension files are incomplete\n' >&2
            exit 1
        fi
        return
    fi

    require_command curl
    require_command mktemp
    DOWNLOAD_DIR="$(mktemp -d)"
    SOURCE_HANDLER="$DOWNLOAD_DIR/s3-console"
    SOURCE_EXTENSION="$DOWNLOAD_DIR/chromium-extension"
    mkdir -p "$SOURCE_EXTENSION"
    trap cleanup_downloads EXIT

    curl --fail --location --silent --show-error \
        "$RAW_BASE_URL/s3-console" \
        --output "$SOURCE_HANDLER"
    curl --fail --location --silent --show-error \
        "$RAW_BASE_URL/chromium-extension/manifest.json" \
        --output "$SOURCE_EXTENSION/manifest.json"
    curl --fail --location --silent --show-error \
        "$RAW_BASE_URL/chromium-extension/background.js" \
        --output "$SOURCE_EXTENSION/background.js"
}

install_handler() {
    local region="$DEFAULT_REGION"

    while (($#)); do
        case "$1" in
            --region)
                if (($# < 2)); then
                    printf 'Error: --region requires a value\n' >&2
                    exit 2
                fi
                region="$2"
                shift 2
                ;;
            *)
                printf 'Error: unknown install option: %s\n' "$1" >&2
                usage >&2
                exit 2
                ;;
        esac
    done

    if [[ ! "$region" =~ ^[a-z0-9-]+$ ]]; then
        printf 'Error: invalid AWS region: %s\n' "$region" >&2
        exit 2
    fi

    require_command python3
    require_command xdg-mime
    require_command xdg-open
    prepare_sources

    mkdir -p "$BIN_DIR" "$APPLICATIONS_DIR" "$EXTENSION_DIR"
    install -m 0755 "$SOURCE_HANDLER" "$HANDLER_PATH"
    install -m 0644 "$SOURCE_EXTENSION/manifest.json" "$EXTENSION_DIR/manifest.json"
    install -m 0644 "$SOURCE_EXTENSION/background.js" "$EXTENSION_DIR/background.js"
    printf 'globalThis.S3_CONSOLE_REGION = "%s";\n' "$region" \
        >"$EXTENSION_DIR/config.js"

    local escaped_handler
    escaped_handler="$(desktop_escape "$HANDLER_PATH")"
    cat >"$DESKTOP_PATH" <<EOF
[Desktop Entry]
Type=Application
Name=S3 AWS Console
Comment=Open s3:// URIs in the AWS S3 web console
NoDisplay=true
Terminal=false
Exec=/usr/bin/env S3_CONSOLE_REGION=$region "$escaped_handler" %u
MimeType=x-scheme-handler/s3;
EOF

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPLICATIONS_DIR"
    fi
    xdg-mime default "$APP_ID" x-scheme-handler/s3

    printf 'Installed s3:// handler for region %s.\n' "$region"
    printf 'Test it with: s3://example-bucket/example/path/\n'
    printf '\nChromium requires one manual step:\n'
    printf '  1. Open chrome://extensions and enable Developer mode.\n'
    printf '  2. Choose "Load unpacked" and select:\n     %s\n' "$EXTENSION_DIR"
    printf 'Then enter: s3 s3://example-bucket/example/path/\n'
}

remove_mime_associations() {
    python3 - "$APP_ID" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list" \
        "$APPLICATIONS_DIR/mimeapps.list" <<'PY'
from pathlib import Path
import sys

app_id = sys.argv[1]
mime_type = "x-scheme-handler/s3"

for filename in sys.argv[2:]:
    path = Path(filename)
    if not path.is_file():
        continue

    changed = False
    output = []
    for line in path.read_text(encoding="utf-8").splitlines(keepends=True):
        stripped = line.strip()
        if "=" not in stripped:
            output.append(line)
            continue

        key, value = stripped.split("=", 1)
        if key.strip() != mime_type:
            output.append(line)
            continue

        handlers = [item for item in value.split(";") if item and item != app_id]
        if app_id not in [item for item in value.split(";") if item]:
            output.append(line)
            continue

        changed = True
        if handlers:
            newline = "\n" if line.endswith("\n") else ""
            output.append(f"{mime_type}={';'.join(handlers)};{newline}")

    if changed:
        path.write_text("".join(output), encoding="utf-8")
PY
}

uninstall_handler() {
    require_command python3

    remove_mime_associations
    rm -f "$DESKTOP_PATH" "$HANDLER_PATH"
    rm -f \
        "$EXTENSION_DIR/manifest.json" \
        "$EXTENSION_DIR/background.js" \
        "$EXTENSION_DIR/config.js"
    rmdir "$EXTENSION_DIR" 2>/dev/null || true
    rmdir "$(dirname "$EXTENSION_DIR")" 2>/dev/null || true

    if command -v update-desktop-database >/dev/null 2>&1 \
        && [[ -d "$APPLICATIONS_DIR" ]]; then
        update-desktop-database "$APPLICATIONS_DIR"
    fi

    printf 'Uninstalled the s3:// handler.\n'
    printf 'If Chromium still lists the extension, remove it at chrome://extensions.\n'
}

command="${1:-install}"
if (($#)); then
    shift
fi

case "$command" in
    install)
        install_handler "$@"
        ;;
    uninstall)
        if (($#)); then
            printf 'Error: uninstall does not accept options\n' >&2
            exit 2
        fi
        uninstall_handler
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        printf 'Error: unknown command: %s\n' "$command" >&2
        usage >&2
        exit 2
        ;;
esac
