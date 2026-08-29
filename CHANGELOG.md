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
  next prayer's **Begins** time — not Iqamah (changed 29 Aug 2026, see
  the dated entry below) — ticking down every second, with a caption
  above it reading "`<Prayer>` Begins in". This deliberately matches
  what the adhan itself triggers on (`getAdhanTriggerMinutes` in
  `index.html`, also Begins-based) — the countdown and the adhan now
  always agree on what "next prayer" means; they used to be able to
  disagree (countdown tracking Iqamah, adhan firing at Begins), which
  looked odd if you noticed the adhan play well before the countdown
  hit zero. (Full history of the display itself: digital current-time
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
- `#settingsPanel`'s content is **scoped to whichever display is
  active** — Appearance (dark mode) always shows since it's genuinely
  app-wide, but Prayer Times-only sections (Adhan) are hidden on any
  other display via `updateSettingsPanelForScreen()`, called every time
  `showScreen()` switches screens. Any future display's own settings
  should follow the same pattern: wrap them in a section keyed to that
  display's name, hidden by default elsewhere.
- `#settingsPanel` closes **only** via its own ✕ button
  (`#settingsPanelClose`, top-right inside the panel) or by navigating
  to a different screen — tapping elsewhere on the screen while it's
  open does nothing, unlike `#moreMenu`, which still closes on an
  outside tap. Deliberately inconsistent between the two: a popover
  menu (choose Home or Settings) benefits from a quick outside-tap
  dismiss; a settings panel with toggles you might be mid-adjusting
  benefits from requiring an explicit close so an accidental tap
  elsewhere doesn't lose your place.
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
**Status: fully live (confirmed 29 Aug 2026)** — client, collector
script, and systemd timer all installed and producing real data on
`gsuaha-home-server` (uptime, load, memory, disk, temperature, all
three services, deploy freshness, and live Docker containers —
`nextcloud`/`nextcloud_db` — all came back correct on the very first
run). See the dated entries below for the full build history and
reasoning.
- Second tablet screen (`#serverScreen`), purple accent throughout
  (heading, memory bar, chart lines — deliberately not the same
  teal-emerald as Prayer Times, so the two displays read as visually
  distinct at a glance, including from the home screen tile).
- Polls a same-origin `server-stats.json` every 10s (`fetchServerStats()`,
  same resilient pattern as the prayer-time fetch: falls back to the
  last-known-good response in `localStorage` on failure, never clears
  the screen just because one poll failed).
- Cards: Uptime; **CPU** (usage %, + trend chart, with load average and
  core count as supporting text — usage % is the headline number since
  it's more intuitive than load average alone, which only makes sense
  once you know the core count); Memory (+ bar + trend chart, with swap
  as supporting text); Temperature (+ trend chart); Disk (per mount);
  Services (per-service active/inactive dot — now also includes **DNS
  Resolution** and **Internet** as two more rows, see below); **Network**
  (down/up throughput + trend chart); **Maintenance** (pending package
  updates, reboot-required flag); **Last Successful Deploy** (age since
  the runner's last successful job — not just "is the runner process
  running", which the 29 Aug DNS outage proved doesn't actually tell you
  whether deploys are working); Containers.
- **Connectivity is two separate checks, not one**: DNS Resolution
  (`getent hosts github.com`) and Internet (`ping` a raw IP, `1.1.1.1`,
  bypassing DNS entirely) are deliberately independent — the 29 Aug
  outage was exactly a case where DNS was broken but the network route
  itself was fine, and one combined "internet: yes/no" flag would have
  hidden that distinction. Both render as ordinary rows in the existing
  Services card (no new card needed — they're just more entries in the
  same `services` array, active/inactive like any other service).
- Trend charts (`renderSparkline()`) are small hand-built inline-SVG
  line+area charts reading a short rolling `history` array per metric
  (`history.cpu_load`, `.cpu_percent`, `.memory_percent`, `.temp_c`,
  `.network_kbps` — oldest first) — no charting library, consistent
  with the rest of this app. Colour follows the same warn/bad
  thresholds as the metric's own bar/text (memory/temp ≥70% or
  ≥90%-equivalent turn amber/red); CPU usage and network throughput
  charts are deliberately left neutral, since "too high" for either
  depends on context (core count; what's normal for this connection)
  that isn't tracked, so no threshold is invented for either.
- Service/container status dots are **iOS systemGreen/systemRed**
  (`#34c759`/`#ff3b30` light, `#30d158`/`#ff453a` dark) — deliberately
  not the same green as Prayer Times' accent or this screen's purple;
  reads as a distinct "terminal/systemd status" signal (think
  `systemctl status`'s "active"/"failed"), universal green=good/red=bad
  regardless of which display it's on.
- Staleness (`generated_at` more than 30s old, **or** the last poll
  failed — catches both "the collector script died" and "the network
  request failed" as the same "don't trust this" state) is shown by
  colouring the header's own **"Updated Xm ago"** line amber — there is
  **no separate bottom-of-screen banner** any more (removed 29 Aug
  2026, see the dated entry below; it duplicated the header line
  exactly).
- **Grid is CSS Grid, not flexbox-with-per-card-margins** — 2 columns
  in portrait, 4 in landscape (`@media (orientation: landscape)`), wide
  cards (`.statCardWide`) always `grid-column: span 2`. `#statGrid`
  itself is a flex child of `#serverScreen` with `flex: 1;
  min-height: 0; overflow-y: auto;` — a safety net (not the primary
  fix) so content can never be silently clipped by the page's usual
  `overflow: hidden` again, however many cards this grows to later.
- `server-stats.json` is `.gitignore`'d, same treatment as `adhan.mp3` —
  it's server-generated state, not app code, and must never be
  committed or wiped by a deploy (added to the rsync exclude list once
  the server-side script exists).

### Bin Day display
**Status: fully live (confirmed 29 Aug 2026).** Third tablet screen
(`#binScreen`), iOS-blue accent (`#007aff` light / `#0a84ff`–`#409cff`
dark) — deliberately distinct from Prayer Times' teal-emerald and
Server Health's purple, same "each display gets its own colour" rule.
- **Deliberately zero live fetching — no backend, no XHR at all.**
  Stockport Council's own bin-day lookup
  (`forms.stockport.gov.uk/bin-collections`) is a multi-step,
  session-based form with no public JSON API, so scraping it reliably
  would need real backend infrastructure this project has otherwise
  avoided everywhere. UK bin collections instead follow a fixed
  recurring pattern, so the pattern itself is hardcoded
  (`BIN_ROTATION_REFERENCE` / `BIN_ROTATION` / `BIN_LABELS`) and the
  schedule is computed client-side with plain date math
  (`computeBinSchedule()`), the same "derive it live from the clock"
  philosophy already used for the countdown and day-rollover logic.
- **The verified rule** (collection day: every Monday; round "21A"):
  the **green** bin is collected every single Monday with no
  exceptions, plus a 4-week rotation that layers on extra bins:
  week 0 adds **black**, week 1 adds **blue + brown**, week 2 adds
  **black**, week 3 adds nothing (green only). Anchored to Monday 5
  Jan 2026 as a confirmed "week 0" (black) week.
- **How this was verified**: checked directly against Stockport
  Council's own published calendar for round 21A (covering April 2025
  – September 2026) across every date from January–September 2026 — 9
  months, zero exceptions — then cross-checked against the live
  per-property "next collections" lookup for a date *beyond* the
  printed calendar's own range (21 September 2026, predicted
  blue+brown), which matched exactly. Stockport's site states its bin
  data is published under the **Open Government Licence** (checked
  directly on their `/terms-and-conditions` page), which explicitly
  permits this kind of reuse — a materially different, more permissive
  situation than the Cheadle Masjid data-usage risk noted below.
- **This rule needs manual re-verification if Stockport ever changes
  round 21A's schedule** (their own calendar notes at least one past
  frequency change, May 2025) — the app has no way to detect that on
  its own; if collections stop matching what's shown, re-derive the
  rotation from an updated council calendar rather than assuming the
  hardcoded rule still holds indefinitely.
