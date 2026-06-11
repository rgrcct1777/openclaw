#!/usr/bin/env bash
#
# save-x-video.sh — download a video from an x.com / twitter.com post.
#
# Designed to be driven from the iOS/macOS Shortcuts app via the
# "Run Script over SSH" action, but works fine as a plain CLI tool too.
#
# Usage:
#   ./save-x-video.sh <x.com-or-twitter.com URL> [output-dir]
#
# On success it prints (last line) the absolute path of the saved file,
# so a Shortcut can capture it from the SSH output.
#
# Environment overrides:
#   X_DL_OUTDIR        Default output directory (default: ~/Downloads/x-videos)
#   X_DL_COOKIES       Path to a Netscape cookies.txt for protected/age-gated posts
#   X_DL_COOKIES_FROM  Browser name for yt-dlp --cookies-from-browser (e.g. safari, chrome)
#   YT_DLP            Path to the yt-dlp binary (default: looked up on PATH)
#
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }

# --- locate yt-dlp -----------------------------------------------------------
YT_DLP_BIN="${YT_DLP:-yt-dlp}"
if ! command -v "$YT_DLP_BIN" >/dev/null 2>&1; then
  die "yt-dlp not found. Install it: 'brew install yt-dlp' (macOS) or 'pipx install yt-dlp'."
fi

# --- parse args --------------------------------------------------------------
RAW_URL="${1:-}"
[ -n "$RAW_URL" ] || die "no URL given. Usage: $(basename "$0") <x.com URL> [output-dir]"

OUTDIR="${2:-${X_DL_OUTDIR:-$HOME/Downloads/x-videos}}"

# Shortcuts often hands over the whole share sheet text; pull the first URL out.
URL="$(printf '%s' "$RAW_URL" | grep -oE 'https?://[^[:space:]]+' | head -n1 || true)"
[ -n "$URL" ] || URL="$RAW_URL"

# Normalize the mobile/short hosts to x.com so yt-dlp's twitter extractor matches.
case "$URL" in
  *x.com/*|*twitter.com/*|*mobile.twitter.com/*|*vxtwitter.com/*|*fxtwitter.com/*) ;;
  *) die "not an x.com/twitter.com URL: $URL" ;;
esac
URL="${URL//vxtwitter.com/x.com}"
URL="${URL//fxtwitter.com/x.com}"
URL="${URL//mobile.twitter.com/x.com}"

# Strip tracking query params (?s=, ?t=, etc.) — keep things tidy for filenames.
URL="${URL%%\?*}"

mkdir -p "$OUTDIR"

log "downloading: $URL"
log "into:        $OUTDIR"

# --- build yt-dlp args -------------------------------------------------------
args=(
  --no-playlist
  --no-progress
  --restrict-filenames
  --merge-output-format mp4
  # Prefer a single mp4 the Photos app can ingest; fall back to best.
  -f "bv*+ba/b"
  -o "$OUTDIR/%(uploader_id)s-%(id)s.%(ext)s"
  --print after_move:filepath
)

if [ -n "${X_DL_COOKIES:-}" ]; then
  [ -f "$X_DL_COOKIES" ] || die "X_DL_COOKIES set but file missing: $X_DL_COOKIES"
  args+=(--cookies "$X_DL_COOKIES")
elif [ -n "${X_DL_COOKIES_FROM:-}" ]; then
  args+=(--cookies-from-browser "$X_DL_COOKIES_FROM")
fi

# --- run ---------------------------------------------------------------------
# --print after_move:filepath emits the final path on stdout; capture it.
saved_path="$("$YT_DLP_BIN" "${args[@]}" "$URL")" || die "yt-dlp failed for: $URL"

[ -n "$saved_path" ] && [ -f "$saved_path" ] || die "download reported success but no file found"

log "saved ok"
# Last stdout line = absolute path, for the Shortcut to pick up.
printf '%s\n' "$saved_path"
