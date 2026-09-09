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
  Fridays), Asr, Maghrib, Isha — Begins + Iqamah columns. Each row's
  name also carries a small, low-opacity weather hint inline to its
  left (added 9 Sept 2026, see the "Weather (per-prayer hint)" section
  below and that date's several dated entries) — icon, rain probability,
  and temperature at that prayer's own Begins time.
- On Fridays, the Dhuhr row is replaced by a Jumu'ah row using
  `data.friday.zuhr_jamah` (shown as "1st Khutbah") and
  `data.friday.asr_mithl_1` (shown as "2nd Khutbah") — this exact field
  mapping was verified against the masjid's own live screen at
  cheadlemasjid.org/prayer-times-screen-2/.
- The next upcoming prayer's row is highlighted (`.row.active`) — a
  green accent bar next to the prayer name, a full-row background tint
  (`rgba(14, 143, 107, 0.22)` light / `rgba(47, 211, 154, 0.22)` dark —
  boosted from an earlier `0.14` on 8 Sept 2026, see that dated entry:
  the lower value read as basically invisible once the mesh-gradient
  background existed behind it), plus a matching 1px border for a
  clear edge regardless of exactly what's behind the row at any given
  moment. `activeRowKeyFor(target)` maps `findNextTarget()`'s key onto
  whichever row should actually be highlighted — needed because the
  overnight case is keyed `"fajr-tomorrow"` (distinct from today's
  `"fajr"`) but the table only ever has today's six rows, so passing
  that key straight through never matched anything (see the 8 Sept
  2026 dated entry — this silently broke the highlight for the entire
  overnight window between Isha and the next Fajr, not just a
  visibility problem). `tick()` re-syncs the highlighted row by
  comparing against `lastRenderedActiveKey` (the key `renderRows()`
  actually rendered last), not by checking "is any row currently
  highlighted at all" — the older check meant the highlight could sit
  stuck on a prayer whose Begins time had already passed, for up to
  `REFRESH_MS` (5 minutes), even while the countdown label above it had
  already moved on to the next prayer.
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
- **`#tileGrid` vertically centres its tiles in the space below the
  title (31 Aug 2026)** — `#homeTitle` keeps its own fixed position
  near the top (the ⋮ icon anchors to its exact line, and shouldn't
  drift if the title moved), while `#tileGrid`
  itself gets `flex: 1` (filling whatever's left of `#homeScreen`'s
  height) plus `align-items`/`align-content: center` to centre the
  tiles within that remaining space — not the whole home screen block.
  Wrapping to a second row (once enough displays exist) still centres
  correctly, since `align-content` (not just `align-items`) governs how
  multiple wrapped flex lines are distributed.
- Switching screens (`showScreen(name)`) is a pure show/hide of existing
  DOM, **never a page reload/navigation** — a reload would throw away
  the Prayer Times adhan's audio-autoplay unlock (see Adhan below), so
  every display has to coexist in one document.
- **One bare corner icon** (top-right, ⋮, `#settingsBtn`), outside
  whichever display's glass panel is showing → opens a small popover
  (`#moreMenu`) with two rows today: **Home** (house icon) → returns to
  `#homeScreen`; **Settings** (gear icon) → opens that display's
  settings panel. **Also shown on `#homeScreen` itself (30 Aug 2026)** —
  Appearance (dark mode) is app-wide and shouldn't require opening a
  tablet display first just to reach it — where the **Home** row hides
  itself (`showScreen()` toggles `#goHomeRow`'s display), since
  navigating Home from Home is meaningless; **Settings** stays and opens
  the same panel as everywhere else, with only Appearance visible since
  every per-display section (e.g. Adhan) is scoped to a real display
  name, and `currentScreen === "home"` matches none of them. (There
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
  re-run every time `showScreen()` switches screens — **home screen
  included as of 30 Aug 2026**, where it centers against `#homeTitle`
  instead (the home screen has no `.screenHeader` bar, just a centered
  heading — `positionMoreIcon()` branches on `currentScreen === "home"`
  to pick which element to measure) — as well as on `window.resize`,
  unconditionally now rather than skipping the home screen as it used
  to. This only works while the relevant header element actually exists
  in the DOM and is visible, which is why it's tied to the screen-switch,
  not just a one-time page-load call.
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

### Weather (per-prayer hint)
**Status: fully live (as of 9 Sept 2026), lives inside the Prayer Times
table only — there is no home-screen weather element any more.** The
original version of this feature (30 Aug 2026 – 9 Sept 2026) was a
small animated 5-day forecast strip, `#weatherWidget`, in the top-left
corner of the home screen — **removed 9 Sept 2026 at explicit user
request** ("Remove the weather on the home display"). Fully deleted,
not just hidden: `#weatherWidget` and its HTML comment, every
`.weatherDay`/`.weatherDayLabel`/`.weatherIcon`/`.weatherRain`/
`.weatherTemp` CSS rule (both themes), `positionWeatherWidget()` and
every call to it, `showScreen()`'s widget-visibility toggle, and
`renderWeatherWidget()` itself (its one remaining real job — repainting
the per-prayer hints when new weather data lands — was folded back into
direct `refreshPrayerWeatherCells()` calls at each of its former call
sites). `WEATHER_URL` also dropped its now-unused `&daily=...` params
and `forecast_days` (5 → 1, since nothing reads beyond today once the
strip is gone) — confirmed via live `curl` that `forecast_days=1` still
returns the full current day (00:00–23:00), including hours already
past, which the per-prayer lookups depend on. **One real bug caught
during this removal**: `fetchWeather()`'s success check tested
`parsed.daily` to decide whether a fetch had actually worked — with
`&daily=...` gone, that condition could never be true again, which
would have made every future fetch look like a failure and silently
fall back to cache/blank forever; changed to check `parsed.hourly`
instead, which is what the app actually uses now. Full write-up in the
9 Sept 2026 dated entry — if this ever needs to come back, that's where
to start, not a fresh rebuild.

**Per-prayer-time weather — settled state: a small, low-opacity inline
hint to the left of each prayer's name (added 9 Sept 2026, revised four
times same day — see below for all four).** Not a separate
column: `prayerWeatherInlineHtml()` prepends
`<span class="prayerWeatherInline">` — icon on top, a small
`.prayerWeatherInlineNums` line (blue rain% + spectrum-coloured temp)
stacked underneath it — directly into the `.cell.name` markup, before
the prayer's name text itself, for all 6 rows (Fajr, Sunrise, Dhuhr/
Jumu'ah, Asr, Maghrib, Isha — user explicitly wanted symmetry with the
existing table even though Isha's forecast isn't actionable for
daytime tasks like drying washing). Deliberately discreet
(`opacity: 0.5`) — a background hint, not something competing with the
Begins/Iqamah times for attention. Wind speed is not shown in this
compact form (kept easy to re-add: `hourlyWeatherForMinutes()` still
returns it, `prayerWeatherInlineHtml()` just doesn't render it).
- **Data source: Open-Meteo** (`api.open-meteo.com/v1/forecast`) — free,
  keyless, no signup, fetched client-side with the same resilience
  pattern as Prayer Times/Server Health (falls back to the last good
  `localStorage` response, `cheadleMasjidWeather`, on a failed fetch;
  never shows a stale/wrong icon just because one poll failed). Polled
  every 30 minutes (`WEATHER_REFRESH_MS`) via `&hourly=weathercode,
  temperature_2m,precipitation_probability,wind_speed_10m,is_day`, plus
  `&wind_speed_unit=mph` for UK-appropriate units.
- **Location is deliberately rounded to 2 decimal places (`WEATHER_LAT`/
  `WEATHER_LON` = 53.39 / -2.22), not the real exact address** — this
  app has no backend, so the forecast location has to live in the
  public repo as plain coordinates; rounding to ~1km precision (already
  finer than weather forecasting itself resolves to) means the repo
  never pinpoints a specific house, while the forecast itself is
  identical. Same reasoning as Bin Day only ever committing the
  anonymous schedule pattern, never the address it was derived from —
  and taken a step further here, since even the *lookup* itself only
  ever sent the postcode (not the full street address) to the geocoding
  service. If this location is ever re-derived, round a real geocode to
  2 decimal places rather than committing the precise value.
- **Icons are small, full-colour inline SVGs** (`WEATHER_ICON_SVG`) —
  deliberately not this app's usual monochrome `fill="currentColor"`
  nav-icon convention, since colour (yellow sun, grey cloud, blue rain)
  is what makes a small icon read as "which condition" at a glance, the
  same reason every real weather app does this. Colours are fixed, not
  theme-dependent, matching how real weather icons don't change hue
  between a light/dark app theme elsewhere either. Open-Meteo's WMO
  `weathercode` field collapses down to 9 categories (clear, clear-night,
  partly-cloudy, partly-cloudy-night, cloudy, fog, rain, snow,
  thunderstorm) via `weatherCategoryForCode()` — see that function for
  the exact code-to-category mapping, and the day/night bullet below for
  why there are twice as many as the original 7.
- **Animated, deliberately slow and low-amplitude**: sun/moon pulse or
  glow, clouds drift a couple pixels, raindrops/snowflakes fall in a
  loop, the lightning bolt flickers — all via CSS `@keyframes`
  (`wxSunPulse`/`wxMoonGlow`/`wxCloudDrift`/`wxDropFall`/`wxFlakeFall`/
  `wxBoltFlash`/`wxFogWave`), no JS-driven animation. Kept subtle on
  purpose: this sits on an always-on wall display and shouldn't be
  distracting, same reasoning as the mesh-gradient background's own slow
  drift. `prefers-reduced-motion` disables all of these, same media
  query the background drift already uses.
- `hourlyWeatherForMinutes(mins)` rounds a prayer's Begins time (already
  available as minutes-since-midnight via the existing `parseMinutes()`
  helper) to the nearest hour and looks up that exact
  `"YYYY-MM-DDTHH:00"` slot in the hourly response.
- **Icon reflects actual day/night, not just WMO sky condition** (added
  9 Sept 2026) — `weatherCategoryForCode(code, isDay)` branches "clear"
  and "partly-cloudy" into `clear-night`/`partly-cloudy-night` moon
  variants whenever Open-Meteo's own `is_day` hourly field says it's
  after dark, since a WMO code alone only ever describes sky condition,
  never time of day (a genuinely clear night reports the exact same
  code 0 as a clear afternoon). Added specifically because Isha — always
  after dark — was showing a sun icon. `hourly.is_day` is guarded
  (`hourly.is_day ? hourly.is_day[idx] : undefined`) since a response
  cached in `localStorage` from before this change won't have that
  field at all; without the guard, a stale cache would throw reading
  `undefined[idx]` and break the whole table's render, not just show
  the wrong icon. The moon glyph reuses the exact path already used for
  the Prayer Times home-screen tile, filled in rather than a new shape;
  `partly-cloudy-night`'s moon-behind-cloud composition mirrors
  `partly-cloudy`'s sun-behind-cloud one, positioned by scaling and
  translating that path to sit centred where the sun sits in the
  daytime version (got this wrong on the first attempt — `translate(1,
  -3) scale(0.6)` scaled the shape *toward* the origin as well as
  shrinking it, pushing almost the whole crescent off the top of the
  viewBox; fixed by solving for the translate that keeps the shape's
  own centre at the sun's on-canvas position after scaling, confirmed
  by rendering both night icons enlarged in isolation rather than
  trusting the transform math alone).
- **Icon above the numbers, icon bigger (`1.9vw`) and numbers smaller
  (`0.85vw`) than the single-line version this replaced** — but the
  *combined* stack (icon + numbers line, `line-height: 1` throughout,
  no min-width/min-height floor on the icon) must never exceed the
  Begins/Iqamah text's own line height, same constraint as always on
  this table. Sized by measuring against `.cell.time`'s real rendered
  height via `getBoundingClientRect()` in both orientations rather than
  guessing vw values and hoping — confirmed the stack uses roughly
  75–90% of that budget in both portrait and landscape, with headroom
  to spare rather than sitting right at the edge.
- **Rain % is always blue** (`.prayerWeatherInlineRain`,
  `#0a84ff`/`#409cff` light/dark — the same colour rain always reads as
  everywhere in this app). **Temperature is a continuous grey→amber→
  red spectrum** (`tempSpectrumColor()`), reusing this app's existing
  Server Health warn/bad colour tokens as the two hot-end stops
  (`#b45309`→`#dc2626`-family light, `#f2b84b`→`#f87171`-family dark)
  rather than inventing new hues — stays grey through ordinary UK
  temperatures (≤12°C), only warms up as it climbs past the low 20s,
  fully red by 30°C. Linearly interpolated and clamped, computed
  per-row from the row's actual numeric temperature (can't be pure CSS,
  unlike every other themed colour in this app) and baked into an
  inline `style="color:..."` on the temp span at render time. Verified
  the interpolation arithmetic by hand against a live rendered value
  (matched exactly) and visually across the full temperature range via
  temporary DOM overrides (grey at 8°C through red at 30°C, smooth and
  clearly distinguishable from the rain%'s fixed blue at every point).
- `applyTheme()` now calls `refreshPrayerWeatherCells()` after
  switching the body's theme class — needed because the temperature
  colour is baked in at render time, not pure CSS, so without this a
  theme toggle would leave temperatures showing the *previous* theme's
  palette until some unrelated next re-render. Verified by toggling
  dark mode via the real Settings switch (not just editing
  `body.className` directly) and confirming the temp colour repainted
  immediately in the new theme's stops.
- Verified against real live Open-Meteo data (distinct icon/rain%/temp
  per row, matching each prayer's actual hour), both themes, both iPad
  orientations; no console errors introduced.

**First version (same day, replaced before the day was out): a
separate 4th "Weather" column.** Built first as its own column (own
header cell, icon-over-stats stack sized `1.5vw`/`2.6vw`) showing icon,
rain%, temp, *and* wind speed. Two real bugs were found and fixed while
testing that version — worth remembering since the same row-height
constraint still applies to the current inline design, just with far
smaller stakes now that nothing sits in its own tall stack: (1) first
pass's `1vw` stats text measured 8.34px via `getComputedStyle`, too
small to read at a glance; (2) the vertical icon-over-stats layout that
fixed that overflowed off the bottom of the screen in **landscape**
specifically — this display's `body`/`html` are `overflow: hidden` by
design (a fixed wall-mounted kiosk, never scrolls) and row height here
is purely content-driven, so Maghrib/Isha were silently pushed
entirely below the visible viewport, not just tight. Both fixes shipped
and verified, then the whole column approach itself was replaced within
the same session at the user's explicit request — *"I don't want a
separate column. I want something really compact and discreet. Very
transparent and to the left of the different prayers"* — for the inline
design described above, which sidesteps the row-height problem entirely
since it adds no new vertical space to the row at all.

### Appearance
- **"Liquid Glass" look** (matching iOS 26's own material design): every
  floating panel (`#header`, `#countdownClock`, `#card`, `#settingsPanel`,
  `#moreMenu`, `.tile`) is translucent with `backdrop-filter: blur(28px)
  saturate(180%)` and a bright hairline border. `#settingsBtn` and
  `#homeBtn` are deliberately **not** part of this shared glass styling —
  they're bare icons, not panels (see Navigation below).
- **Page background: animated mesh-gradient of soft colour pools (30 Aug
  2026), replacing the earlier plain flat colour.** This is a deliberate
  *re-opening* of the flat-background decision below (not a silent
  reversal — the user explicitly asked to revisit it), prompted by
  realizing the flat background meant `backdrop-filter: blur(28px)` had
  nothing to actually blur (blurring a single flat colour returns the
  same flat colour) — so every panel *except* `#settingsPanel`/
  `#moreMenu` (the only two that float over other real content) was
  getting zero real blur, just translucency+border faking the look.
  Three large soft-edged `radial-gradient` pools per theme, echoing this
  app's own three accent colours (teal/purple/blue) rather than a new
  palette — pastel versions on white in light theme, deep muted glows on
  black in dark theme — kept on an oversized (`background-size: 160%
  160%`) canvas that slowly drifts via `background-position`
  (`@keyframes bgDrift`, 120s ease-in-out infinite alternate) for a
  barely-perceptible ambient motion rather than a static image; a
  `prefers-reduced-motion` media query disables the animation. Kept
  **universal**, not per-display, to stay simple. Still a single CSS
  change on `body.theme-light`/`body.theme-dark` — no new DOM elements,
  no z-index changes needed, since a background always paints behind
  everything automatically. Verified in local preview across all three
  displays, the home screen, both themes, and both iPad orientations —
  contrast against every accent colour (including Server Health's own
  purple, which shares a hue with one of the gradient pools) stayed
  clearly legible throughout, and every panel now visibly softens the
  colour behind it, confirming the blur is doing real optical work
  everywhere now, not just on the two overlay panels. The flat
  background's original reasoning (see the colourful → flat → colourful
  → flat dated entries further below) is now superseded by this change,
  not deleted from the record — that history is still worth reading if
  this ever gets revisited again.
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
  Styling is fixed/theme-independent, sits above all other UI (z-index),
  so a scheduled adhan fires and shows this alert **regardless of which
  display is currently open** — `checkAdhanSchedule()` runs every tick
  unconditionally, not gated on `currentScreen`. **Dismissing the alert
  (either way) always navigates to Prayer Times (30 Aug 2026)** — before
  this, dismissing it just revealed whatever screen was already
  underneath, which could leave someone looking at Server Health or Bin
  Day right after the prayer they came to check on; now
  `stopAdhanAndHideAlert()` calls `showScreen("prayer-times")` as part
  of the same cleanup. Harmless no-op for the Settings Test-button flow,
  which can only be reached while Prayer Times is already open (Adhan
  settings are hidden on every other screen) — the one side effect there
  is that dismissing also closes the Settings panel if it was open,
  since `showScreen()` always does that; not specifically worked around,
  since it's a minor, easily-understood side effect of a deliberate fix.
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
  still exists and still works — `git push home main` from the Mac.
  Uses a dedicated SSH key (`~/.ssh/id_ed25519_home`, configured for
  `Host 192.168.0.180` in `~/.ssh/config`, same pattern as the GitHub
  key) as of 30 Aug 2026 — no password needed any more (see the dated
  entry below for why it briefly needed one, and how that was fixed
  properly rather than worked around). Useful if the runner service is
  ever down.
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
  confirmed working as of 2026-08-29; all three displays (Prayer Times,
  Server Health, Bin Day) plus adhan playback re-confirmed working on
  the real device as of 2026-08-30**, after the `adhan.mp3` fix above —
  the user tested all three tiles and the adhan directly on the iPad,
  not just via server-side checks.
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

### 2026-08-30 — Fixed the `home` remote's SSH auth; force-synced its stale history
Two separate problems, found while trying to push the Bin Day work to
the manual fallback remote:

1. **The `home` remote had no key-based auth at all** — pushing to it
   relied on the `gsuaha` account's password, entered interactively.
   That's fine when the user runs it themselves in a real terminal, but
   means it can't be pushed to non-interactively (e.g. by Claude, or
   any future automation) at all — `Permission denied
   (publickey,password)` every time. Fixed properly rather than worked
   around: generated a dedicated key pair
   (`~/.ssh/id_ed25519_home`, same naming convention as
   `id_ed25519_github`), added a `Host 192.168.0.180` entry to
   `~/.ssh/config` pointing at it (`IdentitiesOnly yes`, same pattern
   as the existing GitHub entry), and the user ran `ssh-copy-id -i
   ~/.ssh/id_ed25519_home.pub gsuaha@192.168.0.180` themselves in their
   own terminal (the one step that genuinely needs the account
   password — never done by Claude directly, consistent with this
   project's existing rule). Verified with a `BatchMode=yes` SSH
   command completing with no prompt at all before trusting it.
2. **Once auth worked, the push was still rejected** — `home/main` was
   stuck on commits from very early in the project (before "Add adhan
   playback"), because the `git filter-branch` rewrite that later
   purged `adhan.mp3` from history (see that dated entry above) was
   force-pushed to `origin`/GitHub at the time but never re-pushed to
   this remote — the two histories had genuinely diverged from that
   point, not because anyone else pushes here. Since this remote is a
   personal deploy-only mirror (its `post-receive` hook just does
   `git checkout -f main` into the webroot — nothing collaborative
   depends on its history), confirmed with the user before running
   `git push home main --force` to bring it back in line with
   `origin`. Verified `home/main` and `origin/main` now point at the
   identical commit, and that the live server still serves current
   content after the force-push (the hook re-ran automatically).

Net effect: `git push home main` now works non-interactively, with no
password prompt, and both remotes' histories match again.

### 2026-08-30 — Restored `adhan.mp3` on the live server (went missing, likely during the rename)
While testing on the real iPad, the user hit the app's own documented
"Couldn't find adhan.mp3 — add it next to index.html" message — the
intended, self-explanatory failure mode for exactly this file (see the
Adhan baseline section above), but it wasn't expected to actually be
missing on a server that had it working before. Checked directly
(`find /` on the server, an HTTP request for the file) and confirmed
it was genuinely absent from `/var/www/home-dashboard-hub/` — not a
caching or client-side issue.

Likely cause: the 29 Aug 2026 rename's step 1 was `sudo mv
/var/www/cheadle-masjid-display /var/www/home-dashboard-hub`, which
should have carried the untracked file along with everything else —
but that step wasn't followed by a check that `adhan.mp3` specifically
survived, unlike every other piece of that rename (which *was*
verified end-to-end). Root cause not fully confirmed (the old path no
longer exists to inspect), but the effect is clear either way: the
file was gone.

Fixed by `scp`ing the still-present local copy
(`~/Desktop/home-dashboard-hub/adhan.mp3`) straight to the server over
the same key-based SSH connection set up in the previous entry, then
verified two ways before considering it done: an HTTP `200` for
`/adhan.mp3` (not the earlier `404`), and matching `md5` checksums
between the local file and what the server actually serves back over
HTTP — not just "the file exists," but "it's byte-identical to the
real recording, not a truncated or corrupted copy."

**Lesson for any future rename/migration of this project**: `adhan.mp3`
lives outside git entirely, so no amount of re-checking the repo's own
files would have caught this — anything untracked needs its own
explicit "did this specific file survive" check, not just "did the
directory move." Worth adding a one-line reminder to the README's
rename/migration notes if this project is ever restructured again.

**Confirmed fixed on the real device, not just server-side**: the user
retried the Adhan Test button on the actual iPad after the `scp` fix —
it played correctly. While they had the device in hand, they also
re-checked all three home-screen tiles (Prayer Times, Server Health,
Bin Day), which all opened and worked as expected. This is the first
full on-device confirmation since the Bin Day display was added and
since the rename — everything up to this point had only been verified
individually (local preview, server-side `curl`/SSH checks), not as a
single end-to-end pass on the physical hardware.

### 2026-08-30 — ⋮ icon (and Settings/dark mode) now reachable from the home screen
User asked to be able to reach dark mode from "Choose a Display"
directly, rather than needing to open a tablet display first just to
flip Appearance. Previously `showScreen("home")` explicitly hid
`#settingsBtn` — reasonable back when the home screen had genuinely
nothing to configure, but Appearance has been an app-wide setting
(shown regardless of which display is open) since the multi-display
navigation baseline was written, so this was really just an oversight
that outlived its original reasoning.

Three changes, all in `index.html`:
1. `positionMoreIcon()` gained a home-screen branch — the home screen
   has no `.screenHeader` bar (just a centered `#homeTitle`), so it
   measures that element instead when `currentScreen === "home"`,
   same "measure it, don't guess" approach as every other screen.
2. `showScreen()` now sets `settingsBtn.style.display = "flex"` (and
   calls `positionMoreIcon()`) on the `home` branch instead of hiding
   it, and toggles `#goHomeRow`'s own display based on whether the
   target screen *is* home — showing "Home" as an option while already
   on Home would be meaningless clutter.
3. `window.onresize`'s handler used to skip `positionMoreIcon()`
   entirely while on the home screen (`if (currentScreen !== "home")`)
   — removed, since the function now handles that screen correctly too.

No changes needed to `updateSettingsPanelForScreen()` or the Settings
panel itself — Adhan's section already keys off `currentScreen ===
"prayer-times"`, which is simply never true while home is showing, so
it hides correctly with zero new code; Appearance was already
unconditional. This is exactly the "wrap per-display settings, default
to hidden" pattern the baseline already documented working as intended.

Tested by clicking through the real UI flow (not editing `style.display`
directly, which bypasses `showScreen()`'s own state): opened the ⋮ menu
from the home screen (only "Settings" shown, "Home" correctly absent),
opened Settings (only Appearance visible), toggled dark mode and
confirmed it applied instantly across the whole app including the home
screen's own tiles, then navigated to a tablet display and confirmed
"Home" reappears in its menu — no regression to the existing per-display
behaviour. Checked in both portrait (834×1194) and landscape (1194×834).

### 2026-08-30 — Next-prayer row highlight: plain grey → grey with a hint of green
User wanted the highlighted "next prayer" row (`.row.active`) to read
as grey with a subtle green tint, in both themes, rather than a flatly
neutral grey box. Changed `background-color` from `rgba(255, 255, 255,
0.55)` (light) / `rgba(255, 255, 255, 0.08)` (dark) to `rgba(14, 143,
107, 0.14)` (light) / `rgba(47, 211, 154, 0.14)` (dark) — reusing
Prayer Times' own existing accent green (`#0e8f6b`/`#2fd39a`, the same
colours already used for the countdown digits and the row's little
accent bar) rather than inventing a new colour, just at a low enough
opacity that it still reads as "a grey box" rather than "a green box."
Verified visually in the local preview in both themes (via
`getComputedStyle` first, to confirm the edited value was actually
live and not a stale cached copy) before considering it done.

### 2026-08-30 — Animated mesh-gradient background, replacing the flat colour
User asked why Settings looked like "nicer glass" than the rest of the
app. Answer, worked out from the actual CSS rather than guessed: every
panel shares the exact same `backdrop-filter: blur(28px) saturate(180%)`
rule, but `#settingsPanel` and `#moreMenu` are the only two elements
that are `position: fixed` overlays floating on top of already-rendered
screen content — so their blur has real content behind it to soften.
Every other panel (`#card`, `#countdownClock`, `.screenHeader`, `.tile`,
`.statCard`, `#binNextCard`, `#binCard`) sits directly on the page's own
background, which — since the "Liquid Glass" redesign settled on a
plain flat colour (see that entry above) — is a single flat `#ffffff`/
`#000000` with nothing to blur at all. Blurring one flat colour just
returns the same flat colour, so those panels' "glass" look was
actually 100% translucency+border+shadow, 0% real blur.

User then explicitly asked to revisit the flat-background decision
(this is a deliberate re-opening at their request, not an unprompted
reversal of a settled choice) and asked for suggestions on a
minimalist background that would give a stronger, more genuine iOS
Liquid Glass look. Presented three style options (static soft mesh
blobs, a very subtle two-tone gradient, and the same blobs animated
with a slow drift) plus whether it should be universal or tinted per
display; user chose the animated mesh-gradient option and asked for
colour suggestions, deferring the universal-vs-per-display choice to
whichever was simpler.

Implemented as three large `radial-gradient` colour pools per theme,
directly on `body.theme-light`/`body.theme-dark` — no new DOM elements,
no z-index changes needed, since a background always paints behind
everything automatically:
- **Colours deliberately echo this app's own existing three accent
  colours** (Prayer Times teal, Server Health purple, Bin Day blue)
  rather than introducing a new palette — pastel versions
  (`#cfe4fb`/`#e6dbf9`/`#d4f3e7`) on white in light theme, deep muted
  glows (`#123a66`/`#3a1f68`/`#0d3b30`) on black in dark theme.
- **Kept universal, not per-display** — simplest to build and maintain,
  and the point (real blur payoff everywhere) doesn't need per-display
  variation to land.
- **Slow drift, not static**: the gradient canvas is oversized
  (`background-size: 160% 160%`) and its `background-position` animates
  through a 3-point `@keyframes bgDrift` cycle over 120s, `ease-in-out`,
  `alternate` — long enough that the motion reads as ambient rather
  than an obvious moving decoration. A `prefers-reduced-motion` query
  disables the animation entirely.

Verified in local preview: all three displays, the home screen, both
themes, both iPad orientations (834×1194 / 1194×834). Specifically
checked that Server Health's own purple accent (heading, memory bar)
stayed clearly legible against a background that includes a purple
gradient pool — no contrast or hue-clash issues found. Confirmed via
`getComputedStyle` that the animation and gradient are actually applied
(`animationName: "bgDrift"`, `backgroundImage` non-`"none"`), not just
present in source. Every panel now visibly softens whatever colour sits
behind it — the blur is doing real optical work app-wide, not just on
the two overlay panels that already had it.

### 2026-08-30 — Dismissing the adhan alert now always lands on Prayer Times
User asked for the adhan to play and its full-screen alert to appear
regardless of which display is open, and for dismissing it to leave
you on Prayer Times specifically. The first half already worked —
`checkAdhanSchedule()` runs unconditionally in `tick()` (gated on
`data` being loaded, not on `currentScreen`), and `#adhanAlert` is a
`z-index: 100` fixed overlay above every other element in the app —
verified this directly by forcing the alert open while on Server
Health and Bin Day and confirming it covered the full screen either
way, before touching any code.

The real gap was dismissal: `stopAdhanAndHideAlert()` only ever called
`hideAdhanAlert()`, which just reveals whatever screen was already
underneath — so tapping to stop an adhan that fired while looking at
Server Health left you looking at Server Health afterward. Added a
single `showScreen("prayer-times")` call inside
`stopAdhanAndHideAlert()`, which both the manual tap handler and the
audio's `ended` event already funnel through, so both the "tapped to
stop" and "let it finish playing" paths get the same fix for free
rather than needing to patch two places.

Tested by simulating the alert appearing over both Server Health and
Bin Day (each via a tile switch, then forcing `#adhanAlert`'s class
open directly, since there's no real adhan.mp3/network data available
in this local sandbox to exercise the actual schedule trigger) and
dispatching a real click on the alert element — confirmed
`currentScreen` and the visible DOM both end up on Prayer Times in
both cases. Also checked the same-screen case (Settings' Adhan Test
buttons, only reachable while already on Prayer Times): dismissing
still works correctly, with one minor, expected side effect — it also
closes the Settings panel if it was open, since `showScreen()` always
does that as part of switching screens. Not worked around, since it's
a small and easily-understood side effect of a change that's otherwise
a clear improvement.

(Testing note: the browser automation tool's synthetic mouse click at
pixel coordinates failed to trigger the alert's bound `onclick` handler
in this resized-viewport local test, while dispatching `.click()`
directly on the element worked reliably and is what a real tap
triggers — treated as a tool quirk, not a real bug, consistent with
other documented automation-tool quirks for this project.)

### 2026-08-30 — Small animated 5-day weather strip on the home screen
User asked for a small, top-left 5-day forecast on "Choose a Display" —
5 small animated icons, a rain-probability percentage under each, and
invited follow-up questions on the UI specifics before building. Three
genuinely implementation-changing questions were asked before writing
any code: how precisely the forecast location should be committed to
the public repo (privacy), whether each day needed a label, and whether
to add temperature alongside rain %. User chose: coordinates rounded to
~1km precision rather than the exact address, day labels shown, and
temperature added.

Geocoded the location via Nominatim (OpenStreetMap's free geocoder),
deliberately querying **only the postcode**, not the full street
address — a smaller privacy footprint than the lookup even needed to
be. Rounded the returned coordinates to 2 decimal places
(`WEATHER_LAT`/`WEATHER_LON` = 53.39 / -2.22) before writing them
anywhere in the repo; verified via a real Open-Meteo forecast request
against the rounded value that the forecast is identical in practice —
weather doesn't resolve to house-level precision, so nothing was lost
by rounding. No literal address or postcode is committed anywhere.

Chose **Open-Meteo** as the data source — free, keyless, no signup,
fetched client-side exactly like Prayer Times' own API, keeping this
app's "no backend, no secrets in the repo" story intact. Built:
- `#weatherWidget`, a small fixed-position glass panel (same shared
  styling as every other panel) anchored top-left, shown/hidden by
  `showScreen()` exactly when `#homeScreen` is.
- `weatherCategoryForCode()` mapping Open-Meteo's WMO weather codes down
  to 7 icon categories (clear/partly-cloudy/cloudy/fog/rain/snow/
  thunderstorm).
- 7 small, hand-built, full-colour inline SVG icons (`WEATHER_ICON_SVG`)
  — a deliberate, noted exception to this app's usual monochrome
  `currentColor` icon convention, since colour is what makes a
  ~16-18px icon legible as "which condition" at this size.
- Slow, low-amplitude CSS `@keyframes` animations per icon (sun pulse,
  cloud drift, falling rain/snow, flickering lightning, fog wave) —
  kept deliberately subtle for an always-on wall display, same
  reasoning as the mesh-gradient background's own slow drift, and
  wired into the same `prefers-reduced-motion` media query.
- `fetchWeather()`/`saveWeatherLocal()`/`loadWeatherLocal()` mirroring
  the Server Health polling pattern exactly (falls back to cached data
  on failure, never blanks the widget) — polled every 30 minutes.

Tested against the real live Open-Meteo API (a genuine fetch, not a
mock) and confirmed working data end-to-end; then forced all 7 icon
categories with synthetic data (since a single real forecast rarely
covers sun through thunderstorm at once) and zoomed in to confirm every
icon reads distinctly at actual rendered size, not just in the abstract.
Checked visibility toggling (shown on home, hidden on every tablet
display), `localStorage` caching, both themes, and both iPad
orientations before considering this done.

**Immediate follow-up, same session**: user saw the first version (which
used the shared glass-card styling, sized closer to the other panels)
and asked for it smaller with no outline/card at all — sitting directly
on the mesh-gradient background instead. Removed `#weatherWidget` from
all three shared "Liquid Glass" selector lists (rather than overriding
its background/border/blur back to transparent, which would leave a
glass panel fighting its own styling) and shrank every size in the
widget — icon `2.4vw`→`1.7vw` (min `22px`→`16px`), day label
`1vw`→`0.75vw`, rain % `1vw`→`0.75vw`, temp `0.85vw`→`0.62vw` — and
dropped the per-column divider line, which had nothing left to visually
belong to once the card around it was gone. Re-verified in both themes
and both orientations: icons and text still read clearly at the smaller
size directly against the gradient (zoomed in to confirm, not just
eyeballed at actual scale), with no legibility problems found against
any part of the background the widget's fixed top-left position
actually sits over.

**Second immediate follow-up, same session**: user asked for the widget
to sit vertically in line with "Choose a Display" — reasonable, since
the ⋮ icon on this screen already vertically centres against that exact
title (from the earlier "settings icon on the home screen" change), so
the widget floating at its own fixed `top` offset looked disconnected
from that row rather than part of it. Added `positionWeatherWidget()`,
the same measure-the-real-element pattern `positionMoreIcon()` already
uses — reads `#homeTitle`'s live `getBoundingClientRect()` and centres
the widget's own height against it — called from `showScreen()`'s home
branch, `renderWeatherWidget()` (content changes can change the
widget's height), and `window.resize`, mirroring exactly where
`positionMoreIcon()` itself is called. Verified by comparing the
title's and widget's computed vertical centre directly (not just
eyeballed): matched to within a fraction of a pixel in both portrait
and landscape, and confirmed the resize handler correctly re-centres
it after an orientation change.

### 2026-08-30 — Fourth display: Electricity (built around a real hardware blocker)
User wanted a new display for electricity, gas, and water, and asked
for a feasibility ranking before committing to any of them. Researched
rather than assumed throughout:

- **Water**: checked United Utilities (the likely regional supplier)
  directly — they're mid-rollout of smart water meters (2025–2030) and
  describe customer-facing consumption sharing as a *future*
  capability once their systems are updated. No consumer API exists
  today. Shelved, not pursued further.
- **Electricity/gas**: the UK's DCC (Data Communications Company)
  infrastructure means any SMETS2 meter's consumption data is
  reachable via **n3rgy**'s free consumer API, and gas rides the exact
  same enrollment as electricity via a second identifier (MPRN
  alongside MPAN) — confirmed prepayment doesn't block this at all,
  directly from Smart DCC's own documentation.

User then worked through actually setting this up in real time,
hitting a genuine chain of real-world blockers, each one researched
rather than guessed at:
1. **Scottish Power never issued an IHD** (out of stock at
   installation) — without one, there's no MAC address for n3rgy's
   primary consent method.
2. **Confirmed the meter itself is fine**: a photo of the actual meter
   showed a Honeywell AS302P with "SMETS2" printed directly on its own
   label — the right generation, not the blocker.
3. **An old E.ON IHD from a previous address doesn't transfer** —
   IHD-to-meter pairing is a one-time cryptographic commissioning step
   tied to the specific meter it was set up with; re-pairing to a
   different meter isn't a consumer-accessible action.
4. **Hildebrand's Glow CAD (no display, radio-only) would have been
   the clean workaround** — sidesteps Scottish Power's stock issue
   entirely, since it pairs to the meter's HAN independently — but
   checking their actual shop (not just a search snippet) found no
   standalone CAD-only listing currently live, and their own site gave
   contradictory stock signals for the combined Display+CAD bundle
   (sold out with a deposit option on one page, "Available" on
   another) within the same session. No genuine listing found on
   Amazon UK either — Hildebrand's own shop is the only real channel,
   and its state couldn't be trusted at the moment of checking.
5. **n3rgy's "Trusted Consent" alternative** (a documented second
   consent path for exactly this situation — bill, QR code, card
   validation, or device serial number instead of an IHD MAC) remains
   open, but needs the user to contact n3rgy directly; not something
   resolvable from this side.

Rather than block the whole feature on hardware that isn't available,
identified and verified a genuinely useful piece needing **zero**
personal account access: the UK Carbon Intensity API. Verified its CORS
support directly (`curl -D -` against a real request, confirming
`access-control-allow-origin: *`) after a search result claimed the
opposite — the search was wrong, and shipping on that wrong claim would
have meant discovering a false "can't be done client-side" blocker
after building against it, or worse, building an unnecessary backend
piece for a value that was actually fetchable from anywhere all along.

Built the full `#electricityScreen` (tile, header, CSS Grid with the
established overflow-safety pattern, own `.electricityCard`/
`.gridMixChip` class namespace) around this one live card — see the
baseline section above for the full implementation detail. Personal
consumption/cost cards can slot into the same grid later without any
of this being redone, once either the Hildebrand CAD or n3rgy's Trusted
Consent route actually pans out.

Tested against the real live Carbon Intensity API (regional endpoint,
postcode district `SK8`) in local preview — confirmed correct parsing
of intensity index, gCO₂/kWh figure, and generation mix; confirmed the
warn/bad colour-coding CSS classes apply the intended colours
(`getComputedStyle`, not just eyeballed); checked the new tile and
screen in both themes and both iPad orientations, alongside the
existing three tiles to confirm the 4-tile grid still wraps cleanly.

### 2026-08-31 — Power outage: server down, recovered, re-verified
A real power cut took the home server offline entirely — not a DNS or
software issue this time, confirmed by `ping` returning 100% packet
loss (the server wasn't just slow to respond, it was fully
unreachable). The Electricity display commit above happened to land on
GitHub during this exact window, so its deploy job queued with no
runner available to pick it up.

User rebooted the server after restoring power and asked whether its
IP might have changed (a fair DHCP concern). Confirmed methodically
rather than guessed: the old IP was still unreachable at first, so
scanned the full `/24` for open SSH/HTTP ports to find it — one
genuine false lead worth recording (`192.168.0.209` had SSH open, but
its login banner belonged to an unrelated device, not this server;
stopped immediately after a clean, expected `Permission denied` rather
than investigating further, since it plainly wasn't ours), and two
more (a Sky router, an unidentified device with no meaningful response)
that were also ruled out. On a second scan a few minutes later, the
original address (`192.168.0.180`) itself was back — DHCP had simply
re-issued the same lease once the server was fully back online, not
assigned a new one. Confirmed via `hostname` over SSH that it was
genuinely this server before trusting the address again, not just that
something answered on it.

**Worth doing at some point**: a static DHCP reservation for this
server's MAC address in the router, so a reboot or power cut never
requires re-discovering its address again. Suggested to the user, not
yet done — a router-config change to do together when convenient, not
something to guess at remotely.

Once confirmed genuinely back (`hostname` matched, Apache/server-stats
timer/GitHub Actions runner all `active`), found the runner had
reconnected and resumed "Listening for Jobs" on its own, but the
Electricity deploy that queued during the outage never actually ran —
`.last-successful-deploy` stayed stale even a short while after the
runner came back, and the live site still had no Electricity code in
it. Rather than guess why the queued job didn't resume (no `gh` CLI
available locally to inspect GitHub's own run history and confirm),
the reliable fix was a fresh push — this entry's own commit — to
trigger a brand-new deploy the now-listening runner would pick up
immediately, verified the same way every deploy in this project is:
`.last-successful-deploy`'s timestamp advancing and the live page
actually containing the new code, not just assumed from the runner
looking healthy.

### 2026-08-31 — Reverted the Electricity display: grid carbon intensity wasn't wanted as an interim step
User explicitly didn't like the Electricity display as built — a
single grid carbon-intensity card, shipped as a stand-in for personal
consumption data while that stays blocked on the missing IHD/CAD (see
the two dated entries above for that full story). Asked for it back
out entirely: **"You can add this once I've got the IHD and we can
display more useful information."** Not a case of the feature being
broken or the research being wrong — the carbon-intensity data and
everything found about n3rgy/Hildebrand/SMETS2 access remains accurate
and worth keeping for later — the interim-display *approach itself*
wasn't wanted.

Removed completely and cleanly from `index.html`: the home-screen tile,
`#electricityScreen` and its header/grid markup, the `TABLET_SCREENS`
entry, every `.electricityCard`/`.gridMixChip`-related CSS (structural
rules, both themes' colour rules, and its inclusion in the three shared
"Liquid Glass" selector lists), and every carbon-intensity JS function
(`fetchCarbonIntensity`, `renderElectricityScreen`, the save/load-local
pair, `titleCase`, `gridMixChipsHtml`) along with their wiring into
`tick()` and the boot sequence. Verified nothing was left behind with a
case-insensitive search for "electricity", "carbon", and "gridmix"
across the whole file, not just by eye — came back empty. Re-tested in
local preview afterward: exactly three tiles again
(prayer-times/server-health/bin-day), no console errors, weather strip
still correctly positioned.

**Current baseline above no longer has an "Electricity display"
section** — removed rather than left describing something that no
longer exists live; this dated entry, plus the two above it, remain
the accurate record of what was tried and why it was undone. When this
gets rebuilt (once the IHD/CAD situation resolves), it should lead with
genuinely useful personal information — usage, cost, trends — not
default back to grid carbon intensity as the opening card without
checking with the user first; that specific framing is what didn't
land, not the idea of an Electricity display itself.

### 2026-08-31 — Vertically centred the home screen's tiles
User asked for the three display tiles to sit in the vertical centre
of "Choose a Display", rather than immediately below the title with
empty space left underneath. Kept `#homeTitle` exactly where it already
was — the weather strip and ⋮ icon both position themselves against
its live line (`positionWeatherWidget()`/`positionMoreIcon()`), so
moving the title would have dragged both of those out of their
top-row position too, which wasn't what was asked for. Instead gave
`#tileGrid` itself `flex: 1` (filling the remaining height inside
`#homeScreen`'s existing flex column) plus `align-items`/
`align-content: center`, so only the tiles centre within the leftover
space below the title. Verified in local preview in both themes and
both iPad orientations; also confirmed via `getBoundingClientRect()`
that the tiles' own vertical centre lines up with the middle of the
space actually available to them (accounting for `#homeScreen`'s
existing bottom padding, not naively the full viewport height).

User also confirmed this project is intentionally paused here until
real progress is made on the CCTV setup (see the CCTV planning
discussion — a DVR bridge for the existing analog cameras, Frigate as
the storage/live-view/AI layer) — no further display work expected
until then.

### 2026-09-08 — Fixed the next-prayer row highlight: two real bugs, not just faded colour
User reported the green highlight bar on the next upcoming prayer's row
had "disappeared" in both themes and asked for it to be investigated
and restored, clearly visible in both. Investigated properly rather
than assuming it was just the mesh-gradient background washing out an
already-subtle tint (the working theory going in, given that background
was added after the tint was last tuned) — that turned out to be only
part of the story; there were two genuine logic bugs underneath.

**Bug 1 — the overnight highlight never worked at all.**
`findNextTarget()` keys the "nothing left today, counting down to
tomorrow" case as `"fajr-tomorrow"`, deliberately distinct from
today's `"fajr"` row. But `renderRows()` matches rows by exact key
equality, and the table only ever renders today's six rows — so
passing `"fajr-tomorrow"` straight through as the active key matched
nothing, ever. Confirmed with a temporary `console.log` inside
`renderRows()` itself (pure code-reading wasn't settling it — every
call site looked correct in isolation) showing `activeKey=
"fajr-tomorrow"` against `rowKeys=[fajr,sunrise,dhuhr,asr,maghrib,
isha]`. This silently broke the highlight for the *entire* stretch
between Isha and the next Fajr, every single day — a large fraction of
the clock, not a rare edge case. Fixed with a small `activeRowKeyFor()`
helper that strips the `-tomorrow` suffix before it's used as
`renderRows()`'s activeKey, landing the highlight on today's Fajr row
(the same one the "Fajr Begins in" label already refers to) — the
underlying `target.key` itself is left untouched for anything else
that might care about the distinction.

**Bug 2 — the highlight didn't advance during the day either.**
While testing bug 1's fix, simulated a mocked "now" of 3pm (between
Asr and Maghrib) to check the ordinary, non-overnight path — and found
the countdown label correctly updated to "Maghrib Begins in" while the
table stayed highlighting Fajr from boot. `tick()`'s own optimization
(re-render the rows only when needed, not every single second) checked
`document.querySelectorAll(".row.active").length === 0` — "is any row
currently highlighted" — which only ever catches the highlight being
completely *absent*, never the highlight being *stale* (pointing at a
prayer whose Begins time already passed). Once any row was ever
correctly highlighted, that check would never fire again, and the
table would only ever catch up whenever `fetchData()`'s own 5-minute
refresh happened to call `render()` (which always rebuilds
unconditionally) — meaning up to `REFRESH_MS` of visible mismatch
between the countdown label and the highlighted row at every prayer
transition, every day. Fixed by tracking `lastRenderedActiveKey` (set
inside `renderRows()` itself, so it stays correct regardless of which
caller — `render()` or `tick()` — last ran it) and having `tick()`
compare the *correct* key against it, rebuilding whenever they differ,
not just whenever nothing is highlighted at all. Re-verified with the
same mocked-3pm approach: the highlight correctly moved from Fajr to
Maghrib the instant the countdown label did.

**Then the visibility fix**, on top of both logic fixes: even once
correctly applied to the right row at the right time, the existing
`rgba(…, 0.14)` tint was genuinely difficult to make out at actual
device scale against the mesh-gradient background (confirmed by
screenshot, not assumed) — raised to `0.22` in both themes, plus a new
matching 1px border around the active row for a crisp edge regardless
of exactly what colour the drifting gradient happens to show behind it
at any given moment. Verified in both themes, both iPad orientations,
and at actual (unzoomed) scale specifically — not just a close-up
screenshot, since a wall-mounted display is read from across a room,
not inspected at arm's length.

### 2026-09-09 — Per-prayer-time weather: a 4th column in the Prayer Times table
User asked how the home-screen weather strip worked, then whether each
prayer row could show its own forecast instead of just the day's
overall high/low — "that way the user can know what period of the day
is best to maybe put the clothes out". Confirmed this was possible and
reasonably accurate off the same Open-Meteo API at no extra cost (its
hourly endpoint, combined with the existing daily request in a single
call), and proposed adding wind speed alongside rain%/temp as a more
directly useful drying-conditions signal than temperature alone.
Clarified placement/scope with three quick questions before building:
placement (inside the Prayer Times table itself, next to the existing
Begins/Iqamah columns — not the home screen), scope (all 6 rows
including Sunrise, for symmetry with the existing table), and whether
to include wind speed (yes, but built so it's easy to pull back out on
its own if it "doesn't look nice" once seen live). See the expanded
"Weather strip" section above for full implementation detail — in
short: `WEATHER_URL` now requests `&hourly=...` alongside the existing
`&daily=...` in one call; `hourlyWeatherForMinutes()` maps a prayer's
Begins time to the matching hourly forecast slot; each row gets an
icon + rain% + temp + wind cell via `prayerWeatherCellHtml()`.

Two real issues surfaced during testing, not just cosmetic tuning:
- **Text too small on the first pass** — `1vw` stats text measured at
  8.34px (`getComputedStyle`), too small for primary table content on
  a wall display. Raised to `1.5vw` and restructured to a vertical
  icon-over-stats stack to fit larger text in the same narrow column.
- **That taller stack overflowed off-screen in landscape** — this
  display's `body`/`html` are `overflow: hidden` by design (a fixed
  kiosk, never meant to scroll), and row height here is purely
  content-driven (no fixed/shared row height), so the portrait-sized
  vertical stack pushed the Maghrib and Isha rows entirely below the
  visible viewport in landscape's shorter, wider frame — found by
  measuring real row `getBoundingClientRect()` values against the
  viewport height, not by eyeballing a screenshot that happened to
  scroll the same content into view. Fixed with a landscape-only
  `@media (orientation: landscape)` override (same pattern already used
  for the Server Health stat grid) laying the icon and stats out in one
  compact horizontal row instead, keeping every row's height close to
  what it was before this column existed. Re-verified: all 6 rows fit
  with room to spare in landscape, in both themes.

Verified against real live Open-Meteo data end-to-end (distinct icon/
rain%/temp/wind per row matching each prayer's actual hour), both
themes, both iPad orientations, no console errors introduced by this
change. Wind speed is deliberately isolated (its own `<span>` + theme
colour rule) so it can be removed on its own later without touching
rain%/temp/icon, per the user's own stated "might remove it" caveat.

### 2026-09-09 — Per-prayer-time weather, redesigned: column → inline hint
Same day the 4th "Weather" column above shipped, user asked for a
different treatment entirely: *"I don't want a separate column. I want
something really compact and discreet. Very transparent and to the
left of the different prayers eg. Fajr, sunrise, dhuhur."* Asked one
quick clarifying question on how much information to keep at that
smaller scale (icon+temp only / icon-only / icon+rain%+temp with wind
kept separate) — user chose **icon + rain% + temp, wind kept out but
easy to add back**, matching the removable-wind-speed caveat already
built into the column version.

Replaced the column entirely rather than layering the two: removed the
4th `.cell.weather`/header cell and `prayerWeatherCellHtml()`, and
added `prayerWeatherInlineHtml()`, which prepends a small
`<span class="prayerWeatherInline">` (icon + `"rain% temp°"` text) onto
`nameHtml` in `renderRows()`, right before the prayer's own name text —
so it renders as part of the existing `.cell.name` (already a flex
container) rather than a cell of its own. Kept deliberately subtle:
`opacity: 0.5`, `font-size: 1vw`, `14px`-scale icon — a background hint
next to the name, not a fourth thing competing with Begins/Iqamah for
attention. This also fully sidesteps the previous version's landscape
row-height problem: since nothing sits in a tall stack any more, both
the earlier `@media (orientation: landscape)` override and the
portrait/landscape font-size split it needed are gone — one CSS rule
now covers both orientations, verified with the same real
`getBoundingClientRect()` row-height check as before (all 6 rows sit
comfortably inside 834px in landscape, well under the previous
column's already-fixed bound).

Verified against real live Open-Meteo data, both themes, both iPad
orientations, no console errors. See the rewritten "Weather strip"
section above (now split into "settled state" and "first version,
replaced" parts) for full before/after detail — the column version's
code no longer exists in `index.html`, kept here and there only as
documented history.

### 2026-09-09 — Per-prayer weather hint: capped height, rain in blue, temperature spectrum
Third pass on the same-day feature: *"I like it but I want the
information to be compact vertically but keeping the height to max the
height of the text. Make sure to add the blue for rain percentage and
the temperature should be a spectrum of reds and oranges if the
temperature gets high otherwise just keep it at grey."* Two changes:

**Height capped to the text itself.** The icon previously had its own
`min-width`/`min-height: 14px` floor, independent of the actual text
size next to it (`8.34px` at the time) — meaning the icon could be, and
was, taller than its own text, adding a sliver of extra height to the
row. Switched the icon to `width/height: 1em` (no floor at all) plus
`line-height: 1` on the wrapper, so it's mathematically pinned to
whatever the text's own line-height is — confirmed via
`getBoundingClientRect()` that icon height and wrapper height come out
identical, in both orientations, unlike before.

**Colour split into a fixed blue and a data-driven spectrum.** Rain %
and temperature used to share one plain themed-text colour; split into
`.prayerWeatherInlineRain` (always blue, reusing the existing
`#0a84ff`/`#409cff` tokens) and `.prayerWeatherInlineTemp`, whose
colour now comes from a new `tempSpectrumColor(tempC, isDark)` helper —
a genuine continuous interpolation (not a few hard-edged buckets)
across three stops per theme: grey at ≤12°C (ordinary UK weather),
through this app's existing amber "warn" colour around the low-to-mid
20s, to its existing red "bad" colour by 30°C. Reused Server Health's
`.statWarn`/`.statBad` hues rather than inventing a new palette, so a
"getting hot" reading uses the same colour language as everywhere else
in the app. Since this needs the actual numeric temperature (not just
the current theme), it's computed per-row and written as an inline
`style="color:..."` at render time — the one colour in this app that
isn't pure CSS. That in turn meant `applyTheme()` needed a
`refreshPrayerWeatherCells()` call added: without it, flipping the
theme switch left every temperature showing the old theme's colour
until some unrelated next re-render happened to touch the table.
Caught by testing the *real* Settings toggle rather than only editing
`body.className` directly (this app's usual quick-test shortcut, which
would have masked the bug since it never runs through `applyTheme()`
at all).

Verified: interpolation arithmetic checked by hand against a live
rendered value (exact match); the spectrum's look confirmed across
8°C→30°C via temporary DOM colour overrides (smoothly grey → amber →
red, clearly distinct from rain%'s fixed blue throughout); real theme
toggle re-renders correctly; both iPad orientations still show all 6
rows with zero added row height. No console errors.

### 2026-09-09 — Per-prayer weather hint: numbers moved under the icon
Fourth pass on the same-day feature: *"I want the numeric numbers to be
under the icon. Make the icon a bit bigger and the numbers a bit
smaller. Make sure the vertical height of the icon and text is max of
the height of the text."* Restructured `.prayerWeatherInline` from a
single horizontal line (icon, rain%, temp all side by side) into a
vertical stack — icon on top, a new `.prayerWeatherInlineNums` line
(rain% + temp together) underneath — and rebalanced the two pieces'
sizes: icon up to `1.9vw` (from being sized to match the numbers'
height exactly), numbers down to `0.85vw`.

The height constraint from the very first inline version still
applies, just against a taller combined shape now: measured the
*combined* icon+numbers stack against `.cell.time`'s real rendered
height (the Begins/Iqamah text sitting right next to it) via
`getBoundingClientRect()` in both portrait and landscape before
settling on final sizes, rather than picking vw numbers by eye and
assuming they'd fit — exactly the kind of check that would have caught
the original column version's landscape overflow bug earlier if it had
been run then. Result: the stack uses about 75–90% of the available
line-height budget in both orientations (22.9px of a 26px budget in
portrait, 32.8px of 37px in landscape), comfortable margin either way,
not sitting right at the edge.

Verified: all 6 rows checked programmatically against their own
`.cell.time` height in both orientations (all pass), both themes
visually confirmed, no console errors.

### 2026-09-09 — Weather icons now know day from night; temp spectrum on the home strip too
User: *"test on ipad and make sure icons make sense. like a sun can't
be showing during isha? and the orange/red temp spectrum should be
applied to the home display temperature digits."* Two fixes:

**Real bug: a WMO weather code alone doesn't encode time of day.**
Code 0 ("clear") is the same whether it's 2pm or 2am — this app was
picking the sun icon for it either way, so Isha (always after dark)
could genuinely show a sunny icon on a clear night. Confirmed live
against real data for today's date: hour 21 (Isha's rounded hour) came
back `weathercode: 0, is_day: 0` — a real, currently-live case of the
bug, not a hypothetical. Fixed by adding `is_day` to the `&hourly=...`
request and threading it through `weatherCategoryForCode(code, isDay)`,
which now returns `clear-night`/`partly-cloudy-night` instead of their
daytime equivalents whenever `is_day === 0`. Verified against real live
data: Fajr and Maghrib (both `partly-cloudy-night` — cloud with the
sun/moon peeking through) and Isha (`clear-night`) all now show a moon;
Sunrise (`partly-cloudy`, `is_day: 1`) still correctly shows a sun.
The home-screen daily strip is deliberately **not** touched by this —
a whole day has no single time-of-day, so it keeps always showing the
daytime icon, exactly as before.

New moon icons reuse the exact crescent path already used for the
Prayer Times home-screen tile (`M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0
21 12.79z`), filled in rather than drawn fresh. Getting
`partly-cloudy-night`'s composition right took two attempts: the first
transform (`translate(1,-3) scale(0.6)`) scaled the shape toward the
SVG origin as well as shrinking it, which pushed almost the entire
crescent off the top edge of the viewBox — invisible, not just
misplaced, confirmed by rendering both new icons enlarged in an
isolated preview rather than trusting the transform arithmetic on its
own. Fixed by solving for the translate that keeps the shape's own
centre at the same on-canvas point the daytime version's sun circle
already sits at, after the same scale factor. Also guarded
`hourly.is_day` being read at all (`hourly.is_day ? hourly.is_day[idx]
: undefined`), since a `localStorage`-cached response from before this
change won't have that field — without the guard, that stale-cache
case would throw on `undefined[idx]` and break the whole table's
render instead of just showing the pre-existing (correct, if
day-only) icon behaviour until the next successful fetch.

**Home-screen temperature spectrum.** The daily strip's high/low
(`.weatherTemp`) used one flat themed colour; now each of hi and lo is
coloured independently via the same `tempSpectrumColor()` already built
for the per-prayer hint, since a day's high and low can sit in very
different bands. `applyTheme()` was already re-rendering the prayer
table's temperatures on a theme switch; simplified it to call
`renderWeatherWidget()` instead of `refreshPrayerWeatherCells()`
directly — the former already calls the latter on every path (including
before any weather data has loaded), so one call now keeps both the
home strip and the prayer table's data-driven colours in sync with
theme switches, rather than needing two separate calls kept in step by
hand.

**"Test on iPad"**: this repo has no native app/Xcode project, so
there's no build for the iOS Simulator to launch — attempted anyway,
and the simulator control tool itself reported no full Xcode install
on this machine (`xcode-select` points at the CLI tools only), so it
couldn't be used even for a plain Safari-in-simulator check. Continued
testing the same way this project always has: the Browser pane at the
iPad Pro 11"'s real two viewport sizes (834×1194 portrait, 1194×834
landscape), both themes. **If genuine on-device iPad testing is ever
wanted, that needs a real Xcode install (`sudo xcode-select -s
/Applications/Xcode.app/Contents/Developer` after installing Xcode
itself from the App Store) — flagged to the user rather than silently
substituted.**

Verified: real live data confirmed the icon fix end-to-end (moon for
Fajr/Maghrib/Isha, sun for Sunrise); home-strip temperature colours
checked numerically per-span and via a real theme-toggle re-render;
both new night icons visually confirmed correct after the transform
fix; both orientations re-checked against the existing row-height
budget (unaffected, icon-only change); no console errors beyond
pre-existing unrelated 404 noise from this local test server.

### 2026-09-09 — Removed the home-screen weather strip
User: *"Remove the weather on the home display and check to make sure
all the documentation and the project is up to date."* The per-prayer
weather hint inside the Prayer Times table (this same day's other
entries) is unaffected — this only removed the separate 5-day forecast
strip that used to sit in the home screen's top-left corner.

**Removed cleanly, not just hidden** — matching how the Electricity
display was fully reverted back on 31 Aug 2026, verified with the same
discipline: a case-insensitive sweep for every remaining reference
after the edits, not just removing the obvious pieces and assuming
nothing was missed.
- `<div id="weatherWidget">` and its explanatory HTML comment, gone from
  the markup entirely.
- CSS: `#weatherWidget`/`#weatherWidget.show`, `.weatherDay`,
  `.weatherDayLabel`, `.weatherIcon`, `.weatherRain`, `.weatherTemp`,
  and their four theme-specific colour rules — all removed. The shared
  `.wxSun`/`.wxMoon`/`.wxCloud`/etc. animation classes stayed, since the
  per-prayer hint's icons still use them.
- JS: `positionWeatherWidget()` and all three call sites (`showScreen()`,
  `window.onresize`, and inside the widget's own render function) —
  removed. `showScreen()`'s `weatherWidget.className = ...` toggle —
  removed. `renderWeatherWidget()` itself — removed entirely; its one
  remaining real job (repainting per-prayer hints once new weather data
  lands) was already just a call to `refreshPrayerWeatherCells()`, so
  every one of its own call sites (`applyTheme()`, `fetchWeather()`'s
  success path, `handleWeatherFetchFailure()`, and app init) now calls
  `refreshPrayerWeatherCells()` directly instead — one less layer of
  indirection, not just a smaller version of the same function.
- `WEATHER_URL`: dropped `&daily=weathercode,temperature_2m_max,
  temperature_2m_min,precipitation_probability_max` entirely (nothing
  reads `weatherData.daily` any more) and reduced `forecast_days` from
  `5` to `1`, since `hourlyWeatherForMinutes()` only ever looks up
  today's date regardless of how many days are requested. Confirmed via
  a live `curl` against the real API first that `forecast_days=1` still
  returns the full current day, `00:00` through `23:00` — including
  hours already in the past — since the per-prayer hints for early
  prayers (Fajr, say, looked up at 8pm) depend on that.

**One real bug caught by this removal, not introduced by it**:
`fetchWeather()`'s success handler checked `if (parsed && parsed.daily)`
to decide whether a response actually counted as a successful fetch.
With `&daily=...` gone, `parsed.daily` can never exist in a real
response again — left unchanged, this condition would have been false
on every single fetch from now on, silently routing every successful
200 response into the failure/fallback path instead, forever. Caught by
reading the function fully rather than only touching the lines that
looked directly related to the strip; changed to check `parsed.hourly`,
which is what this app actually consumes now. Verified live: cleared
`localStorage`, confirmed a fresh fetch populates `weatherData.hourly`
(24 entries, no `daily` key) and the Prayer Times table renders
correctly from it, not from a silently-stale cache.

Also updated stale prose left behind in this same file's own baseline
section and in README.md/ARCHITECTURE.md, which both still described
the removed strip in present tense and didn't mention the per-prayer
hint at all (a real documentation gap, not something this removal
created) — see the rewritten "Weather (per-prayer hint)" sections in
both.

Verified: home screen confirmed weather-strip-free in both themes and
orientations (no leftover DOM node, no layout gap); Prayer Times table
still shows correct per-row icons/rain%/temp end-to-end against a fresh
live fetch; theme toggle still repaints per-prayer temperatures
correctly now that it calls `refreshPrayerWeatherCells()` directly; no
console errors beyond pre-existing unrelated 404 noise from the local
test server.