- The home address used to look up which round/day applies is
  deliberately **not stored anywhere in this repo or its docs** — only
  the resulting anonymous schedule pattern above is committed.
- `#binNextCard` shows the next upcoming collection: a static
  **"Next Collection"** label (not "Next Collection In" — fixed 30 Aug
  2026, see the dated entry below, since that read as broken English
  once combined with "Tomorrow") above the big value ("Today" /
  "Tomorrow" / "In N days"), the date, and coloured bin chips;
  `#binCard`/`#binRows` lists the following 5 upcoming Mondays. Reuses
  the same overflow-safety CSS pattern as Server Health's `#statGrid`
  (`flex: 1; min-height: 0; overflow-y: auto`), tested at both iPad
  orientations before shipping given the earlier real overflow bug.
- Rendered every tick (`renderBinDay()`, called unconditionally from
  `tick()` and once at boot) — cheap, since it's just date math and a
  handful of `textContent`/`innerHTML` writes, not an XHR.

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
  exactly why the automatic nightly reload was removed. If that very
  first tap ever fails to unlock (for any reason), the listeners stay
  attached and the *next* tap retries — fixed 29 Aug 2026, see the dated
  entry below; previously a single failed first attempt broke this for
  the rest of that page session, silently.
- **"Is the adhan actually going to play right now" is checkable at a
  glance** (added 29 Aug 2026), not just something that fails silently
  at the scheduled moment: the small speaker icon next to any armed
  prayer turns amber instead of its normal accent-green colour while
  audio isn't unlocked yet, and Settings' Adhan section has an explicit
  "Audio: Ready" / "Audio: Not ready — tap the screen once" line.
- A full-screen green alert appears while the adhan plays (scheduled or
  via Test), naming the prayer, with a pulsing speaker icon and a "Tap
  anywhere to stop" hint. Tapping it stops the audio and dismisses the
  alert; it also auto-dismisses when the adhan finishes on its own.
  Styling is fixed/theme-independent, sits above all other UI (z-index).
- **No "Playing (Prayer)…" status text** in Settings any more (removed
  29 Aug 2026 — see the dated entry below) — the full-screen alert
  already says which prayer is playing while it's actually playing, so
  a second status line in Settings was redundant, and it used to be set
  once on a successful `play()` and never cleared, so it could outlive
  the adhan itself indefinitely. `#adhanStatus` is still used, just for
  genuine problems (blocked by the browser's autoplay policy, or
  `adhan.mp3` missing) — both `stopAdhanAndHideAlert()` (manual tap-to-
  stop) and the audio's `ended` event now explicitly clear it, and a
  *new* successful play also clears any leftover error text from an
  earlier attempt, so nothing in that status line can ever describe a
  state that's no longer true.

### Deployment (current, live)
- **Primary path — automated**: push to `main` on GitHub → a
  self-hosted GitHub Actions runner installed on the Linux home server
  (`gsuaha-home-server`, `192.168.0.180`) picks up the job → checks out
  the commit → `rsync`s it into `/var/www/home-dashboard-hub`
  (excluding `.git`, `.github`, `adhan.mp3`). Runs as a systemd service
  under the `gsuaha` user. See `.github/workflows/deploy.yml`.
- **Fallback path — manual**: the original bare git repo
  (`~/git/home-dashboard-hub.git`) + `post-receive` hook
  (`GIT_WORK_TREE=/var/www/home-dashboard-hub git checkout -f main`)
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

