# Save X (Twitter) videos via Shortcuts

A small `yt-dlp` wrapper so you can share a post from the **X** app and have the
video land in a folder on your computer. `save-x-video.sh` does the download;
the **Shortcuts** app is just the trigger.

## What it does

- Takes an `x.com` / `twitter.com` post URL (or the whole share-sheet blob — it
  pulls the first URL out).
- Normalizes mirror/mobile hosts (`vxtwitter`, `fxtwitter`, `mobile.twitter`)
  and strips tracking params.
- Downloads the best video as a single Photos-friendly `.mp4`.
- Prints the saved file's absolute path as its last line, so a Shortcut can grab
  it.

## One-time setup (on the computer that downloads)

This needs to run on a machine you can reach over SSH (a Mac, a home server, a
Raspberry Pi…). iPhones can't run shell scripts directly.

1. Install `yt-dlp` and `ffmpeg`:
   ```bash
   # macOS
   brew install yt-dlp ffmpeg
   # Debian/Ubuntu
   sudo apt install ffmpeg && pipx install yt-dlp
   ```
2. Copy `save-x-video.sh` onto that machine and make it executable:
   ```bash
   chmod +x save-x-video.sh
   ```
3. Test it from a terminal:
   ```bash
   ./save-x-video.sh "https://x.com/SomeUser/status/1234567890123456789"
   ```
   You should get a file in `~/Downloads/x-videos/` and the path printed at the
   end.

### Logging into X (required for most videos)

X now hides almost every video behind a login, and yt-dlp can no longer sign in
with a username/password. The fix is to reuse the cookies from a browser where
**you are already logged into x.com on the download machine**:

1. On the download machine, open a browser and log into <https://x.com>.
2. Tell the script which browser that is:
   ```bash
   export X_DL_BROWSER="chrome"   # or firefox, safari, edge, brave
   ```
   To target a specific profile, use yt-dlp's syntax, e.g.
   `export X_DL_BROWSER="chrome:Profile 1"` or `"firefox:work"`.
3. That's it — downloads now run as your logged-in session.

Notes per browser:
- **Chrome/Brave/Edge**: may need the browser **closed** so the cookie DB isn't
  locked. Firefox usually works while open.
- **Safari** (macOS): grant your terminal/SSH "Full Disk Access" in System
  Settings → Privacy & Security so it can read Safari's cookies.

If the script hits a login-gated post without cookies configured, it tells you
exactly this and exits — so a failed Shortcut run is self-explanatory.

#### Headless server (no browser)

Export a `cookies.txt` once (e.g. with the "Get cookies.txt LOCALLY" browser
extension while logged into x.com) and point the script at it:

```bash
export X_DL_COOKIES="$HOME/.config/x-cookies.txt"
```

Re-export when the session expires (X cookies are long-lived but not forever).

## The Shortcut (iPhone / iPad / Mac)

The cleanest path is **Run Script over SSH**.

1. Make sure the download machine has Remote Login / SSH enabled
   (macOS: System Settings → General → Sharing → Remote Login).
2. Open **Shortcuts → +** to create a new shortcut.
3. Add these actions in order:
   1. **Receive** — set it to accept *URLs* (and *Text*) from the **Share
      Sheet**. Turn on "Show in Share Sheet" in the shortcut settings.
   2. **Run Script over SSH** with:
      - **Host / Port / User**: your download machine.
      - **Authentication**: SSH key (recommended) or password.
      - **Input**: *Shortcut Input*.
      - **Script**:
        ```sh
        /absolute/path/to/save-x-video.sh "$(cat)"
        ```
        `"$(cat)"` feeds the shared URL (stdin) as the first argument.
   3. *(optional)* **Show Result** with the SSH action's output so you see where
      the file landed.
4. Rename the shortcut something like **Save X Video**.

### Using it

In the X app: tap **Share → Save X Video**. The shortcut sends the post URL over
SSH, the script downloads the video, and the path comes back as the result.

> Want the video back on your phone instead of just on the server? Have the
> script write into a synced folder (iCloud Drive / Dropbox / Syncthing), or
> extend the Shortcut to `scp`/fetch the returned path. Keep the wrapper's job
> to "download to a known folder"; do the moving in the Shortcut.

## Configuration reference

| Variable | Purpose | Default |
| --- | --- | --- |
| `X_DL_BROWSER` | Browser you're logged into x.com with (`chrome`, `firefox`, `safari`, …; supports `browser:profile`) | unset |
| `X_DL_OUTDIR` | Download directory | `~/Downloads/x-videos` |
| `X_DL_COOKIES` | Path to an exported `cookies.txt` (headless alternative) | unset |
| `X_DL_COOKIES_FROM` | Deprecated alias for `X_DL_BROWSER` | unset |
| `YT_DLP` | Path to the `yt-dlp` binary | `yt-dlp` on `PATH` |

> **Tip:** set `X_DL_BROWSER` in the same place the SSH session picks up
> environment (e.g. your shell profile), or pass it inline in the Shortcut's
> script line: `X_DL_BROWSER=chrome /path/to/save-x-video.sh "$(cat)"`.

You can also pass an output dir as the 2nd argument:
`save-x-video.sh <url> /path/to/dir`.

## Notes

- Only download content you have the rights to save, and respect X's Terms of
  Service.
- If a download suddenly breaks, update yt-dlp first (`yt-dlp -U` or
  `pipx upgrade yt-dlp`) — X changes its internals often.
