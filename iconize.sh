#!/usr/bin/env bash
#
# iconize.sh - Optimize and convert image files to ICO format.
#
# Copyright (C) 2026 Toni Homedes i Saun <toni@homedes.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

set -u
set -o pipefail

PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

VERSION="1.0.1"
VERBOSE=0
ICON_SIZE=256
FILES=()

# FSF Recommended --help output
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] <file1> [file2 ...]

Optimize and convert input images (SVG, PNG, etc.) to ICO format using
multiple compression strategies to produce the smallest possible output.

Options:
  -s, --size SIZE    Set target size in pixels (default: 256)
  -v, --verbose      Show detailed optimization steps
  -h, --help         Display this help message and exit
      --version      Output version information and exit

Report bugs to: <https://github.com/thomedes/iconize>

License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
    exit 0
}

# FSF Recommended --version output
show_version() {
    cat << EOF
iconize $VERSION

Copyright (C) 2026 Toni Homedes i Saun <toni@homedes.net>

License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -s|--size)
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                ICON_SIZE="$2"
                shift 2
            else
                echo "Error: -s|--size requires a numeric value." >&2
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            ;;
        --version)
            show_version
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "Error: No input files provided." >&2
    echo "Try '$0 --help' for more information." >&2
    exit 1
fi

log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "$@"
    fi
}

# Resolve ImageMagick binary
IM_CMD=""
if command -v magick &>/dev/null; then
    IM_CMD="magick"
elif command -v convert &>/dev/null; then
    IM_CMD="convert"
elif [ -x "/usr/bin/convert" ]; then
    IM_CMD="/usr/bin/convert"
elif [ -x "/usr/bin/magick" ]; then
    IM_CMD="/usr/bin/magick"
fi

# Dependency check
MISSING_DEPS=()
[ -z "$IM_CMD" ] && MISSING_DEPS+=("imagemagick (magick/convert)")
! command -v pngquant &>/dev/null && MISSING_DEPS+=("pngquant")

if [ "${#MISSING_DEPS[@]}" -ne 0 ]; then
    echo "Error: Missing core dependencies: ${MISSING_DEPS[*]}" >&2
    exit 1
fi

HAS_ICOTOOL=0
if command -v icotool &>/dev/null; then
    HAS_ICOTOOL=1
else
    log_verbose "Notice: 'icoutils' (icotool) not found. Skipping icotool method."
fi