### Known risks (unresolved, not yet acted on — surface if this comes up)
- **Prayer Times' data usage likely conflicts with Cheadle Masjid's own
  published Terms & Conditions.** Their site's `/terms-conditions/`
  page (checked directly, not assumed) permits using material from the
  site for personal, informational viewing only — explicitly **not**
  "reproduction on any other website" — and separately prohibits
  copying, storing, or transmitting any part of the site to a third
  party without written permission; it also asks that even *linking* to
  the site be notified/approved first. This app fetches
  `wp-json/dpt/v1/prayertime` (a technically-open, unauthenticated
  WordPress REST endpoint) every 5 minutes and reproduces the data on a
  separate display — which is exactly the kind of use those terms
  don't permit, regardless of the endpoint being fetchable without
  authentication. **This was identified in conversation on 29 Aug 2026
  and never acted on** — no permission has been sought from the masjid
  (CMA Welfare Trust), and the fetch has not been paused. The
  recommended next step, discussed but not yet done: contact the masjid
  and ask for explicit permission to use their prayer-time data for
  this personal display — their own terms literally invite this
  ("notify and seek the CMA's approval"). Don't treat "it's a public
  GitHub project and has been running fine" as evidence this is
  resolved; it isn't, it just hasn't been raised with them yet.

### Known trade-offs (intentional, don't "fix" without discussion)
- No automatic page reload → a pushed code change only takes effect once
  someone manually reopens the app on the iPad (exits Guided Access,
  taps the icon again). This was a deliberate choice over losing the
  audio-autoplay unlock on every reload.
- The whole page is plain ES5 JavaScript (no `fetch`, arrow functions,
  `let`/`const`, or CSS variables) — a holdover from Tab 3 support that's
  no longer strictly necessary on the iPad, but left as-is since
  rewriting it would be pure churn with no functional benefit.
- **Repo/folder/server path renamed to `home-dashboard-hub`** (29 Aug
  2026, see the dated entry below) — was `cheadle-masjid-display` since
  this project's original single-purpose start; deferred at the time of
  the first multi-display change specifically to avoid touching the
  live deployment pipeline mid-build, done properly once two displays
  actually existed and before adding a third.

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

### 2026-08-29 — Server Health: installed and verified live (step 3 of 3)
The manual server-side install from step 2, done and confirmed working
first try:
- `jq`/`lm-sensors` were already installed on this box; `sudo
  sensors-detect --auto` found both a CPU package sensor (`coretemp`)
  and a motherboard Super I/O chip (`nct6775`) on this Intel NUC5i5RYB —
  the script's "grab the first `_input` value" approach happened to
  land on a sensible reading (`61°C`) without needing to target a
  specific chip/label, so no adjustment to the script's temperature
  line was needed after all.
- `gsuaha` added to the `docker` group so the container list would
  populate — worth noting *why* this took effect immediately without a
  fresh login (which group-membership changes normally need): the
  script runs as a fresh process spawned by systemd each time the timer
  fires, and systemd resolves group membership from `/etc/group` at
  that process's own launch, not inherited from whatever shell session
  happened to add the user to the group. An already-open interactive
  shell would still need a re-login to see the new group; a systemd
  timer's next tick doesn't.
- Systemd unit files copied to `/etc/systemd/system/`, `daemon-reload`,
  `enable --now server-stats.timer` — `systemctl status` showed
  `active (waiting)` with a ~10s trigger countdown immediately, and
  `server-stats.json` had fresh, sane, real numbers on the very first
  read (not zeros/nulls/placeholder-looking data): real uptime, real
  load average, real memory (7822 MB total — the actual RAM on this
  box, not the round 7900 used in step 1's mock fixture), a real
  `last_successful_deploy` timestamp matching the commit that had just
  deployed, and two real running containers (`nextcloud`,
  `nextcloud_db`) neither of which were anticipated by name in advance
  — confirming the container-listing code generalizes correctly to
  whatever's actually running, not just what was tested against.
- Real data surfaced one genuinely useful finding this whole feature
  was built to surface: root disk at **73% full (37/54 GB)** on a box
  also running Nextcloud — not an emergency, but worth keeping an eye
  on, and a concrete example of why this display is worth having.
- One follow-up flagged, not yet confirmed either way: whether
  `coretemp`/`nct6775` are written to `/etc/modules` for auto-load on
  boot (`sensors-detect --auto`'s last prompt), or only loaded for the
  current boot — temperature reads correctly *right now* regardless,
  this only matters for whether it still does after the server's next
  reboot.

**All three steps of the Server Health build are now done.** Full
schema, card list, and architecture reasoning stay documented above and
in ARCHITECTURE.md's "Data flow: Server Health" section — this entry is
the record of what got installed and confirmed, not a new design.

### 2026-08-29 — Verified the live iPad's data source; scoped Settings per-display; Settings now closes only via ✕
Three small, unrelated fixes from the same conversation, after Server
Health went live.

**Verified the live pipeline, not just the local preview**: fetched
`http://192.168.0.180/server-stats.json` and `/index.html` directly
from outside the iPad — confirmed the deployed page is current (title,
markup) and the JSON it's pulling is genuinely fresh (`generated_at`
within seconds, full 24-point history, real containers) — rather than
only trusting the local `bash -n`/isolated-jq/local-preview testing
from the step 2/3 entries above. Didn't (couldn't) see the physical
iPad's screen itself — that's a real limitation, not skipped out of
laziness — but everything upstream of the glass is confirmed correct.

**Settings panel content is now scoped per-display**: user noticed
Prayer Times' Adhan toggles were showing up in Settings while on the
Server Health screen, where they mean nothing. Fixed by wrapping the
Adhan section in `#adhanSettingsSection` and adding
`updateSettingsPanelForScreen()` (hides it unless
`currentScreen === "prayer-times"`), called from `showScreen()` so it
stays correct on every screen switch regardless of whether Settings
happens to be open at the time. Appearance (dark mode) stays visible on
every screen — it's a genuinely app-wide setting, not display-specific.

