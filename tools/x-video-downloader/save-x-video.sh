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
# X no longer lets yt-dlp log in with a username/password, so almost every
# video now needs the cookies from a browser where you are already signed into
# x.com. Point the script at that browser once and it "just works" after login:
#
#   X_DL_BROWSER       Browser you're logged into x.com with, for yt-dlp
#                      --cookies-from-browser. Accepts yt-dlp's full syntax:
#                      "chrome", "firefox", "safari", "edge", "brave",
#                      or "chrome:Profile 1" / "firefox:work" to pick a profile.
#
# Environment overrides:
#   X_DL_OUTDIR        Default output directory (default: ~/Downloads/x-videos)
#   X_DL_COOKIES       Path to an exported Netscape cookies.txt (alternative to
#                      X_DL_BROWSER, e.g. for headless servers with no browser)
#   X_DL_COOKIES_FROM  Deprecated alias for X_DL_BROWSER
#   YT_DLP             Path to the yt-dlp binary (default: looked up on PATH)
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

# Cookies make logged-in posts work. Prefer an exported file, else the live
# browser session; X_DL_COOKIES_FROM stays as a deprecated alias for X_DL_BROWSER.
browser_cookies="${X_DL_BROWSER:-${X_DL_COOKIES_FROM:-}}"
have_auth=0
if [ -n "${X_DL_COOKIES:-}" ]; then
  [ -f "$X_DL_COOKIES" ] || die "X_DL_COOKIES set but file missing: $X_DL_COOKIES"
  args+=(--cookies "$X_DL_COOKIES")
  have_auth=1
elif [ -n "$browser_cookies" ]; then
  args+=(--cookies-from-browser "$browser_cookies")
  have_auth=1
fi

# --- run ---------------------------------------------------------------------
# Capture stderr so an auth failure gets a precise, actionable message instead
# of yt-dlp's generic error. --print after_move:filepath emits the path on stdout.
err_log="$(mktemp -t save-x-video.XXXXXX)"
trap 'rm -f "$err_log"' EXIT

if ! saved_path="$("$YT_DLP_BIN" "${args[@]}" "$URL" 2>"$err_log")"; then
  # X gates most videos behind login; surface that as the likely cause.
  if grep -qiE 'NSFW|log in|sign in|authenticat|401|403|not authorized|age.?restrict' "$err_log"; then
    log "--- yt-dlp output ---"; cat "$err_log" >&2; log "---------------------"
    if [ "$have_auth" -eq 0 ]; then
      die "this post needs you to be logged into X. Log into x.com in a browser on this machine, then re-run with X_DL_BROWSER=chrome (or firefox/safari/edge/brave)."
    fi
    die "logged-in download still failed. Confirm you're signed into x.com in the X_DL_BROWSER browser and that its cookies aren't locked (close the browser, or export X_DL_COOKIES instead)."
  fi
  cat "$err_log" >&2
  die "yt-dlp failed for: $URL"
fi

[ -n "$saved_path" ] && [ -f "$saved_path" ] || die "download reported success but no file found"

log "saved ok"
# Last stdout line = absolute path, for the Shortcut to pick up.
printf '%s\n' "$saved_path"