# Process a single file
process_file() {
    local INPUT_IMG="$1"
    local OUTPUT_ICO="${INPUT_IMG%.*}.ico"

    if [ ! -f "$INPUT_IMG" ]; then
        printf "  %-8s %-32s %-12s %s\n" "[FAIL]" "$INPUT_IMG" "-" "File not found"
        return 1
    fi

    log_verbose "\n--- Optimization steps for: $INPUT_IMG ---"

    local TMPDIR_BASE="${TMPDIR:-${TMP:-/tmp}}"
    local WORK_DIR
    WORK_DIR=$(mktemp -d "$TMPDIR_BASE/ico_opt.XXXXXX")

    cleanup_local() {
        rm -rf "$WORK_DIR"
    }

    local RAW_PNG="$WORK_DIR/raw.png"
    local OPT_PNG="$WORK_DIR/opt.png"

    # Rasterize SVG or resize bitmap
    if [[ "$INPUT_IMG" =~ \.svg$ ]]; then
        if ! "$IM_CMD" -background none "$INPUT_IMG" -resize "${ICON_SIZE}x${ICON_SIZE}" "$RAW_PNG" 2>/dev/null; then
            printf "  %-8s %-32s %-12s %s\n" "[FAIL]" "$INPUT_IMG" "-" "ImageMagick rasterization error"
            cleanup_local
            return 1
        fi
    else
        if ! "$IM_CMD" "$INPUT_IMG" -resize "${ICON_SIZE}x${ICON_SIZE}" "$RAW_PNG" 2>/dev/null; then
            printf "  %-8s %-32s %-12s %s\n" "[FAIL]" "$INPUT_IMG" "-" "ImageMagick resize error"
            cleanup_local
            return 1
        fi
    fi

    # Optimize with pngquant (fallback silently to raw if failed or skipped)
    if ! pngquant --quality=65-80 --strip "$RAW_PNG" --output "$OPT_PNG" &>/dev/null; then
        cp "$RAW_PNG" "$OPT_PNG"
    fi

    declare -A CANDIDATES

    # Method 1: icotool
    if [ "$HAS_ICOTOOL" -eq 1 ]; then
        local ICO_1="$WORK_DIR/cand1_icotool.ico"
        if icotool -c -o "$ICO_1" "$OPT_PNG" &>/dev/null; then
            if [ -f "$ICO_1" ]; then
                local SIZE_1
                SIZE_1=$(stat -c%s "$ICO_1")
                CANDIDATES["icotool"]="$ICO_1"
                log_verbose "Method 'icotool':\t\t${SIZE_1} bytes"
            fi
        fi
    fi

    # Method 2: ImageMagick PNG-in-ICO
    local ICO_2="$WORK_DIR/cand2_im_png.ico"
    if "$IM_CMD" "$OPT_PNG" -define icon:auto-resize="$ICON_SIZE" "ico:$ICO_2" &>/dev/null; then
        if [ -f "$ICO_2" ]; then
            local SIZE_2
            SIZE_2=$(stat -c%s "$ICO_2")
            CANDIDATES["im_png"]="$ICO_2"
            log_verbose "Method 'im_png':\t\t${SIZE_2} bytes"
        fi
    fi

    # Method 3: ImageMagick Indexed Palette (BMP3)
    local ICO_3="$WORK_DIR/cand3_im_bmp3.ico"
    if "$IM_CMD" "$OPT_PNG" -colors 256 "BMP3:$ICO_3" &>/dev/null; then
        if [ -f "$ICO_3" ]; then
            local SIZE_3
            SIZE_3=$(stat -c%s "$ICO_3")
            CANDIDATES["im_bmp3"]="$ICO_3"
            log_verbose "Method 'im_bmp3':\t\t${SIZE_3} bytes"
        fi
    fi

    # Method 4: ImageMagick Compressed Zip
    local ICO_4="$WORK_DIR/cand4_im_zip.ico"
    if "$IM_CMD" "$OPT_PNG" -compress Zip "ico:$ICO_4" &>/dev/null; then
        if [ -f "$ICO_4" ]; then
            local SIZE_4
            SIZE_4=$(stat -c%s "$ICO_4")
            CANDIDATES["im_zip"]="$ICO_4"
            log_verbose "Method 'im_zip':\t\t${SIZE_4} bytes"
        fi
    fi

    # Select candidate with minimum size
    local BEST_FILE=""
    local BEST_SIZE=999999999
    local BEST_METHOD=""

    for METHOD in "${!CANDIDATES[@]}"; do
        local CAND_FILE="${CANDIDATES[$METHOD]}"
        local CAND_SIZE
        CAND_SIZE=$(stat -c%s "$CAND_FILE")
        if [ "$CAND_SIZE" -lt "$BEST_SIZE" ]; then
            BEST_SIZE="$CAND_SIZE"
            BEST_FILE="$CAND_FILE"
            BEST_METHOD="$METHOD"
        fi
    done

    if [ -z "$BEST_FILE" ]; then
        printf "  %-8s %-32s %-12s %s\n" "[FAIL]" "$INPUT_IMG" "-" "No valid candidate generated"
        cleanup_local
        return 1
    fi

    cp "$BEST_FILE" "$OUTPUT_ICO"
    log_verbose "Selected method: ${BEST_METHOD} (${BEST_SIZE} bytes)"

    local HUMAN_SIZE
    HUMAN_SIZE=$(numfmt --to=iec-i --suffix=B "$BEST_SIZE" 2>/dev/null || echo "${BEST_SIZE} B")
    printf "  %-8s %-32s %-12s (%s)\n" "[OK]" "$OUTPUT_ICO" "$HUMAN_SIZE" "$BEST_METHOD"

    cleanup_local
    return 0
}

# Header output
echo ""
echo "  Target resolution : ${ICON_SIZE}x${ICON_SIZE} px"
echo "  Batch processing  : ${#FILES[@]} file(s)"
echo ""
printf "  %-8s %-32s %-12s %s\n" "STATUS" "OUTPUT FILE" "SIZE" "METHOD"
printf "  %-8s %-32s %-12s %s\n" "------" "-----------" "----" "------"

# Main execution loop
SUCCESS_COUNT=0
FAIL_COUNT=0

for FILE in "${FILES[@]}"; do
    if process_file "$FILE"; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
done

# Footer output
echo ""
echo "  Finished: $SUCCESS_COUNT succeeded, $FAIL_COUNT failed."
echo ""
