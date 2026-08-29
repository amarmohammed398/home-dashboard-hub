# Changelog & Feature Baseline

This file is the source of truth for what this project currently does.
It exists so that every future change has something concrete to check
against:

**Workflow going forward:**
1. Before making a change, check the **Current baseline** below for
   anything the new change might touch or could break.
2. Make the change, and verify it in the local preview (not just by
   reading the code) — same standard as everything built so far.
3. Re-check the baseline items that overlap with the change still hold.
4. Update this file: add a dated entry under **Change log**, and update
   **Current baseline** if the change altered or replaced existing
   behaviour (don't just append — if something was removed or changed,
   the baseline entry should reflect what's *actually true now*, the
   same way git commits here have documented replacing, not just
   adding, earlier decisions).
5. If the change alters the *system-level* story — a new architectural
   piece, a data flow change, a new deployment target, a non-obvious
   problem solved — also update [ARCHITECTURE.md](ARCHITECTURE.md).
   Not every change needs this (a colour tweak doesn't); a new
   engineering decision or a bug worth explaining does.
6. Commit with a descriptive message. Commit each logical change
   separately rather than batching unrelated things together.
7. Push to whichever remotes are relevant (`home` for the live display,
   `origin` for GitHub) once a change is confirmed working.

If a requested change conflicts with something in the baseline (e.g.
"remove the nightly reload" vs. an earlier "reload nightly to pick up
new code" decision), that's worth surfacing rather than silently
overriding — the baseline exists precisely to catch that kind of thing.

---

## Current baseline (as of 2026-08-28)

### Data & prayer times
- Live-fetches today's prayer times client-side from
  `https://cheadlemasjid.org/wp-json/dpt/v1/prayertime?filter=today`
  every 5 minutes (`REFRESH_MS`). No prayer times are ever hand-entered.
- Table shows, in order: Fajr, Sunrise, Dhuhr (or **Jumu'ah** on
  Fridays), Asr, Maghrib, Isha — Begins + Iqamah columns.
- On Fridays, the Dhuhr row is replaced by a Jumu'ah row using
  `data.friday.zuhr_jamah` (shown as "1st Khutbah") and
  `data.friday.asr_mithl_1` (shown as "2nd Khutbah") — this exact field
  mapping was verified against the masjid's own live screen at
  cheadlemasjid.org/prayer-times-screen-2/.
- The next upcoming Iqamah's row is highlighted (green accent bar).
- If the live fetch fails, the page falls back to the last successful
  response cached in `localStorage`, with an "Offline · showing last
  update HH:MM" footer notice.
- The page does **not** auto-reload itself (deliberately — see the iOS
  autoplay note below). Day rollover, the countdown, and adhan
  scheduling all work reactively off the live clock instead.

### Countdown display
- A **flip-clock** countdown (`#flipClock`) to the next Iqamah: 6 tiles
  (HH:MM:SS) that each play a 3D flip animation (CSS `rotateX`, two
  static halves + two animated flap layers per tile) when their digit
  changes, once a second. Tiles are a fixed dark colour scheme regardless
  of light/dark app theme (deliberately — that's what makes it read as
  "flip clock" rather than plain text with a border). Caption above it
  still reads "`<Prayer>` Iqamah in". (History: was a plain digital
  `HH:MM:SS` string before this, and an animated analogue clock face
  before that — see dated entries below. Don't reintroduce analogue
  without being asked.)

### Appearance
- **"Liquid Glass" look** (matching iOS 26's own material design): every
  floating panel (`#header`, `#countdownClock`, `#card`, `#settingsPanel`,
  `#settingsBtn`) is translucent with `backdrop-filter: blur(28px)
  saturate(180%)`, a bright hairline border, and an inset top highlight,
  sitting over a fixed multi-blob radial-gradient background (not an
  image — cheap to render continuously). The blur only reads as "glass"
  because the background behind it is colourful/varied; a flat single
  colour wouldn't show any visible effect.
- Light theme by default: soft pastel mesh gradient (mint/blue/cream/
  lavender) behind frosted white-ish glass panels, emerald (`#0e8f6b`)
  accent.
- Dark mode available via the gear icon (top-right) → Settings panel →
  Dark mode toggle. Choice persists in `localStorage`
  (`cheadleMasjidTheme`) across reloads. Dark mode uses the same glass
  treatment over a deep jewel-toned gradient instead.
- Both themes are plain CSS classes (`body.theme-light` /
  `body.theme-dark`), not CSS custom properties — kept for compatibility
  with the old Galaxy Tab 3 fallback path (see Deployment). Note this
  means `backdrop-filter` itself is *not* available on that old path
  (Android 4.4's WebView predates it) — the glass look is iPad-only by
  necessity; the old Tab 3 fallback would just show solid-ish flat
  panels instead, which is fine/expected, not a bug to fix.
- The flip-clock tiles stay their own fixed dark colour regardless of
  theme (unchanged) — deliberately opaque against the glass panels for
  contrast/legibility, real flip clocks aren't glass either.
- iOS "Add to Home Screen" meta tags (`apple-mobile-web-app-capable`
  etc.) so the Home Screen icon launches full-screen, no Safari chrome.

### Adhan (call to prayer)
- Settings panel → Adhan section: an on/off toggle for each of Fajr,
  Dhuhr/Jumu'ah, Asr, Maghrib, Isha, each with a ▶ Test button to
  preview immediately.
- Plays `adhan.mp3` ("Azan Madina" by Muhammad Marwan Qassas, supplied by
  the user) once, at the enabled prayer's **Begins** time (not Iqamah).
  **Not tracked in git** (see `.gitignore`) — it's a copyrighted
  recitation without confirmed redistribution rights, so it's purged
  from git history entirely and lives only as a plain file, locally and
  on the deploy server. If this repo is ever re-cloned fresh, `adhan.mp3`
  needs to be copied in by hand before adhan playback will work; the
  Test buttons in Settings will report "Couldn't find adhan.mp3" until
  then, which is the intended, self-explanatory failure mode. Tracked
  per-day in `localStorage` (`cheadleMasjidAdhanLastPlayed`) so it won't
  repeat if the page
  reloads later the same day.
- A small speaker icon (🔊) appears next to any prayer row whose adhan
  is currently armed.
- **iOS autoplay**: Safari blocks audio until a user gesture. The page
  "unlocks" itself permanently on the very first tap/click after each
  page load (`unlockAudioOnce()`), so every adhan after that plays with
  zero interaction — **as long as the page is never reloaded**, which is
  exactly why the automatic nightly reload was removed.
- A full-screen green alert appears while the adhan plays (scheduled or
  via Test), naming the prayer, with a pulsing speaker icon and a "Tap
  anywhere to stop" hint. Tapping it stops the audio and dismisses the
  alert; it also auto-dismisses when the adhan finishes on its own.
  Styling is fixed/theme-independent, sits above all other UI (z-index).

### Deployment (current, live)
- **Primary path — automated**: push to `main` on GitHub → a
  self-hosted GitHub Actions runner installed on the Linux home server
  (`gsuaha-home-server`, `192.168.0.180`) picks up the job → checks out
  the commit → `rsync`s it into `/var/www/cheadle-masjid-display`
  (excluding `.git`, `.github`, `adhan.mp3`). Runs as a systemd service
  under the `gsuaha` user. See `.github/workflows/deploy.yml`.
- **Fallback path — manual**: the original bare git repo
  (`~/git/cheadle-masjid-display.git`) + `post-receive` hook
  (`GIT_WORK_TREE=/var/www/cheadle-masjid-display git checkout -f main`)
  still exists and still works — `git push home main` from the Mac, run
  in a real terminal (SSH auth needs the user's own password entry, not
  something done through Claude directly). Useful if the runner service
  is ever down.
- Served by **Apache** (not nginx — nginx was the original plan, but the
  server already runs Apache on port 80 for other sites, notably
  `cloud.silkhomesltd.co.uk`; switching to nginx would have taken that
  offline, so a dedicated Apache vhost bound to `192.168.0.180:80` was
  used instead — nginx was never actually put into service on this box).
  Which deploy path is used doesn't matter to Apache — both write to the
  same folder.
- Displayed on an **iPad Pro 11" (iOS 26.6.1)**: Safari → Add to Home
  Screen → tap once to unlock audio → Auto-Lock set to Never → locked
  into the app via Guided Access (Settings → Accessibility → Guided
  Access, triple-click side button).
- **Confirmed working live on the iPad as of 2026-08-28; automated
  deploy pipeline confirmed working as of 2026-08-29.**
- Old Samsung Galaxy Tab 3 (Android 4.4) + GitHub Pages + Fully Kiosk
  Browser (legacy v2.9.3 build 360) setup is documented in the README as
  a fallback/alternative, not deleted, in case it's ever used again.

### Known trade-offs (intentional, don't "fix" without discussion)
- No automatic page reload → a pushed code change only takes effect once
  someone manually reopens the app on the iPad (exits Guided Access,
  taps the icon again). This was a deliberate choice over losing the
  audio-autoplay unlock on every reload.
- The whole page is plain ES5 JavaScript (no `fetch`, arrow functions,
  `let`/`const`, or CSS variables) — a holdover from Tab 3 support that's
  no longer strictly necessary on the iPad, but left as-is since
  rewriting it would be pure churn with no functional benefit.

---

## Change log

### 2026-08-28 — Initial build
Built from scratch: static `index.html` fetching live prayer times from
Cheadle Masjid's own WordPress REST API, ES5-only for Galaxy Tab 3
compatibility. Included GitHub Pages + Fully Kiosk Browser deployment
docs (superseded later the same day — see below).

### 2026-08-28 — Modern light/dark redesign
Replaced the original dark-green theme with a light, card-based design
(white cards, emerald accent). Added the settings gear icon and a dark
mode toggle persisted via `localStorage`.

### 2026-08-28 — Adhan playback
Added per-prayer adhan on/off toggles + Test buttons in Settings. Plays
`adhan.mp3` once at each enabled prayer's Begins time, tracked per-day
to avoid repeats. User supplied the audio file.

### 2026-08-28 — Full-screen adhan alert
Added the green full-screen "tap to stop" alert shown while an adhan is
playing, auto-dismissing when the adhan finishes unassisted.

### 2026-08-28 — Switched target device to iPad Pro + self-hosted server
Added iOS Home Screen meta tags. Removed the nightly auto-reload (broke
iOS audio-autoplay unlock on every reload). Rewrote deployment docs
around a self-hosted git-push pipeline instead of GitHub Pages.

### 2026-08-28 — Fixed dark mode toggle; digital→analogue→digital clock
Fixed a real bug: `applyTheme()` was overwriting the toggle's whole
`className`, stripping the shared `.toggleSwitch` base class introduced
for the adhan toggles, making the dark-mode switch invisible and
untappable. Also replaced the digital current-time clock with an
analogue countdown-to-Iqamah clock (hour/minute hands showing remaining
time) per user request.

### 2026-08-28 — Animated the analogue clock
Added a ticking seconds hand and smooth CSS-transitioned hand movement,
using an unwrapped (never modulo'd) angle to avoid a full-circle-spin
glitch at minute/hour boundaries.

### 2026-08-28 — Reverted to a digital countdown
User didn't like the analogue clock after seeing it animated — replaced
with a clean digital `HH:MM:SS` countdown instead. All SVG clock-face
code removed.

### 2026-08-28 — README fixes from live deployment troubleshooting
Two real issues hit while actually deploying, both fixed in the docs:
(1) split commands relying on `cd` persisting across separate terminal
runs, which it doesn't when each is run as a separate paste — merged
into single self-contained blocks; (2) the nginx config step showed the
desired file *content* but never the actual command to create it as
root (`sudo tee ... > /dev/null`, not `sudo cat >`, since a plain
redirect is opened by the shell before `sudo` elevates).

### 2026-08-28 — Live deployment: switched from nginx to Apache
Discovered on the actual server that Apache was already running on port
80 (serving `cloud.silkhomesltd.co.uk`), while nginx had never been
started. Rather than risk disrupting the existing site, configured a
dedicated Apache vhost (bound to the server's specific IP,
`192.168.0.180:80`, so it can't be shadowed by the other name-based
vhosts) instead of switching the box to nginx. **First successful live
deployment to the iPad happened this day.**

### 2026-08-28 — Added this file
Created `CHANGELOG.md` as the baseline/regression-tracking file per user
request, compiled from the full git history above.

### 2026-08-28 — Purged adhan.mp3 from git history ahead of going public
User decided to make the GitHub repo public but wanted `adhan.mp3`
excluded, since it's a copyrighted recitation without confirmed
redistribution rights. A plain `git rm` wouldn't have been enough — the
file would still be retrievable from every earlier commit on a public
repo — so ran `git filter-branch --index-filter 'git rm --cached
--ignore-unmatch adhan.mp3' --prune-empty -- --all` across all 11
commits at the time, then expired the reflog and ran `git gc
--prune=now --aggressive` to actually purge the blob (`.git` shrank from
carrying a 9MB file across several commits down to 136K). This rewrote
every commit hash. Took a full backup of the repo before starting since
this is a destructive rewrite. Restored `adhan.mp3` to the working
directory afterward (filter-branch's final checkout removed it) and
added `.gitignore` so it can't be accidentally re-tracked. The live
deployment on the server is unaffected — it's just a file sitting in
`/var/www/cheadle-masjid-display`, not something git manages there.

### 2026-08-28 — Published to GitHub
Repo is now public at github.com/amarmohammed398/cheadle-masjid-display
(13 commits, `adhan.mp3` confirmed absent). HTTPS push failed twice with
GitHub's "password authentication is not supported" error — not a 2FA
issue, GitHub simply requires a Personal Access Token in place of the
account password for any git operation over HTTPS, full stop, and the
account password kept getting typed instead. Switched to SSH instead:
generated a dedicated `~/.ssh/id_ed25519_github` key, added a
`Host github.com` entry to `~/.ssh/config` pointing at it, loaded it
into the macOS keychain via `ssh-add --apple-use-keychain`, added the
public key to the GitHub account, and pointed `origin` at
`git@github.com:amarmohammed398/cheadle-masjid-display.git`. Worked on
the first attempt. Two remotes now: `origin` (GitHub, public, for
backup/portfolio/collaboration) and `home` (the Linux server, private,
for the actual live deployment) — `git push` needs to name one
explicitly since neither is the sole upstream in the usual sense for
both directions (`-u` was only set for `origin`).

**Known follow-up**: because the history rewrite above changed every
commit hash, `home`'s stored copy of `main` now shares no common
ancestor with the local rewritten history. The *next* `git push home
main` will be rejected as non-fast-forward and needs
`git push home main --force` once to resync — safe, since it only
rewrites git's bookkeeping on the bare repo, not the already-deployed
files. After that one-time force-push, normal pushes resume as usual.

### 2026-08-28 — Added ARCHITECTURE.md
User is treating this project as a learning exercise for software/AI
engineering more broadly, and wanted a high-level, employer-readable
explanation of how the system works, kept up to date going forward —
distinct from this file, which is the granular/dated history. Added
`ARCHITECTURE.md`: system diagram, data flow, deployment pipeline, and
a "key engineering problems solved" section framing the real issues hit
during deployment (the Apache/nginx conflict, iOS autoplay, the git
history rewrite, the CSS animation angle-wrapping bug, GitHub's password
auth removal) as case studies rather than just bug fixes. Workflow
updated (see top of this file) to keep it current when a change is
architecturally significant, not for every commit.

### 2026-08-29 — Automated deployment with GitHub Actions
Added `.github/workflows/deploy.yml`: pushing to `main` now automatically
deploys to the live display, removing the manual `git push home main`
step (which stays available as a fallback — nothing about it changed).

Deliberately used a **self-hosted runner** rather than GitHub's default
cloud runners: the home server has no public address, so a cloud runner
would have no way to reach it. Installing GitHub's runner agent directly
on the server flips the direction of the connection — the runner polls
GitHub outbound, nothing needs to accept inbound traffic — which fits
the "everything stays on the home LAN" principle the whole deployment
was already built around, and avoids opening a port on a box that also
serves another site.

The deploy step is `rsync -av --delete` from the runner's checkout into
`/var/www/cheadle-masjid-display`, excluding `.git`, `.github`, and
**`adhan.mp3`** — the last one is load-bearing, not cosmetic: since
`adhan.mp3` isn't tracked in git at all, `--delete` would otherwise see
it as "not in the source" on the very first automated run and delete it
from the live server.

Runner registered via GitHub's one-time setup token, installed as a
systemd service (`svc.sh install` / `start`) running as the `gsuaha`
user — the same user that owns the served folder, so no permission
issues syncing into it. First automated run (triggered by the commit
that added this very workflow) completed in 19 seconds; verified the
served folder afterward and confirmed exactly the expected files, with
`adhan.mp3`'s original timestamp untouched.

Two real copy-paste snags hit while setting this up, both about
interactive terminal input rather than the runner itself: (1) GitHub's
runner-setup page renders `$` prompts and inline comments for
readability that aren't meant to be pasted literally, and a multi-line
selection from that page dropped a newline, merging a comment onto the
following command; (2) `./config.sh`'s first run had a second copy of
the same command sitting in the terminal's input queue, which got
consumed as the answer to its first interactive prompt instead of
waiting for real input — fixed by re-running it alone and answering each
prompt one at a time.

### 2026-08-29 — Digital countdown became a flip clock
Replaced the plain `HH:MM:SS` text countdown with a proper flip-clock
animation: 6 tiles, each with 4 layers (two static halves showing the
current digit, two animated "flap" layers that do the actual 3D
rotation via CSS `rotateX`). When a digit changes: the old digit's top
flap folds down (`rotateX(0deg)` → `rotateX(-90deg)`, revealing the
static top underneath, which was already updated to the new digit),
then the new digit's bottom flap unfolds in (`rotateX(90deg)` →
`rotateX(0deg)`) starting exactly when the first half finishes, via a
CSS `animation-delay` rather than any JS timing chain.

Two implementation details worth remembering if this needs touching
again: (1) restarting a CSS animation on an element that's already
played it needs the class removed, a forced reflow
(`void el.offsetHeight`), and the class re-added — without the forced
reflow the browser can no-op the re-add since "nothing changed"; (2) the
flap layers need the exact same half-height/overflow-clip span
positioning as the static layers underneath them, which was originally
only written for `.half` and silently didn't apply to `.flap` — an easy
copy-paste gap to reintroduce if these are ever restyled separately.

Verified the flip animation actually runs (not just the CSS existing)
by checking a mid-animation screenshot showed a visibly distorted
digit, and confirmed the underlying countdown value itself decrements
correctly. That second check surfaced a **test-environment artifact**
worth remembering: this project's automated browser-testing tool never
reports a tab as `document.visibilityState: "visible"`, even when
freshly created or explicitly fronted — Chrome throttles timers in
backgrounded tabs, so `setInterval(tick, 1000)` was only observed firing
every ~2 seconds in that tool, always by a clean, consistent delta
(never irregular) confirming it wasn't a logic bug, just the same
category of "local test harness ≠ production" issue as the earlier
WEBrick flakiness. Real iPad Safari, always foregrounded, doesn't have
this problem.

### 2026-08-29 — "Liquid Glass" redesign
User asked for the UI to look like iOS glass (Apple's current "Liquid
Glass" material, matching the iPad's own iOS 26). Replaced every flat
panel background with `backdrop-filter: blur(28px) saturate(180%)` +
translucent fill + bright hairline border + an inset top highlight
(`inset 0 1px 0 rgba(255,255,255,...)`, a cheap fake specular highlight
— real glass reflects more light near the top edge). Replaced the flat
single-colour page background with a fixed multi-blob radial-gradient
per theme — necessary, not decorative: a blur effect over a single flat
colour behind it produces no visible difference, so glass panels need
something colourful/varied behind them to actually read as "glass" at
all. Corner radii bumped up throughout (16-20px → 24-28px) to match
iOS's more pronounced continuous-corner style.

Deliberately left alone: the flip-clock tiles (stay solid/dark — real
flip clocks aren't glass, and it gives useful contrast against the now
much busier background) and the full-screen adhan alert (already had
its own independent design language, unrelated to this).

Noted in the baseline: `backdrop-filter` doesn't exist on the old
Galaxy Tab 3's Android 4.4 WebView (this CSS property postdates it
entirely), so that fallback path would show flat-ish translucent panels
without the blur — a graceful, expected degradation, not a bug, since
it's just an unsupported-property no-op rather than breaking anything.

### 2026-08-29 — Reverted the plain-background experiment
The two "make the background plain" changes (dark mode, then light
mode) made the glass hard to distinguish in practice — without a
colourful, varied backdrop for `backdrop-filter: blur()` to actually
soften, the panels read as plain translucent boxes rather than glass,
even with the added sheen/border/highlight. User asked to revert;
`git revert -n 03d54bc 95fd124` cleanly restored the original colourful
multi-blob gradient backgrounds for both themes (this file's baseline
above already describes that original version — it was never rewritten
to describe the flattened one being reverted here). Lesson for next
time a background-simplification request comes up: try it and actually
look at it side-by-side with the original before assuming a
panel-material-only glass effect will read clearly enough on its own.