**Settings panel now closes only via an explicit ✕**: previously,
tapping anywhere outside `#settingsPanel` closed it, same as
`#moreMenu`. User asked for this specifically to stop working that way
for Settings (a toggle-heavy panel someone might be mid-adjusting, where
an accidental outside tap losing your place is worse than for a simple
Home/Settings picker menu) — added `#settingsPanelClose` (a small ✕
button, top-right inside the panel, Material's "close" glyph) and
removed the settingsPanel branch from the outside-click handler.
`#moreMenu` is intentionally left as-is, still closing on an outside
tap — the inconsistency between the two panels is deliberate, not an
oversight, and shouldn't be "fixed" into consistency without asking.

Verified in the local preview: Prayer Times' Settings still shows
Appearance + Adhan; Server Health's Settings shows Appearance only, no
Adhan section at all; tapping elsewhere on the screen while Settings is
open no longer closes it (confirmed by an explicit outside-tap test);
the ✕ closes it correctly; switching back to Prayer Times and reopening
Settings shows Adhan again (`adhanSettingsSection.style.display`
confirmed back to visible via direct inspection, not just eyeballing);
`#moreMenu`'s own outside-tap-to-close behaviour is unchanged; dark mode
still recolours the new ✕ button correctly; no console errors beyond
the known/expected missing-`adhan.mp3` 404 in the local test folder.

### 2026-08-29 — "Choose a Display" heading: plain black/white
`#homeTitle` was the same accent colour as each theme's other headings
(`#0b7a5c` light / `#4de3ac` dark, matching `#masjidName`) — changed on
request to plain `#000000` light / `#ffffff` dark instead, so the home
screen's own heading doesn't read as "belonging" to either display's
accent colour (green for Prayer Times, purple for Server Health) now
that two exist with distinct colours. Verified in both themes in the
local preview.

### 2026-08-29 — Fixed stale "Playing (Prayer)…" text after testing the adhan
User reported: tap a prayer's Test button, the full-screen alert shows
and plays the adhan, tap to stop it — and "Playing (Dhuhr)…" (or
whichever prayer) stays showing in Settings' Adhan section indefinitely,
even though nothing is playing any more.

**Root cause**: `playAdhanFile()`'s success path set that text once
(`onStatus("Playing (" + label + ")…")`) right as the alert opened, but
nothing anywhere ever cleared it — not stopping the alert manually, not
the audio finishing on its own. It wasn't a background timer or a
leftover interval still running (checked for that explicitly, per the
request to make sure nothing was) — simpler than that: a one-way
`textContent` assignment with no corresponding "clear" ever written.

**Fix**: removed the "Playing…" status line entirely, since the
full-screen alert already communicates that same information while it's
actually true. Added explicit clearing in the two places playback
actually stops — `stopAdhanAndHideAlert()` (manual tap) and the audio's
`ended` event, which now calls `stopAdhanAndHideAlert()` too instead of
a separate, slightly different `hideAdhanAlert()`-only path, so both
"stopped it myself" and "it finished on its own" go through identical
cleanup rather than two versions that could drift apart later. Also
clear any *leftover error* text (e.g. an earlier "blocked by browser"
message) the moment a later attempt actually succeeds — the status line
should never describe a problem that's already been resolved.
`#adhanStatus` is still used for real, current problems (autoplay
blocked, `adhan.mp3` missing); only the redundant, ended-up-becoming-
stale "Playing" message was removed.

**Verified without a real `adhan.mp3`** (none in this sandbox, and no
`ffmpeg`/`sox` available to fabricate a playable one) by exercising the
*actual* fixed code paths directly rather than skipping verification:
seeded `#adhanStatus` with the exact stale text the bug produced and
the alert open, then invoked the real `adhanAlert.onclick` handler (the
same one a tap triggers) and confirmed it now clears the text and
closes the alert; separately dispatched a real `ended` event on the
audio element and confirmed the same cleanup fires. Also clicked an
actual Test button end-to-end — hits the pre-existing, unrelated
"blocked by browser" autoplay-policy path (expected, since a
script-triggered click isn't a genuine user gesture), confirming the
error-message path still works and "Playing" never appears anywhere.
No new console errors.

### 2026-08-29 — Server Health: six new stats (user felt the display "looked quite little")
Added, all user-selected from a menu of options: an internet/DNS
connectivity check, CPU core count + real usage %, swap usage, network
throughput, and two maintenance flags (pending updates, reboot
required).

**Schema changes** (`scripts/server-stats.sh` + client both updated
together, no external consumers to keep compatible with):
- `load_avg` moved from top-level into a new `cpu` object alongside it:
  `cpu: {cores, percent, load_avg}`.
- New top-level `swap: {used_mb, total_mb, percent}` (0%, not null,
  when no swap is configured — that's a normal setup, not missing data).
- New top-level `network: {interface, rx_kbps, tx_kbps}`.
- New top-level `maintenance: {reboot_required, updates_available}`.
- `services` array gained two more entries: `dns` (DNS Resolution) and
  `internet` (Internet) — rendered by the exact same generic
  `renderStatRows()` the other services already use, no new rendering
  code needed for these two.
- `history` gained `cpu_percent` and `network_kbps` alongside the
  existing three series.

**CPU % and network throughput are both computed from cumulative
counters, not point-in-time readings** — `/proc/stat` (CPU ticks) and
`/proc/net/dev` (bytes) only make sense as *deltas* between two
samples, so the script now persists one extra state file between runs
(`~/.server-stats-prev-sample`: timestamp + previous counters) purely
for this, separate from the existing rolling-history file. First run
after this deploys (or after that file is ever deleted) has nothing to
diff against, so `cpu.percent`/`network.rx_kbps`/`network.tx_kbps` come
back `null` for exactly that one run — verified the client already
handled this correctly (shows "--", draws no chart, no crash) before
ever touching the real server, since the exact same "first sample" case
already existed for temperature history in the original build.

**Network interface is auto-detected**, not hardcoded — `ip route show
default` finds whichever interface actually carries the default route,
rather than assuming `wlp2s0` specifically (true on this box today, but
no reason to bake that in when the check to find it properly is one
line).

**Pending updates check is cached for an hour** (`apt list
--upgradable`, itself just reading already-fetched local package lists,
no network call) — it can only change after an `apt update` runs, so
checking it fresh every 10 seconds would be pure waste. Cache file's own
mtime is the "how old is this" check, no extra bookkeeping needed.

**Connectivity check is deliberately two separate booleans**, not one
— `dns_ok` (`getent hosts github.com`) and `internet_ok` (`ping` a raw
IP, `1.1.1.1`, which can't be affected by a DNS problem). This directly
mirrors the 29 Aug outage, where DNS was broken but the network route
itself was fine — a single combined flag would have hidden exactly the
distinction that mattered that day.

**Verified without deploying to the real server first**: the new awk
one-liners (CPU% delta math, network rate math, divide-by-zero and
negative-delta guards for a counter reset) tested standalone with
known inputs and confirmed exact expected outputs; the extended jq
history/final-JSON logic tested in isolation across multiple simulated
runs including the first-run-null case; the exact resulting JSON shape
fed into the real client in the local preview and visually confirmed
for every new card, including forcing each maintenance state
("Up to date" vs "N updates" vs "Reboot required") and the all-null
first-run state, in both themes. No console errors in any state. Only
after all of that did this get committed and pushed — the actual
server picks up the new script automatically via the existing deploy
pipeline, no manual re-install needed this time (unlike the original
Server Health build, this change is pure script content, not new
packages or systemd units).

### 2026-08-29 — Fixed the adhan silently not playing at Iqamah time
User reported the adhan not playing even with a prayer's toggle on in
Settings. Worth stating plainly first, separate from the bugs below:
**the adhan is designed to play at each prayer's *Begins* time, not
Iqamah** (matches real masjid practice, and is what the README already
documented) — if it was actually firing correctly at Begins and just
being looked for at Iqamah instead, that gap (often 20–40 minutes) could
easily look like "it didn't play." That said, code review turned up two
real bugs independent of that distinction, both making a genuine
failure *invisible* rather than just mistimed:

1. **A failed first audio-unlock permanently broke every future
   scheduled adhan, silently.** `unlockOnceHandler` (attached to the
   very first tap/click after each page load) removed its own event
   listeners unconditionally, regardless of whether
   `unlockAudioOnce()`'s `audio.play()` actually succeeded.
   `unlockAudioOnce()` already reset `audioUnlocked` back to `false` on
   failure specifically so a *later* tap could retry — but with the
   listeners already gone, nothing was ever left to give it that later
   tap. One failed first-ever tap (for any reason — a slow load, a
   wrapper app quirk, anything) meant audio stayed locked for the rest
   of that page session, with zero indication anywhere.
2. **The real, scheduled adhan trigger passed no status callback at
   all.** `checkAdhanSchedule()` called `playAdhanFile(label, null)` —
   `null`, not `setAdhanStatus`. The Settings "Test" buttons always
   passed a real callback and so always showed a clear error on
   failure; the actual scheduled path at prayer time did not, so a
   blocked-autoplay or missing-file failure there produced literally no
   evidence anywhere that anything had gone wrong.

**Fix**: `unlockAudioOnce()` now only removes its listeners from inside
the confirmed-success branch of the promise it's already using — a
failed attempt leaves them attached so the next tap tries again.
`checkAdhanSchedule()` now passes `setAdhanStatus`, the same real
callback the Test buttons use, so a scheduled failure shows up in
Settings exactly like a Test failure would. Also added a persistent,
proactive readiness signal so this doesn't have to be diagnosed only
after a missed prayer: the little speaker icon next to any armed prayer
row is amber instead of green while audio isn't unlocked yet
(`updateAdhanReadyIndicators()`, re-applied every time the table
re-renders and every time the unlock state changes either way), plus an
explicit "Audio: Ready" / "Not ready — tap the screen once" line in
Settings' Adhan section.

**A second, more serious bug was introduced by this fix itself, and
caught only by directly testing the retry path — not by re-reading the
code.** Moving the listener-removal into `unlockAudioOnce()` meant that
function needed to reference `unlockOnceHandler` — but `unlockOnceHandler`
was declared *nested inside* `initAdhanUI()`, a different, inner
function scope that `unlockAudioOnce()` (declared at the outer,
top-level scope) cannot see. Calling `removeEventListener(...,
unlockOnceHandler, ...)` from inside `unlockAudioOnce()` therefore threw
a `ReferenceError` — which, being thrown inside a `.then()` callback,
turned into a *rejected* promise and landed in the adjacent `.catch()`,
which resets `audioUnlocked` back to `false`. Net effect: every
successful unlock attempt would have been silently converted into an
apparent failure — worse than the original bug, since now *no* tap
would ever successfully unlock audio, not just a first failed one.
Fixed by moving `unlockOnceHandler`'s declaration to the same top-level
scope as `unlockAudioOnce()`. This is exactly why the verification
below tests the actual retry *behaviour* end-to-end rather than just
reading the diff and trusting it looked right.

**Verified by directly exercising the real code paths** (no real
`adhan.mp3` in this sandbox to test genuine playback): stubbed
`audio.play()` to reject, dispatched a real `click` event on `document`,
confirmed the icon/status correctly showed "not ready"; stubbed
`audio.play()` to then resolve and dispatched a second real click,
confirming this — the retry — actually reaches the success branch (this
is the exact test that caught the `ReferenceError` above, via a
`MutationObserver` on the icon's `class` attribute plus a global
`unhandledrejection` listener, since the failure was otherwise
completely silent); confirmed a third click, after unlock is already
true, doesn't call `audio.play()` again at all. No console errors in
the final state. `checkAdhanSchedule()`'s fix wasn't separately
re-tested live (simulating an exact-minute trigger is impractical) —
it reuses the exact `playAdhanFile()` + `setAdhanStatus` path the Test
buttons already exercise successfully, so no new behaviour needed
proving, just the wiring change itself (confirmed by reading the diff).

### 2026-08-29 — Countdown now tracks Begins, not Iqamah
Follow-up to the adhan investigation above: once it was confirmed the
adhan fires at each prayer's **Begins** time (by design, kept as-is),
user asked for the on-screen countdown to match that, rather than
continuing to count down to Iqamah. Previously the two could
legitimately disagree — the adhan already firing at, say, Dhuhr's
Begins (1:11pm) while the countdown still read "Dhuhr Iqamah in 24:00"
— which is exactly the kind of mismatch that made the adhan look like
it fired "early" or "wrong" even when it was working correctly.

- `findNextTarget()`: now reads `rows[i].begins` instead of
  `rows[i].iqamah` when picking which prayer is "next" and how many
  minutes away it is. The tomorrow-Fajr fallback (nothing left today)
  switched from `data.tomorrow.fajr_jamah` to `data.tomorrow.fajr_begins`
  — confirmed this field actually exists in the real API response
  (fetched it live) before relying on it, same parallel Begins/Jamah
  structure as every other field.
- Caption text changed from "`<Prayer>` Iqamah in" to "`<Prayer>`
  Begins in" (`renderCountdown()`).
- **Real behavioural change worth being explicit about**: once a
  prayer's Begins time passes, the countdown now immediately moves on
  to the *next* prayer's Begins — it no longer lingers on the current
  prayer counting down to its Iqamah. E.g. between Dhuhr's Begins
  (1:11pm) and its Iqamah (1:35pm), the display now reads "Asr Begins
  in" rather than "Dhuhr Iqamah in ~10 min" — the Iqamah times are
  still shown as their own column in the table, just no longer drive
  the big countdown or the "next prayer" row highlight.
- Friday's Jumu'ah row is unaffected in how it's special-cased
  (`begins` still maps to `fri.zuhr_jamah`/"1st Khutbah",
  `iqamah` to `fri.asr_mithl_1`/"2nd Khutbah") — the countdown will
  count down to the "1st Khutbah" time for that row now, consistent
  with treating `begins` as the generic "this is what counts down"
  field regardless of what it's labelled per-row.

**Verified against real data, not just logic review**: fetched the
masjid's live API directly to confirm `data.tomorrow.fajr_begins`
exists before relying on it; confirmed the countdown correctly reads
"Maghrib Begins in" matching real current time against the real
Maghrib Begins field; then verified the actual behavioural change (not
just the label) by patching `Date` to a fixed simulated time
(1:20pm — after Dhuhr's Begins, before its Iqamah) and confirming the
countdown correctly skipped ahead to "Asr Begins in 01:15:00" rather
than continuing to show Dhuhr — the exact scenario that couldn't be
exercised just by waiting for real time to pass during testing. No
console errors; dark theme re-checked too.

### 2026-08-29 — Removed the duplicate footer; fixed a real content-overflow bug on the iPad
User asked to remove the "Live/Stale · updated..." text at the bottom
of Server Health (duplicated the "Updated Xm ago" already shown top-
right) and reported the bottom card looking wrong — too close to the
edge, uneven gap. Testing turned up something more serious than
uneven spacing.

**Footer removed.** `#serverFooter` (element, CSS, and the
`setServerFooter()` function) deleted entirely. The stale/live signal
it carried isn't lost, just relocated: `#serverUpdatedLine` (top-right)
now takes an amber `.stale` class under the same conditions the footer
used to check, so that information still exists, just without a second
copy of it at the bottom.

**The real bug, found by testing at actual iPad dimensions, not just
the wide desktop-shaped preview used throughout this whole feature's
development**: in landscape orientation (1194×834), the 10-card grid's
real content height was **1025px against an 834px viewport** —
confirmed via `scrollHeight` vs. `clientHeight`, not eyeballed — so the
entire bottom row (Last Successful Deploy, Containers) and part of the
row above it were **completely invisible**, silently clipped by this
app's usual `overflow: hidden`. What looked like "proportions are off"
from a screenshot was actually real, inaccessible data. Portrait
(834×1194) had no overflow at all — plenty of spare room — which is
exactly why this was never caught earlier: every previous test and
screenshot in this whole Server Health feature happened to use a
portrait-shaped or otherwise generously-tall viewport.

**Two fixes, not one**:
1. `#statGrid` now uses **CSS Grid** instead of flexbox with per-card
   margins — `repeat(2, 1fr)` normally, `repeat(4, 1fr)` in landscape
   (`@media (orientation: landscape)`), `gap` for spacing instead of
   hand-rolled margins. 4 columns repacks the same 10 cards into 3 rows
   instead of 6 (Uptime/CPU/Memory/Temperature share a row; Disk +
   Services, each still `grid-column: span 2`, share the next; Network/
   Maintenance/Last Successful Deploy/Containers share the third) —
   comfortably fits landscape without needing to scroll at all.
   Containers changed from a wide card to a regular one specifically so
   it pairs evenly with Last Successful Deploy in portrait's 2-column
   layout too, rather than being the one card stranded alone on its own
   row with empty space beside it.
2. `#statGrid` also got `flex: 1; min-height: 0; overflow-y: auto;` —
   a **safety net**, not the primary fix: if this grid ever grows past
   whatever screen it's on again (more cards added later, a different
   device), it scrolls instead of silently hiding data the way it just
   did. `min-height: 0` is the standard fix for a flex child that
   otherwise refuses to shrink enough to let its own `overflow-y`
   actually engage.
- `gap`-based spacing also fixed the smaller issue actually reported:
  the old per-card margin approach gave every card its own bottom
  margin but the grid itself no equivalent top-side allowance, so the
  last row sat measurably closer to the screen edge than the header sat
  to the top. Confirmed via direct measurement this is now exact: header
  top offset and grid bottom offset both computed to the identical
  25.02px (landscape, 3vh of 834px) and 35.81px (portrait, 3vh of
  1194px) — not just visually close, the same number.

**Verified at actual iPad dimensions in both orientations** — this is
the key change in testing method here, not just the fix: every stat-
card test up to this point had used the pane's own default/desktop-
shaped viewport, which is exactly why a real device-specific overflow
bug went unnoticed through several rounds of Server Health work.
Confirmed via `scrollHeight`/`clientHeight` that neither orientation
needs to scroll with the current 10 cards; confirmed the exact
symmetric top/bottom offsets above; confirmed dark theme; no console
errors.

### 2026-08-29 — Renamed the project: cheadle-masjid-display → home-dashboard-hub
User asked to finish this before adding a third display, rather than
let it keep accumulating displays under the original single-purpose
name (deferred back when Server Health was first added — see that
entry's "Repo/folder/server path" note, and the equivalent note in
README.md/ARCHITECTURE.md at the time). Every layer, in order:

1. **Server directory**: `sudo mv /var/www/cheadle-masjid-display
   /var/www/home-dashboard-hub`.
2. **Apache vhost** (`/etc/apache2/sites-available/cheadle-display.conf`
   — the vhost *file's own name* wasn't changed, only its
   `DocumentRoot`/`Directory` paths inside it, since Apache doesn't care
   what the `.conf` file itself is called): both paths updated,
   `apache2ctl configtest` clean, reloaded.
3. **Bare repo** (manual-fallback deploy path): `post-receive` hook's
   `GIT_WORK_TREE` updated to the new path, then the bare repo directory
   itself renamed, `~/git/cheadle-masjid-display.git` →
   `~/git/home-dashboard-hub.git`.
4. **This repo's own tracked files**: `.github/workflows/deploy.yml`
   (rsync destination + the deploy-marker step), `systemd/server-stats.service`
   (`ExecStart` path), `scripts/server-stats.sh` (`OUT_FILE`/
   `DEPLOY_MARKER`), and README.md/ARCHITECTURE.md's setup instructions
   and system-overview diagram — all updated to the new path/name.
   Historical dated entries above this one were **not** rewritten —
   they're an accurate record of what was true when they were written,
   including the old name; only the "Current baseline" sections were
   brought up to date, per this file's own stated policy.
5. **GitHub repo**: renamed via Settings → repository name. GitHub
   keeps the old URL redirecting for git operations, but the local
   `origin` remote was pointed at the new URL explicitly anyway rather
   than relying on the redirect indefinitely.
6. **Local Mac folder**: `~/Desktop/cheadle-masjid-display` →
   `~/Desktop/home-dashboard-hub`, done last, once every commit
   referencing the old path had already been pushed successfully from
   the old location.
7. **`systemd/server-stats.service`** re-copied to
   `/etc/systemd/system/` on the server (its `ExecStart` path changed,
   so the already-installed copy from before the rename was now stale)
   and `daemon-reload`'d.

**Sequencing was the actual engineering here, not the renames
themselves**: steps 1–3 (server-side) had to land *before* pushing step
4's `deploy.yml` change, since that change makes the very next deploy
rsync into the new path — pushing it first would have had the runner
try to sync into a directory that didn't exist yet. Verified after each
push (`curl`ing the live server directly, same pattern used throughout
this project) rather than assuming the rename "worked" once the commands
ran without error.

### 2026-08-29 — Made the DNS fix permanent (root-caused, not just patched)
The 29 Aug DNS outage (ARCHITECTURE.md's "A 'healthy' service that
couldn't actually do anything") was only fixed live at the time —
deliberately not made permanent, since the actual reason `wlp2s0` had
no DNS server wasn't confirmed. Root-caused before writing any
persistent config, not guessed at:

- `wlp2s0` turns out to be managed entirely by **NetworkManager**, not
  netplan — its netplan wifi file is genuinely empty (`wifis: {}`); the
  WiFi connection profile ("SKYTTBBB") lives only inside
  NetworkManager's own connection store.
- `/etc/NetworkManager/NetworkManager.conf` had no explicit `dns=`
  setting under `[main]` — left to an implicit default, which is
  exactly the kind of thing that can misbehave silently after a
  reconnect/sleep-wake without ever showing up as a "broken config" on
  inspection (the connection's own DNS looked fine — `nmcli connection
  show SKYTTBBB` reported `192.168.0.1` correctly — it just wasn't
  reliably making it into `systemd-resolved`).
- `/etc/systemd/resolved.conf` had **no `FallbackDNS` configured at
  all** — not deliberately empty, just never set, so there was
  genuinely nothing to fall back to if the primary registration ever
  dropped again.

**Fix, two parts, matching the two gaps found**: `sudo sed -i
'/^\[main\]/a dns=systemd-resolved' /etc/NetworkManager/NetworkManager.conf`
(the likely actual cause) and `sudo sed -i '/^\[Resolve\]/a
FallbackDNS=1.1.1.1 8.8.8.8' /etc/systemd/resolved.conf` (a safety net
regardless of cause — same "fix the likely cause, add a safety net
anyway" approach as the Server Health grid overflow fix). Both services
restarted (`NetworkManager`, `systemd-resolved`) to apply.

**Verified, not assumed**: `resolvectl status` for `wlp2s0` now shows
`Current Scopes: DNS` with `+DefaultRoute` (previously `none`/
`-DefaultRoute` — this is the specific flag that was missing before);
`resolvectl query broker.actions.githubusercontent.com` (the exact
hostname that failed during the original outage) resolved successfully;
the live Server Health display's own "DNS Resolution" and "Internet"
service rows both show active, using the server's own real self-check
rather than a one-off manual query. This is a config file change, not a
live command — confirmed to persist across the reboot in the next
entry, not just assumed to.

One caveat worth being upfront about: restarting `NetworkManager` over
an SSH session on a WiFi-connected box risks briefly dropping the
connection — flagged to the user before running it, since a server with
no other access path could theoretically need physical/console
recovery if it didn't reconnect on its own (it did, without issue).

### 2026-08-29 — Rebooted the server: confirmed everything survives, not just assumed to
The actual point of doing this now rather than whenever the pending
kernel update got dealt with eventually: every fix made today (DNS,
temperature sensor modules, the project rename) needed to be proven to
survive a real reboot, not just trusted because the config file looked
right. Full checklist run after the reboot came back up:

- **DNS**: `wlp2s0` still shows `Current Scopes: DNS` with
  `+DefaultRoute`; `resolvectl query broker.actions.githubusercontent.com`
  (the exact hostname from the original outage) resolved successfully.
  The `NetworkManager.conf`/`resolved.conf` fix is confirmed durable,
  not just a live patch that happened to still be in memory.
- **Temperature sensors**: `lsmod | grep -E "coretemp|nct6775"` shows
  both loaded on this fresh boot — `sensors-detect --auto`'s automatic
  `/etc/modules` entry (confirmed present days ago, but never actually
  tested against a real reboot until now) genuinely works.
- **Apache**: active, serving `index.html` with a real `HTTP 200` — at
  the new `/var/www/home-dashboard-hub` path, confirming the rename's
  vhost change is also reboot-durable, not just applied to the running
  config.
- **GitHub Actions runner**: active immediately after boot with no
  manual restart — the systemd service survives a reboot on its own
  (it was already `enabled`), nothing extra needed.
- **Server Health collector**: `server-stats.timer` active, and
  `server-stats.json` already had fresh data (`uptime_seconds: 653` —
  about 11 minutes post-boot) at the *new* path, confirming both the
  systemd unit re-copy and the rename survived together.
- **Docker containers**: `nextcloud`/`nextcloud_db` both back up
  automatically (Docker's own restart policy, not anything this project
  configured) within the same ~8-minute post-boot window.

Nothing needed manual intervention after the reboot — every fix from
today's session (DNS root-cause, sensor module persistence, the full
project rename) is now proven durable rather than merely applied.

### 2026-08-29 — Third display: Bin Day
Added a third tablet screen for Stockport Council bin collection days,
following the exact same multi-display pattern as Server Health: a new
home-screen tile (`data-screen="bin-day"`), a `#binScreen` with its own
`.screenHeader`, an entry in `TABLET_SCREENS`, and its own accent
colour — iOS blue, to stay visually distinct from Prayer Times'
teal-emerald and Server Health's purple.

The interesting decision was *not* building a live fetch. Stockport's
own lookup (`forms.stockport.gov.uk/bin-collections`) is a session-based
form with no public API — scraping it would need real backend
infrastructure this project has avoided everywhere else, and would
quietly break the day the council redesigns the form. UK bin
collections are a fixed recurring pattern instead, so the pattern
itself is hardcoded and the schedule is computed with plain date math,
consistent with how the rest of the app already computes everything
live off the clock rather than pre-scheduling anything.

The rotation rule (green every Monday, plus a 4-week rotation of
black/blue+brown/black/nothing — full detail in the baseline section
above) was derived from the user's real address, but was verified
exhaustively before being hardcoded: checked against Stockport's
official round-21A calendar for every date January–September 2026 (9
months, zero exceptions), then cross-validated against the live
per-property lookup for 21 September 2026 — a date beyond the printed
calendar's own range — which matched the formula's prediction exactly.
The address itself was used only for that one-off lookup and is not
stored anywhere in this repo; only the anonymous resulting pattern is
committed. Also confirmed, directly on Stockport's own
`/terms-and-conditions` page, that their data is published under the
Open Government Licence — a meaningfully more permissive footing than
the unresolved Cheadle Masjid data-usage risk noted above, and part of
why this display was comfortable to build the same way Prayer Times
was.

Tested in local preview at both iPad orientations (834×1194 portrait,
1194×834 landscape) and both themes before shipping — given the recent
real overflow bug on Server Health, `#binCard` reuses the same
`flex: 1; min-height: 0; overflow-y: auto` safety pattern rather than
assuming five rows will always fit. Also verified the computed schedule
directly in-browser against the two known-correct dates above (31 Aug
2026 → black+green, 21 Sept 2026 → blue+brown) before considering this
done — matched exactly in both cases.

### 2026-08-30 — Fixed awkward "Next Collection In Tomorrow" wording
User reported the live display reading "NEXT COLLECTION IN Tomorrow" —
the static label (`#binNextLabel`, "Next Collection In") was written
assuming the value underneath would always be a duration ("In 5 days"),
but two of the three cases (`"Today"`, `"Tomorrow"`) already read as a
complete phrase on their own, so pairing them with a label ending in
"In" produced broken English. Fixed by shortening the static label to
just **"Next Collection"** — every case now reads correctly as a
two-line phrase: "Next Collection / Today", "Next Collection /
Tomorrow", "Next Collection / In 5 days". No JS logic changed, since
`renderBinDay()`'s three-way "Today"/"Tomorrow"/"In N days" branching
was already correct; this was purely a static-label wording bug.
Verified in local preview by re-checking all three phrasings render
sensibly together.
