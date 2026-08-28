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
5. Commit with a descriptive message. Commit each logical change
   separately rather than batching unrelated things together.
6. Push to whichever remotes are relevant (`home` for the live display,
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
- A digital `HH:MM:SS` countdown (`#countdownDigital`) to the next
  Iqamah, ticking down every second, with a caption above it reading
  "`<Prayer>` Iqamah in". (Was an animated analogue clock face with
  hour/minute/second hands earlier the same day — replaced per explicit
  request; don't reintroduce analogue without being asked.)

### Appearance
- Light theme by default: white cards, soft shadows, emerald (`#0e8f6b`)
  accent, on a light grey (`#f2f4f7`) background.
- Dark mode available via the gear icon (top-right) → Settings panel →
  Dark mode toggle. Choice persists in `localStorage`
  (`cheadleMasjidTheme`) across reloads.
- Both themes are plain CSS classes (`body.theme-light` /
  `body.theme-dark`), not CSS custom properties — kept for compatibility
  with the old Galaxy Tab 3 fallback path (see Deployment).
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
- **Self-hosted**, not GitHub Pages: a bare git repo
  (`~/git/cheadle-masjid-display.git`) on the user's Linux home server
  (`gsuaha-home-server`, `192.168.0.180`), with a `post-receive` hook
  that runs `GIT_WORK_TREE=/var/www/cheadle-masjid-display git checkout
  -f main` on every push.
- Served by **Apache** (not nginx — nginx was the original plan, but the
  server already runs Apache on port 80 for other sites, notably
  `cloud.silkhomesltd.co.uk`; switching to nginx would have taken that
  offline, so a dedicated Apache vhost bound to `192.168.0.180:80` was
  used instead — nginx was never actually put into service on this box).
- `git remote add home ssh://gsuaha@192.168.0.180/home/gsuaha/git/cheadle-masjid-display.git`,
  then `git push home main` to deploy — must be run in a real terminal on
  the Mac (not through Claude directly — SSH auth needs the user's own
  password entry).
- Displayed on an **iPad Pro 11" (iOS 26.6.1)**: Safari → Add to Home
  Screen → tap once to unlock audio → Auto-Lock set to Never → locked
  into the app via Guided Access (Settings → Accessibility → Guided
  Access, triple-click side button).
- **Confirmed working live on the iPad as of 2026-08-28.**
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
