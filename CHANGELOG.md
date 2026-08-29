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

## Current baseline (as of 2026-08-29)

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
- A plain **digital `HH:MM:SS`** countdown (`#countdownDigital`) to the
  next Iqamah, ticking down every second, with a caption above it
  reading "`<Prayer>` Iqamah in". (Full history: digital current-time
  clock → analogue clock → animated analogue → plain digital → flip
  clock → **back to plain digital**, all in the space of one day — see
  dated entries below. This is the current, settled form; don't
  reintroduce the flip clock or analogue without being asked again.)

### Navigation (home screen / multiple displays)
- The app can show one of several full-screen **displays**; a home
  screen (`#homeScreen`) picks between them, one tile per display. Two
  exist today: **Prayer Times** (`#prayerScreen`, formerly just `#app`,
  crescent-moon icon) and **Server Health** (`#serverScreen`, server-rack
  icon, purple accent — see its own section below).
- Displays are registered in one place, `TABLET_SCREENS` (an id →
  element-id map) in `index.html` — adding a new display means adding
  one entry there plus a tile in `#homeScreen`; `showScreen(name)` hides
  every registered screen and shows only the requested one, rather than
  an if/else chain that would grow by a branch per display.
- Every display's own header carries a shared `.screenHeader` class
  (not just an id) precisely so `positionMoreIcon()` can find "the
  current screen's header" generically (scoped to whichever screen
  `TABLET_SCREENS[currentScreen]` names) instead of hardcoding one id.
- Switching screens (`showScreen(name)`) is a pure show/hide of existing
  DOM, **never a page reload/navigation** — a reload would throw away
  the Prayer Times adhan's audio-autoplay unlock (see Adhan below), so
  every display has to coexist in one document.
- **One bare corner icon** (top-right, ⋮, `#settingsBtn`), outside
  whichever display's glass panel is showing → opens a small popover
  (`#moreMenu`) with two rows today: **Home** (house icon) → returns to
  `#homeScreen`; **Settings** (gear icon) → opens that display's
  settings panel. The icon is hidden while `#homeScreen` itself is
  showing — nothing to navigate to or configure from there yet. (There
  was briefly a second, separate top-left Home icon — see the dated
  entry below for why that got folded into this menu instead.)
- Reopening the app (e.g. after an iPad restart) returns to whichever
  display was last open (`localStorage` key `cheadleMasjidLastScreen`),
  **not** the home screen — defaults to `prayer-times` if nothing's
  saved yet (or if the saved value doesn't name a real display, e.g.
  after a display is ever removed), so the always-on kiosk behaviour
  that predates the home screen is unaffected by adding one.
- The ⋮ icon's vertical position is computed from the current display's
  own `.screenHeader` via `getBoundingClientRect()` (`positionMoreIcon()`),
  re-run every time `showScreen()` switches to a non-home screen (as
  well as on `window.resize`) — this only works while that display's
  header actually exists in the DOM and is visible, which is why it's
  tied to the screen-switch, not just a one-time page-load call.
