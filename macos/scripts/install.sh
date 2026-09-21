#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
install_root="${AUTO_CLICK_INSTALL_DIR:-/Applications}"
source_app="$project_dir/dist/Auto Click.app"
destination_app="$install_root/Auto Click.app"
should_build=1
should_launch=1

usage() {
    printf '%s\n' "Usage: ./scripts/install.sh [--no-build] [--no-launch]"
    printf '%s\n' ""
    printf '%s\n' "Options:"
    printf '%s\n' "  --no-build   Install the bundle already in dist/"
    printf '%s\n' "  --no-launch  Do not open Auto Click after installing"
    printf '%s\n' "  -h, --help   Show this help"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-build)
            should_build=0
            ;;
        --no-launch)
            should_launch=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '%s\n' "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [ "$should_build" -eq 1 ]; then
    "$project_dir/scripts/build-app.sh" release
elif [ ! -d "$source_app" ]; then
    printf '%s\n' "Not found: ${source_app}" >&2
    printf '%s\n' "Run again without --no-build to create the bundle first." >&2
    exit 1
fi

if pgrep -f "$destination_app/Contents/MacOS/AutoClick" >/dev/null 2>&1; then
    printf '%s\n' "Closing Auto Click…"
    osascript -e 'tell application id "com.local.AutoClick" to quit' >/dev/null 2>&1 || true

    attempts=0
    while [ "$attempts" -lt 20 ]; do
        if ! pgrep -f "$destination_app/Contents/MacOS/AutoClick" >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
        attempts=$((attempts + 1))
    done
fi

if [ ! -d "$install_root" ]; then
    mkdir -p "$install_root"
fi

printf '%s\n' "Installing into ${destination_app}…"
if [ -w "$install_root" ]; then
    ditto "$source_app" "$destination_app"
else
    printf '%s\n' "Administrator rights are needed to write to ${install_root}."
    sudo ditto "$source_app" "$destination_app"
fi

codesign --verify --deep --strict "$destination_app"

if [ "$should_launch" -eq 1 ]; then
    open "$destination_app"
fi

printf '%s\n' "Auto Click installed successfully."
printf '%s\n' "If the app does not click after an update, toggle Auto Click off and on in Privacy & Security → Accessibility."
