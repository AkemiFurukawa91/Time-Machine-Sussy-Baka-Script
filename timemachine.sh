#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
if [[ $# -ne 1 || ! $1 =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
  echo "Usage: $0 DD-MM-YYYY"
  exit 1
fi
if [ -n "$TERMUX_VERSION" ]; then
    DOWNLOAD_DIR="/storage/emulated/0/Download"
elif grep -qEi 'microsoft|wsl' /proc/version 2>/dev/null; then
    WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
    DOWNLOAD_DIR="/mnt/c/Users/${WIN_USER}/Downloads"
else DOWNLOAD_DIR="$HOME/Downloads"
fi
echo "Using download directory: $DOWNLOAD_DIR"
INPUT_DATE="$1"
DD=${INPUT_DATE:0:2}
MM=${INPUT_DATE:3:2}
YYYY=${INPUT_DATE:6:4}
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT
finish_pdf() {
  local date8="$1"
  local outfile="${DOWNLOAD_DIR}/abp_epaper_${INPUT_DATE}.pdf"
  echo "Merging images → ${outfile}"
  mapfile -t imgs < <(cd "$TMPDIR" && ls *.png | sort -n)
  for i in "${!imgs[@]}"; do
    imgs[$i]="$TMPDIR/${imgs[$i]}"
  done
  magick "${imgs[@]}" -quality 90 "$outfile"
  echo "[✓] Download complete: ${outfile}"
  exit 0
}
PAGE1_N="https://epaper.anandabazar.com/calcutta-archive/15/${INPUT_DATE}/page-1.html"
HTML=$(curl -s "$PAGE1_N")
if echo "$HTML" | grep -q 'দুঃখিত'; then
  echo "No edition on path 15 for ${INPUT_DATE}, trying legacy..."
else
  SAMPLE_URL=$(echo "$HTML" \
    | grep -Po 'https://assets-abp\.ttef\.in/abplive/[0-9]{8}/webepaper/photos/[0-9]+\.png' \
    | head -n1 || true)
  if [[ -n "$SAMPLE_URL" ]]; then
    echo "Found new-format source: $SAMPLE_URL"
    EPAPER_DATE=$(echo "$SAMPLE_URL" \
      | sed -E 's|.*/abplive/([0-9]{8})/webepaper/photos/[0-9]+\.png|\1|')
    BASE_URL=$(echo "$SAMPLE_URL" \
      | sed -E "s|(https://assets-abp\.ttef\.in/abplive/)[0-9]{8}(/webepaper/photos/)[0-9]+\.png|\1${EPAPER_DATE}\2|")
    START_NUM=$(echo "$SAMPLE_URL" \
      | sed -E 's|.*/photos/([0-9]+)\.png|\1|')
    NUM=$START_NUM
    while :; do
      IMG_URL="${BASE_URL}${NUM}.png"
      OUTFILE="${TMPDIR}/${NUM}.png"
      echo "Fetching page #$((NUM - START_NUM + 1)): ${IMG_URL}"
      if ! curl -s -f "$IMG_URL" -o "$OUTFILE"; then
        echo "Reached end of pages at index ${NUM}. Stopping."
        break
      fi
      ((NUM++))
    done
    finish_pdf "$EPAPER_DATE"
  fi
fi
PAGE1_O="https://epaper.anandabazar.com/calcutta-archive/999/${INPUT_DATE}/page-1.html"
HTML=$(curl -s "$PAGE1_O")
if echo "$HTML" | grep -q 'দুঃখিত'; then
  echo "ERROR: No e-paper for ${INPUT_DATE} in legacy archive"
  exit 1
fi
SAMPLE_URL=$(echo "$HTML" \
  | grep -Po 'https://assets-abp-archives\.ttef\.in/abp/(?:abplive|abparchive)/[0-9]{8}/[^ ]+?-[0-9]ll\.(?:png|jpe?g)' \
  | head -n1 || true)
if [[ -z "$SAMPLE_URL" ]]; then
  echo "ERROR: Could not find any e-paper image URL on ${PAGE1_O}"
  exit 1
fi
EPAPER_DATE=$(echo "$SAMPLE_URL" | grep -oE '[0-9]{8}' | head -n1)
PREFIX=${SAMPLE_URL%-[0-9]ll.*}-
SUFFIX=${SAMPLE_URL#${PREFIX}}
PAGE=${SUFFIX:0:1}
SUFFIX=${SUFFIX:1}
while :; do
  url="${PREFIX}${PAGE}${SUFFIX}"
  out="${TMPDIR}/${PAGE}.png"
  echo "Downloading legacy page #${PAGE} → $url"
  if ! curl -sf "$url" -o "$out"; then
    echo "Reached end at page number ${PAGE}."
    break
  fi
  ((PAGE++))
done
finish_pdf "$EPAPER_DATE"