- Browser tab / PWA title is now **"Home Dashboard Hub"** (was "Cheadle
  Masjid - Prayer Times") — reflects the app as a whole, not just its
  first display. Each display keeps its own on-screen branding/accent
  colour (Prayer Times: "Cheadle Masjid", teal-emerald; Server Health:
  "Home Server", purple) — that's correct, not an inconsistency to fix.

### Server Health display
**Status: client built (tested against a mock fixture) and the
server-side collector script + systemd timer + workflow changes are
written — none of it has been installed/enabled on the actual server
yet.** See the dated entries below for the full plan and what's left
(installing `lm-sensors`/`jq`, copying the systemd unit files into
`/etc/systemd/system/`, enabling the timer). Don't expect real data on
the live iPad until that manual install step is done.
- Second tablet screen (`#serverScreen`), purple accent throughout
  (heading, memory bar, chart lines — deliberately not the same
  teal-emerald as Prayer Times, so the two displays read as visually
  distinct at a glance, including from the home screen tile).
- Polls a same-origin `server-stats.json` every 10s (`fetchServerStats()`,
  same resilient pattern as the prayer-time fetch: falls back to the
  last-known-good response in `localStorage` on failure, never clears
  the screen just because one poll failed).
- Cards: Uptime, CPU Load (+ trend chart), Memory (+ bar + trend chart),
  Temperature (+ trend chart), Disk (per mount), Services (per-service
  active/inactive dot), **Last Successful Deploy** (age since the
  runner's last successful job — not just "is the runner process
  running", which the 29 Aug DNS outage proved doesn't actually tell you
  whether deploys are working), Containers.
- Trend charts (`renderSparkline()`) are small hand-built inline-SVG
  line+area charts reading a short rolling `history` array per metric
  (`history.cpu_load`, `.memory_percent`, `.temp_c` — oldest first) —
  no charting library, consistent with the rest of this app. Colour
  follows the same warn/bad thresholds as the metric's own bar/text
  (memory/temp ≥70% or ≥90%-equivalent turn amber/red); CPU load's
  chart is deliberately left neutral since "too high" depends on core
  count, which isn't tracked, so no threshold is invented for it.
- Service/container status dots are **iOS systemGreen/systemRed**
  (`#34c759`/`#ff3b30` light, `#30d158`/`#ff453a` dark) — deliberately
  not the same green as Prayer Times' accent or this screen's purple;
  reads as a distinct "terminal/systemd status" signal (think
  `systemctl status`'s "active"/"failed"), universal green=good/red=bad
  regardless of which display it's on.
- A stale-data banner (mirroring Prayer Times' "Offline · showing last
  update") shows if `generated_at` is more than 30s old **or** the last
  poll failed — catches both "the collector script died" and "the
  network request failed" as the same user-facing "don't trust this"
  state, rather than only handling one of the two.
- `server-stats.json` is `.gitignore`'d, same treatment as `adhan.mp3` —
  it's server-generated state, not app code, and must never be
  committed or wiped by a deploy (added to the rsync exclude list once
  the server-side script exists).

### Appearance
- **"Liquid Glass" look** (matching iOS 26's own material design): every
  floating panel (`#header`, `#countdownClock`, `#card`, `#settingsPanel`,
  `#moreMenu`, `.tile`) is translucent with `backdrop-filter: blur(28px)
  saturate(180%)` and a bright hairline border. `#settingsBtn` and
  `#homeBtn` are deliberately **not** part of this shared glass styling —
  they're bare icons, not panels (see Navigation below).
- **Page background is a plain flat colour, no gradient**: pure white
  (`#ffffff`) in light theme, pure black (`#000000`) in dark theme — by
  explicit request (see dated entries below; this went colourful → flat
  → colourful → flat again, settle on flat this time unless asked
  otherwise). This means the glass blur has nothing colourful behind it
  to visibly soften — the panels still read as glass via their
  translucency/border/shadow, just more subtly than with a busy
  backdrop. That trade-off was made consciously this time, not
  overlooked.
- Emerald (`#0e8f6b` light / `#2fd39a` dark) accent colour throughout.
- Dark mode available via **⋮ → Settings → Dark mode toggle** (see
  Navigation below for the full ⋮/Settings/Home structure). Choice
  persists in `localStorage` (`cheadleMasjidTheme`) across reloads.
- Both themes are plain CSS classes (`body.theme-light` /
  `body.theme-dark`), not CSS custom properties — kept for compatibility
  with the old Galaxy Tab 3 fallback path (see Deployment). Note this
  means `backdrop-filter` itself is *not* available on that old path
  (Android 4.4's WebView predates it) — the glass look is iPad-only by
  necessity; the old Tab 3 fallback would just show solid-ish flat
  panels instead, which is fine/expected, not a bug to fix.
- The flip-clock tiles no longer exist (see Countdown display above) —
  no glass-vs-solid question for them any more.
- iOS "Add to Home Screen" meta tags (`apple-mobile-web-app-capable`
  etc.) so the Home Screen icon launches full-screen, no Safari chrome.

### Adhan (call to prayer)
- Settings panel → Adhan section: an on/off toggle for each of Fajr,
  Dhuhr/Jumu'ah, Asr, Maghrib, Isha, each with a Test button (a solid
  SVG play triangle, `.testBtn svg`, iOS SF Symbols "play.fill" style)
  to preview immediately.
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
- A small speaker icon (`.adhanArmedIcon`, an SVG outline icon — the
  same "volume-2" style already used in the full-screen adhan alert, not
  an emoji) appears next to any prayer row whose adhan is currently
  armed, coloured with the app's accent green so it visually matches an
  "on" toggle switch.
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
- Displayed on an **iPad Pro 11" (iOS 26.6.1)** via **dotKiosk Full
  Screen Browser** (free App Store app) → tap once to unlock audio →
  Auto-Lock set to Never → locked into dotKiosk via Guided Access
  (Settings → Accessibility → Guided Access, triple-click side button).
  Plain Safari + "Add to Home Screen" still works and is documented in
  the README as a fallback, but is no longer the primary method — see
  dated entry below for why.
- **Confirmed working live on the iPad as of 2026-08-28; automated
  deploy pipeline confirmed working as of 2026-08-29; dotKiosk switch
  confirmed working as of 2026-08-29.**
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
- **Repo/folder/server path still named `cheadle-masjid-display`**, even
  though the app is now a multi-display hub (see Navigation above) and
  the browser tab title is "Home Dashboard Hub". Deliberate — renaming a
  live GitHub repo + server directory + Apache vhost is real, riskier
  work than a copy change, and is deferred until a couple more displays
  exist rather than done mid-build. Don't rename these without being
  asked; see ARCHITECTURE.md's "Future displays" section for the plan.

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

### 2026-08-29 — Flip-clock tiles: glass instead of solid dark, and bigger
User didn't like the flip-clock tiles' solid black-ish look clashing
with the surrounding Liquid Glass panels, and wanted them bigger.
Reworked `.flipTile .half`/`.flap` from solid `linear-gradient` fills to
the same material language as every other panel: `backdrop-filter:
blur(16px) saturate(180%)`, theme-specific translucent fill + bright
border (top half more opaque than bottom, a subtle nod to how a real
split-flap card catches light differently top vs bottom), moved into
the light/dark theme sections rather than hardcoded. The seam/hinge
line was also softened from solid black to a faint translucent line so
it doesn't look out of place against glass. Sizing increased across the
board: tile `4.6vw×6vh` → `6.6vw×8.6vh`, digit font `4vw` → `5.6vw`,
colon `3vw` → `4vw`. Verified in both themes: tiles now clearly read as
part of the same glass system as the header/countdown box/table, still
legible, flip animation unaffected by the material change.

### 2026-08-29 — Flip clock removed, backgrounds made truly plain
User asked to (1) drop the flip clock entirely and go back to the plain
digital `HH:MM:SS` countdown, and (2) make each theme's background a
single flat colour with no other colours mixed in — white for light,
dark for dark, full stop (stricter than the earlier "plain flat colour"
attempt, which still used off-white/near-black tones like `#eef2f5` and
`#10131a`; this time genuinely `#ffffff` and `#000000`).

Removed entirely rather than hidden/disabled: `#flipClock` and all
`.flipTile`/`.flap`/`.half` CSS, the `buildFlipTile`/`buildFlipClock`/
`setFlipDigit` JS functions and the `flipTiles` array, the flip
keyframes, and the theme-specific flip-tile colour rules. Restored the
original `#countdownDigital` element, its CSS, and the plain-text
`renderCountdown()` body — pulled from this file's own history of that
exact code rather than reconstructed from scratch, to make sure it
matched exactly.

Backgrounds: `body.theme-light`/`body.theme-dark` are now bare
`background-color: #ffffff` / `#000000`, no gradient layers at all. As
already noted in the baseline, this makes the glass panels' blur have
nothing to visibly soften — accepted this time as a deliberate,
understood trade-off rather than something to re-litigate.

Verified both themes visually before shipping. One thing worth a note
for next time: the dark-mode screenshot taken during verification
rendered as mid-grey instead of black, but `getComputedStyle` confirmed
`rgb(0, 0, 0)` with no filters/blend-modes applied — a capture-pipeline
quirk in this project's testing tool (likely colour-profile/gamma
handling), not a real rendering bug. Same category as the earlier
WEBrick and hidden-tab-timer-throttling artifacts: verify via computed
styles when a screenshot looks suspicious, don't assume the screenshot
is ground truth.

### 2026-08-29 — Switched iPad display method to hide the status bar
User wanted iOS's own status bar (clock/date/wifi/battery) gone
entirely. This isn't fixable from the page itself: the status bar is
OS-level UI, and — unlike native apps, which can request it hidden via
`prefersStatusBarHidden` — Safari-based standalone web apps have no API
to suppress it; `apple-mobile-web-app-status-bar-style: black-translucent`
(already in use) only makes content flow *underneath* it, the icons
stay visible. Genuinely fixing this needs a native app wrapping a
WebView, which only Apple-signed apps (not web pages) are allowed to do.

Three options were on the table: build a custom native wrapper (only
Command Line Tools are installed here, not full Xcode, so this would've
meant a real iOS-dev side-quest — free-tier Apple ID needs reinstalling
via USB every 7 days, or $99/year for a permanent install), use an
existing App Store kiosk app, or leave the status bar visible. User
chose to trial an existing app first, with the explicit option to
revert if it didn't work out.

Picked **dotKiosk Full Screen Browser** (free, by Free Tomorrow) after
checking actual App Store pricing rather than trusting search-result
summaries — the first candidate found (UPDT d.o.o.'s "Kiosk - fullscreen
browser") turned out to be $0.99 despite a search summary calling it
free; dotKiosk is genuinely free with no IAP, explicitly built for this
"repurpose an old device as a kiosk display" use case, and explicitly
designed to be paired with Guided Access (which was already set up).

**Confirmed working — this is now the primary iPad setup method.**
Plain Safari + Add to Home Screen (can't hide the status bar, but needs
zero third-party apps) is kept in the README as a documented fallback,
same pattern as the old Galaxy Tab 3 path — not deleted, just no longer
the default recommendation.

### 2026-08-29 — Replaced emoji/unicode icons with proper SVG icons
User didn't like the Test button (a unicode "▶" character, U+25B6) or
the "adhan armed" indicator (an actual emoji, 🔊, U+1F50A) — wanted
something modern matching the rest of the iOS-styled UI, not emoji.

Test buttons: replaced the unicode glyph with an inline SVG solid
triangle (`<path d="M8 5v14l11-7z"/>`, `fill="currentColor"`) — a filled
shape rather than a thin outline, matching iOS's own SF Symbols
"play.fill" convention, which also reads more clearly at this tiny
(26px circle) size than a stroke-only outline would.

Adhan-armed indicator: replaced the emoji with the same "volume-2"
outline SVG icon already used in the full-screen adhan alert (three
lines: a speaker polygon + two sound-wave arcs), for visual consistency
between the two places sound is represented in this UI. Coloured with
the app's accent green (`#0e8f6b` light / `#2fd39a` dark) rather than
emoji's fixed OS-rendered colours, so it visually matches an "on"
toggle switch.

Both are plain inline SVG (no icon font/library dependency, consistent
with how the settings gear and adhan alert icons were already built).
Verified: play buttons still trigger their test correctly (click
bubbles up from the SVG child to the button div's handler, same
pattern already relied on for the settings gear), icons render cleanly
in both themes.

### 2026-08-29 — Fixed vertical centering of the adhan-armed icon
User noticed the speaker icon sat a little low next to the prayer name.
Cause: it relied on `vertical-align: middle` on an inline icon next to
large (`2.7vw`), bold (`700`) text — `vertical-align: middle` aligns to
half the text's *x-height*, not the visual centre of the glyphs, and
that gap becomes noticeable at large/bold sizes. Fixed by making
`.cell.name` a flex container (`display: flex; align-items: center`)
instead — the bare "Fajr" text becomes an anonymous flex item
alongside the icon's `<span>`, and flexbox centres both against the
cell's true height regardless of font metrics. Verified via
`getBoundingClientRect()` rather than eyeballing a screenshot: icon's
vertical centre now lands within 0.004px of the cell's centre.

### 2026-08-29 — Settings icon moved in-flow; fixed panel asymmetry
User noticed the settings gear made panel proportions uneven. Root
cause: the gear was `position: fixed` floating over the header, and
`#app` carried a permanent `padding-right: calc(3vw + 60px)` just to
keep the header's date text clear of it — every panel's actual usable
width was skewed right relative to left, purely to reserve space for
one corner icon.

Discussed options (moving it into the header's flow; a single
"more"-style overflow icon that scales to future actions like a future
Home button without adding visual clutter; a hidden long-press gesture;
relocating to a bottom dock) — user chose the overflow-icon approach.

Implemented as: bring the single icon into the header's own flex layout
(fixes the padding/symmetry problem at the root) as a plain "more"
icon (fixes the scalability problem):
- `#settingsBtn` moved from a floating glass circle (44px, fixed
  top-right, part of the shared glass-panel styling) to a bare 34px
  icon-only element living inside `#clockBlock`, right after the date —
  no background/border/shadow, just the icon, coloured to match the
  date text's muted colour (deliberately minimal visual weight).
- Icon changed from a gear (`circle` + complex cog path) to a plain
  three-dot ellipsis (`fill="currentColor"`, three `<circle>`s) —
  reads as "more options" rather than narrowly "settings", so it stays
  accurate once non-settings entries (e.g. a Home button) are added to
  the panel it opens later. No new entries added yet — the panel
  structure (Appearance / Adhan sections) already scales to more
  sections without changes.
- `#app`'s `padding-right: calc(3vw + 60px)` removed entirely; padding
  is symmetric `3vh 3vw` again.
- `#clockBlock` became a flex row (date + icon side by side) instead of
  `text-align: right`.

No JS changes needed — `initSettingsUI()` only ever looked up
`#settingsBtn`/`#settingsPanel` by ID and used event bubbling for
clicks, both unaffected by the positioning/markup change.

Verified via `getBoundingClientRect()` on the header, countdown box,
and table: all three now have **identical** left/right margins
(30.71875px each, at 1024px viewport width) — confirmed symmetric,
not just visually eyeballed.

### 2026-08-29 — "More" icon: vertical dots, moved outside the header pane
User asked for two changes to the icon from the previous entry: make
the three dots vertical instead of horizontal, and move it outside the
header's glass pane rather than inside it.

- Icon changed from a horizontal ellipsis (three `<circle>`s in a row)
  to a vertical one (`cx="12"`, `cy` at 5/12/19 — a stacked column
  instead).
- `#settingsBtn` moved back out of `#clockBlock` to a top-level,
  `position: fixed` element — but *not* a return to the old fixed gear
  from two entries ago, which is what originally broke panel symmetry.
  The old version needed `#app` to reserve a special one-sided
  `padding-right` just to keep the header clear of it. This version
  instead sits inside the **already-existing, still-symmetric** 3vw
  gutter that `#app`'s `padding: 3vh 3vw` reserves on both sides —
  `right: calc(1.5vw - 14px)` centres a 28px icon in that gutter, no new
  padding added anywhere. Confirmed via `getBoundingClientRect()`: the
  header's left/right edges are still equidistant from the viewport
  (35.8125px each side at 1194px width) — the icon sits entirely
  outside that box, in the margin, without perturbing it.
- Vertical centring against the header is done from JS, not CSS —
  `positionSettingsBtn()` (called once on load and again on
  `window.onresize`) reads the header's live `getBoundingClientRect()`
  and centres the icon against it. A pure-CSS offset wasn't viable here
  because the header's height is driven by its vw-sized text content,
  not a fixed number. Verified the two centres land within ~0.003px of
  each other (header centre 75.44px vs icon centre 75.4375px, at
  1194×834).
- `#settingsPanel`'s own position (`top: 6.4vh; right: 2vh`) is
  independent of the button's position and needed no change — it was
  never anchored relative to `#settingsBtn` in the first place.
- No JS changes to `initSettingsUI()` itself (click handling, panel
  open/close) — only the new `positionSettingsBtn()` helper was added
  and wired into init + resize.

Verified in both light and dark themes in the local preview: icon
renders in the correct theme colour, sits visibly clear of the header's
blurred background, opens/closes the panel correctly, and panel
symmetry (header/countdown-box/table) is unaffected.

### 2026-08-29 — Home screen + multi-display navigation; project scope widened
User is taking this from a single-purpose prayer-times display into a
multi-display smart-home hub: one iPad (picture-frame case) picking
between several full-screen "displays" from a home screen, starting with
Prayer Times and adding more later (home server health, energy/water/gas
usage, etc. — brainstormed together, tracked as ideas in
ARCHITECTURE.md's "Future displays" section, not commitments yet).

Two concrete UI changes requested to kick this off: (1) the ⋮ icon
should open a small menu with a **Settings** gear entry, rather than
opening the settings panel directly; (2) a separate **Home** button
should exist to reach a **home screen** for picking between displays,
with only one tile (Prayer Times) for now.

Implemented:
- **`#app` renamed to `#prayerScreen`** — now that there's more than one
  screen, "app" was ambiguous about which one it meant. No other id
  changed. Renaming was safe to do in one pass: it was referenced only
  in CSS and one HTML tag, never by JS (confirmed by grep before
  renaming).
- **New `#homeScreen`**: a centred grid of "tiles" (`.tile`, styled with
  the same glass-panel treatment as the other panels), one per display.
  Today there's exactly one, "Prayer Times" (a crescent-moon icon, Feather
  Icons' widely-used `M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z`
  path, filled) — tapping it calls `showScreen("prayer-times")`.
- **New `#homeBtn`**: a solid house glyph (Material Design's public
  "home" icon path), mirrored to the left of the existing ⋮ icon
  (`#settingsBtn`) — same size, same fixed-in-the-existing-gutter
  positioning technique, same JS-computed vertical centring against the
  current screen's header (`positionCornerIcons()`, generalised from the
  old single-icon `positionSettingsBtn()` to loop over both). Clicking it
  calls `showScreen("home")`.
- **New `#moreMenu` popover**: clicking `#settingsBtn` now opens/closes
  this small list (currently one row: a Material Design gear icon +
  "Settings" label) instead of opening `#settingsPanel` directly.
  Clicking the row closes the popover and opens `#settingsPanel`, same
  as before. Positioned via a new `positionMoreMenu()`, anchored to
  `#settingsBtn`'s own live `getBoundingClientRect()` rather than a
  guessed offset — same reasoning as the existing corner-icon
  positioning. Written as a list (not a single button) specifically so
  more entries can be added later without restructuring it.
- **`showScreen(name)`**: the single function that shows one screen and
  hides the rest, closes any open popovers/panels on every switch, shows/
  hides both corner icons (hidden entirely on the home screen — nothing
  to configure or navigate to from there yet), and — for any non-home
  screen — repositions the corner icons and saves the choice to
  `localStorage` (`cheadleMasjidLastScreen`). Deliberately a pure show/
  hide via `className`/`style.display`, never a page reload/navigation:
  a reload would re-lock iOS's audio-autoplay unlock the adhan depends
  on, so this app can never navigate to "change screens," only toggle
  visibility within one already-loaded document.
- **Boot behaviour**: `initNavigationUI()` calls
  `showScreen(getLastScreen())` on load, defaulting to `"prayer-times"`
  if nothing's saved yet — so a cold boot (e.g. iPad restart) goes
  straight into Prayer Times exactly as before, not to the new home
  screen. The home screen is purely opt-in via the new Home button.
- **Title changed**: browser tab / PWA title is now "Home Dashboard Hub"
  (`<title>` and `apple-mobile-web-app-title`), reflecting the app as a
  whole. The Prayer Times display's own on-screen `#masjidName` heading
  is untouched — "Cheadle Masjid" is that display's own branding, not
  the app's.
- **Project not renamed yet**: repo, local folder, and server directory
  all still `cheadle-masjid-display` — see the new "Known trade-offs"
  entry above. README.md and ARCHITECTURE.md updated to describe the
  wider vision and explicitly flag this as deferred, not forgotten.

Verified in the local preview, both themes: default boot lands on
Prayer Times (not Home); Home icon → tile grid renders correctly, no
corner icons showing; tapping the tile returns to Prayer Times with the
countdown still ticking (confirming no reload happened); ⋮ → popover →
Settings → panel opens correctly and popover closes itself; dark mode
toggle still re-colours both corner icons and the tile; reloading the
page while parked on the home screen still returns to Prayer Times (not
stuck on Home), confirming `getLastScreen()`'s save-on-tablet-only
behaviour.

### 2026-08-29 — Folded the separate Home icon into the ⋮ menu
User asked for Home to be reachable from the ⋮ menu instead of its own
icon on the opposite side of the display — one entry point instead of
two.

- **`#homeBtn` removed entirely** (markup, its CSS rules, its theme
  colours, its `positionCornerIcons()` loop entry) — there is now only
  one corner icon, `#settingsBtn` (⋮), same as before the previous
  entry introduced Home.
- **`#moreMenu` gained a second row**, "Home" (the same solid house
  glyph `#homeBtn` used), placed above "Settings" — clicking it closes
  the popover and calls `showScreen("home")`, same pattern as the
  Settings row already used.
- `positionCornerIcons()` (which looped over an array of icon ids for
  the two-icon layout) reverted to a single-icon function, renamed
  `positionMoreIcon()` — an array-of-one loop would've been dead
  generality now that only `#settingsBtn` needs positioning.
- `showScreen()` no longer shows/hides a `homeBtn` — only `settingsBtn`
  is hidden on the home screen now.
- No change to `#moreMenu`'s own position/size, or to how Settings
  itself opens — only what triggers "go to the home screen" moved.

Verified in the local preview: ⋮ → popover now shows both "Home" and
"Settings" rows with their icons; tapping Home closes the popover and
shows the tile grid with no corner icon visible; tapping the Prayer
Times tile returns correctly with the countdown still ticking (no
reload); no console errors from the removed `#homeBtn` references
(confirmed via a full grep of `index.html` for stray `homeBtn`/
`positionCornerIcons` mentions before testing, then again via the
browser console after).

### 2026-08-29 — Server Health display: client built (step 1 of 3)
Second tablet screen, kicking off the smart-home-hub expansion agreed
earlier. Spec discussed and agreed first (metrics list, data-flow
approach, refresh cadence) before writing any code — see that
discussion for the full reasoning; this entry covers what was actually
built. Plan is three steps: (1) client-side screen against a mock
fixture — **this entry**; (2) the server-side collector script +
systemd timer + `lm-sensors` + workflow changes — not done yet; (3)
wire the real fetch up end-to-end and verify on the live iPad/server.

**Screens/navigation refactor** (needed regardless of this specific
display, since it's the first time a second tablet screen existed):
- `showScreen()` moved from an if/else (one branch per screen) to a
  `TABLET_SCREENS` id → element-id registry, looped over to hide
  everything then show the one requested. Adding a third display later
  means one new map entry, not a new branch.
- The shared header layout (previously `#header`'s own CSS) became a
  `.screenHeader` class so every tablet screen can have its own header
  element while still getting the same look, and so
  `positionMoreIcon()` can find "the current screen's header" by
  querying `.screenHeader` scoped to `TABLET_SCREENS[currentScreen]`
  instead of a hardcoded id.
- `getLastScreen()` now validates the saved screen name still exists in
  `TABLET_SCREENS` before trusting it (falls back to `prayer-times`
  otherwise) — otherwise a future display getting removed could leave
  someone's `localStorage` pointing at a screen that no longer exists.

**Server Health screen itself** — full details in the Server Health
baseline section above; highlights:
- Purple accent (heading, memory bar, chart lines) chosen specifically
  so it doesn't share Prayer Times' teal-emerald — user asked for this
  explicitly once both screens existed side by side and the shared
  green made them look like the same thing. Carried through to the
  home-screen tile icon too (scoped override,
  `.tile[data-screen="server-health"] .tileIcon`), not just the screen
  itself, so the tile visually previews what it opens.
- Service/container status dots deliberately **not** purple or Prayer
  Times' green — user asked for a distinct "Linux/systemd active/failed"
  look, landed on iOS's own systemGreen/systemRed (`#34c759`/`#ff3b30`
  light, `#30d158`/`#ff453a` dark): vivid, clearly different from both
  other accents, and consistent with the app's existing iOS design
  language rather than reaching for generic ANSI terminal colours.
- Trend charts (CPU load, memory %, temperature) added on request for
  "more information, and pretty" — hand-built inline-SVG line+area
  sparklines (`renderSparkline()`) reading a rolling `history` array per
  metric, no charting library. This is the reason `server-stats.json`'s
  schema carries a `history` object, not just current-value fields.
- **Bug caught by testing, fixed before it ever reached a real
  fixture**: `formatAgo()` originally collapsed anything under a minute
  to "just now", but the staleness check fires at 30 seconds — so a
  feed that had actually gone stale 35 seconds ago would show "Stale
  data · last update just now", visibly contradicting itself. Testing
  against a mock fixture (which, unlike a real server, never advances
  its own `generated_at`) surfaced this immediately. Fixed by making
  `formatAgo()` second-resolution ("Xs ago") instead of collapsing
  sub-minute values — this is exactly the kind of thing a live-updating
  health display should be more precise about than the slower-moving
  Prayer Times countdown was.

**Tested entirely against a local mock `server-stats.json` fixture**
(not committed — see `.gitignore`), varying it between requests to
exercise every visual state: healthy/warn/bad memory and temperature
(bar + chart + colour all changed together correctly), healthy/warn/bad
deploy freshness, live vs. stale feed, light and dark theme, and the
home-screen tile. No console errors in any state. Nothing here has
touched the real server yet — `gsuaha-home-server` has no
`server-stats.json`-producing script, so this display will show
"Waiting for data…" on the actual iPad until step 2 is done.

### 2026-08-29 — Server Health: collector script + systemd timer + deploy-marker (step 2 of 3)
Writes the pieces step 1 was waiting on. Nothing here is installed/
running on the actual server yet — that's a manual step (see below) —
so this is "code exists and is verified correct," not "server health
shows real data now."

- **`scripts/server-stats.sh`**: collects uptime, load average, memory,
  disk (root only by default — see the script's own comment for why a
  second `/var/www` row would likely just repeat the same numbers on
  this box), temperature (via `lm-sensors`, degrades to `null` if
  unavailable), three services (`apache2`, `ssh`, the GitHub Actions
  runner — glob-matched the same way the runner's own troubleshooting
  commands did on 29 Aug), Docker containers (skipped entirely if
  `docker` isn't usable), and the last-successful-deploy timestamp —
  then assembles it all with `jq` into `server-stats.json`, written
  atomically (`.tmp` file + `mv`) so the client never reads a
  half-written file mid-update.
  - Deliberately deployed **inside the repo** (`/var/www/cheadle-masjid-display/scripts/`
    after a normal `git push`), not hand-placed on the server outside
    git — editing the script later is just another push, same as
    `index.html`. The *systemd* unit files can't work this way (systemd
    only reads `/etc/systemd/system/`), so those need a one-time manual
    copy — see `systemd/server-stats.service`'s own header comment.
  - Rolling history (`history.cpu_load`/`.memory_percent`/`.temp_c`,
    last 24 samples ≈ 4 minutes at the default 10s interval) persists
    between runs in a dotfile in the script user's home directory, not
    in `server-stats.json` itself across restarts — each run reads the
    previous history, appends, trims to length, writes it back.
  - `temp_c` is deliberately **not** appended to its history array when
    a reading isn't available (`null`) — pushing `null` into the array
    would break the client's sparkline math (plain arithmetic, not
    null-aware) for every point on the chart, not just the missing one.
    Caught and fixed during testing (see below), before this ever ran
    against real hardware.
- **`systemd/server-stats.service` + `.timer`**: a oneshot service run
  every 10s by a timer, `ExecStart` pointing at the *deployed* script
  path (`/var/www/cheadle-masjid-display/scripts/...`) — meaning this
  commit had to reach the server via a normal deploy **before** the
  timer could be installed and start working, not the other way round.
- **`.github/workflows/deploy.yml`**: `server-stats.json` and the new
  `.last-successful-deploy` marker both added to the rsync `--exclude`
  list (same reasoning as `adhan.mp3` — neither is tracked in git, so
  without the exclude, `--delete` would remove them from the live
  server on the very next deploy). A new step, `Record this as the last
  successful deploy`, writes a fresh UTC timestamp to
  `.last-successful-deploy` right after the rsync step — this is what
  the Server Health "Last Successful Deploy" card actually reads, and
  it only runs if the rsync step succeeded (a failed step stops the job
  by default), so the timestamp genuinely means "a deploy completed",
  not just "a job started."

**Verified before touching the real server**: `bash -n` on the script
(syntax only — its own logic uses Linux-only paths like `/proc/loadavg`
that don't exist on macOS, so it can't fully run here); the `jq` history
and final-JSON-assembly logic tested in isolation with simulated inputs
across seven consecutive runs (confirmed correct rolling-window
trimming, and confirmed a null temperature reading is skipped rather
than corrupting the array); the exact JSON the script would produce fed
into the real client in the local preview, confirming full schema
compatibility end-to-end (not just against the earlier hand-written
mock fixture from step 1).

**What's left (manual, on `gsuaha-home-server`, once this commit has
deployed):** install `lm-sensors` and `jq`, run `sudo sensors-detect
--auto`, copy the two systemd unit files into `/etc/systemd/system/`,
`daemon-reload`, `enable --now server-stats.timer`, then confirm
`server-stats.json` appears in the webroot and looks sane before
trusting the iPad's display of it.
