# Architecture — How This Works

This document explains the system at a level above the code: what it
does, how the pieces fit together, and — more importantly for anyone
evaluating this as engineering work rather than just a finished app —
*why* it's built this way, including the mistakes made and fixed along
the way. For the granular commit-by-commit history, see
[CHANGELOG.md](CHANGELOG.md). For setup instructions, see
[README.md](README.md).

## What it does

An iPad mounted around the house (picture-frame case, permanent power)
shows one of several full-screen **displays**, picked from a home
screen. The first display built is Cheadle Masjid's daily prayer times —
counts down live to the next Iqamah, and optionally sounds the adhan
through the tablet's speaker at the right moment. More displays are
planned (home server health, utility usage, and others — see "Where
this could go next" at the bottom); the app is deliberately structured
so adding one means adding a new screen and a new home-screen tile, not
rebuilding anything that already works. All of it runs unattended,
indefinitely, updated by pushing code from a laptop.

### Multi-display navigation

Every display, plus the home screen that picks between them, lives in
the *same* `index.html` document — switching is a JS show/hide of a
`<div>`, never a real page navigation. This is a hard requirement, not
a style choice: the Prayer Times display depends on a one-time "audio
autoplay unlock" (see the adhan section below) that a page reload would
throw away, so nothing in this app is allowed to reload the page just
to change what's on screen. `showScreen(name)` in `index.html` is the
single place that shows one screen and hides the rest; adding a new
display means adding a new branch there plus a new tile in `#homeScreen`
— it does not touch how any existing display works.

One small **⋮ icon** floats outside the currently-open display's own
panel, opening a menu with **Home** (always returns to the picker) and
**Settings** (that display's own, if it has any). It's hidden on the
home screen itself — nothing to navigate to or configure from there
yet. Reopening the app after it's been closed (e.g. an iPad restart)
returns straight to whichever display was last open, not the home
screen, so the always-on kiosk behaviour this app was already tuned for
isn't disturbed by having a picker at all.

## System overview

```mermaid
flowchart LR
    subgraph Source of truth
        API["cheadlemasjid.org<br/>WordPress REST API"]
    end

    subgraph Client [iPad — the only thing running app logic]
        JS["index.html<br/>(vanilla JS, no framework/build step)"]
    end

    Mac["Developer's Mac<br/>git commit"]
    GitHub["GitHub<br/>public repo"]

    subgraph Home [Linux home server]
        Runner["Self-hosted GitHub<br/>Actions runner"]
        BareRepo["Bare repo +<br/>post-receive hook<br/>(fallback path)"]
        Apache["Apache<br/>serves /var/www/cheadle-masjid-display"]
    end

    API -- "fetched client-side<br/>every 5 min, cross-origin" --> JS
    Mac -- "git push origin main<br/>(primary path)" --> GitHub
    GitHub -- "triggers workflow<br/>(runner polls outbound)" --> Runner
    Runner -- "rsync" --> Apache
    Mac -. "git push home main<br/>(manual fallback)" .-> BareRepo
    BareRepo -. "post-receive hook:<br/>git checkout -f" .-> Apache
    Apache -- "HTTP, home WiFi" --> JS
```

There is **no backend written for this project at all**. The "server" is
just a static file host; all logic — fetching prayer times, computing the
countdown, deciding when to play the adhan, remembering settings — runs
in the browser on the iPad. This was a deliberate simplicity choice: a
static site is far easier to reason about, deploy, and debug than
introducing a server-side component that would need its own hosting,
process management, and failure modes, for a problem that doesn't need
one.

## Data flow

1. On load, the page reads any cached prayer-time data from
   `localStorage` and renders immediately (so a slow or failed network
   request never means a blank screen).
2. It then makes a cross-origin `XMLHttpRequest` straight to the
   masjid's own WordPress site, which exposes a small custom REST
   endpoint (`/wp-json/dpt/v1/prayertime`) returning today's, tomorrow's,
   and Friday's times as JSON. This repeats every 5 minutes.
3. Every successful response overwrites the `localStorage` cache. A
   failed request doesn't clear the display — it just shows an "Offline
   · showing last update HH:MM" notice and keeps using the last good
   data.
4. A `setInterval` tick, once a second, recomputes: which row is "next",
   the countdown digits, and whether any enabled prayer's adhan should
   fire right now — all derived fresh from the current data + current
   time, nothing is pre-scheduled with timers set in advance. This means
   the display self-corrects if the tablet's clock drifts or the tab
   was backgrounded and resumed; it never gets into a stale state that
   needs a reload to fix.

No prayer time is ever hand-entered or hardcoded — the masjid's own site
remains the single source of truth, which matters for correctness around
things like Ramadan, DST changes, and one-off Iqamah adjustments.

## Deployment architecture

The interesting engineering here isn't the frontend — it's the
deployment pipeline, because it had to satisfy a constraint that's easy
to state and annoying to actually build: **"pushing code from my laptop
should update a tablet in someone's living room, without that tablet
ever needing to run anything more than a browser."**

```mermaid
sequenceDiagram
    participant Dev as Developer (Mac)
    participant GH as GitHub
    participant Runner as Self-hosted runner<br/>(on the home server)
    participant Web as Apache webroot
    participant Tab as iPad (dotKiosk)

    Dev->>GH: git push origin main
    GH->>Runner: workflow job<br/>(runner polls GitHub outbound)
    Runner->>Runner: actions/checkout@v4
    Runner->>Web: rsync -av --delete<br/>(into /var/www/...)
    Note over Tab: Already has the page open,<br/>fullscreen, Guided Access locked
    Tab->>Web: next 5-min data poll / manual reopen
    Web-->>Tab: latest deployed files
```

The deploy target is a home server with **no public IP address** — a
GitHub-hosted cloud runner has no route to it at all. The fix is a
**self-hosted runner**: GitHub's own runner agent, installed as a
systemd service directly on the home server, which continuously polls
GitHub asking "any jobs for me?" over a normal outbound connection —
the same direction as a browser making a request. Nothing on the home
network has to accept an inbound connection from the internet, which
matters because this server also hosts another, unrelated production
site. The alternative (a cloud runner + SSH into a port forwarded on
the home router) would have worked too, but would have meant exposing
SSH on that box to the entire internet just to run this project's
deploys.

A manual fallback still exists underneath this: the original bare git
repo + `post-receive` hook (`git push home main`), kept specifically so
there's a way to deploy if the runner service is ever down. Both paths
write to the exact same folder, so neither knows or cares that the
other exists.

`git push`-triggered deployment is a well-worn pattern regardless of
which of the two mechanisms above executes it (this is essentially a
hand-rolled Heroku/Vercel) — chosen over any third-party PaaS because it
removes any dependency on one, and any need for the tablet or server to
have public internet exposure at all: everything happens over the home
LAN, whether triggered manually or automatically.

## Key engineering problems solved (not just "features built")

A few things here are worth more than the line-count they took, because
the *process* of finding and fixing them is the actual engineering:

- **Two web servers fighting over port 80.** The deploy plan assumed
  nginx; the actual server turned out to already be running Apache for
  an unrelated production site. Rather than blindly starting nginx
  (which would have failed to bind the port) or stopping Apache (which
  would have taken the other site offline), the fix was a dedicated
  Apache vhost bound to the server's specific IP — solving the immediate
  problem without touching something unrelated that depended on the same
  box. This is a "read the actual system state before changing it"
  lesson more than a technical one.
- **iOS Safari's audio autoplay policy.** Browsers block JavaScript from
  playing sound without a prior user gesture. The fix (a page-lifetime
  "unlock" on the very first tap) directly conflicted with an earlier
  design decision to auto-reload the page nightly — a reload would throw
  the unlock away and silently break the adhan. Removing the reload was
  the right call once that interaction was understood, but it only
  became obvious by tracing the actual failure mode, not by guessing.
- **Removing a copyrighted file from git history, not just from the
  latest commit.** Before making the repo public, the bundled adhan
  recording needed to disappear entirely — a plain `git rm` would have
  left it recoverable from every prior commit. This needed rewriting
  history (`git filter-branch`) and understanding that git commit hashes
  are content-addressed, so changing history means *every* downstream
  commit gets a new hash — which is also why the already-deployed server
  remote needed a one-time force-push afterwards to resync.
- **A subtle CSS animation bug.** An early version of the countdown used
  an analogue clock face whose hands were driven by `% 60`/`% 3600`
  modulo arithmetic. That looked correct in isolation but caused the
  hands to visibly spin almost a full circle backwards once a minute,
  because a CSS transition animates between two raw numbers, not the
  visually shortest path between two angles. The fix — feeding the
  animation a continuously-decreasing, never-wrapped number — is a small
  example of the gap between "the maths is correct" and "the maths
  produces the intended animation."
- **GitHub silently rejecting password auth.** Not a bug in this
  project's code, but a real "why doesn't this work" moment: GitHub
  stopped accepting account passwords for git operations over HTTPS in
  2021 (unrelated to 2FA), which isn't obvious from the error message
  alone. Fixed by switching to SSH key auth rather than fighting with
  Personal Access Tokens.
- **Reaching a private server from a cloud CI system.** GitHub Actions'
  default runners execute in GitHub's cloud, which has no route to a
  server behind a home router with no public IP. Rather than solving
  this by exposing the server to the internet (port-forwarding SSH,
  dynamic DNS), a self-hosted runner flips who initiates the connection:
  the server polls GitHub outbound instead of GitHub reaching in. Same
  outcome, opposite — and safer — direction of trust.
- **A limitation no amount of CSS could fix.** Hiding iOS's system
  status bar (clock/battery/WiFi icons) turned out to be impossible from
  a web page at all — `apple-mobile-web-app-status-bar-style` only
  changes how content flows *around* the status bar, it can't remove it,
  because only native apps are permitted to request that via
  `prefersStatusBarHidden`. Building a native wrapper was one option
  (blocked here on only having Xcode's Command Line Tools installed, not
  full Xcode); the pragmatic fix was a small, genuinely free, purpose-
  built native app (dotKiosk) that does exactly that one thing. Knowing
  when a problem is a platform boundary rather than a bug to keep
  debugging is its own skill.

## Frontend implementation notes

- Single HTML file, plain ES5 JavaScript — no framework, no build step,
  no `npm install`. This was originally a hard requirement (an ancient
  2013 Android tablet's browser couldn't run modern JS at all) and was
  kept even after the target device changed to a modern iPad, since
  rewriting working code for style rather than function is its own kind
  of technical debt.
- State lives in a handful of module-scoped variables inside a single
  IIFE (`(function () { ... })()`), plus `localStorage` for anything that
  needs to survive a reload (theme choice, adhan on/off settings, cached
  prayer data, "already played today" tracking). There's no state
  management library because the state is small and simple enough that
  one would add complexity rather than remove it.
- Settings (dark mode, per-prayer adhan toggles) are all just CSS class
  toggles on DOM elements, persisted to `localStorage` and re-applied on
  load — the simplest possible approach for a UI this size.

## Skills this project involved

For anyone reading this to evaluate the work rather than use the app:
live production debugging on a real shared server (not a clean VM);
reasoning about browser security models (CORS, autoplay policy) and
designing around them instead of fighting them; git internals beyond
day-to-day commit/push (history rewriting, remote divergence, why
content-addressing means changing history reshapes everything after it);
Linux system administration (systemd services, Apache virtual hosting,
file permissions, SSH key management); making a deliberate
build-vs-avoid-complexity call (no backend, no framework, no build
step) and being able to justify it; designing a navigation/state
structure (the home screen + `showScreen()` pattern) that lets new,
unrelated features (future displays) get added without touching
existing ones, while working around a real platform constraint (iOS's
audio-unlock requirement ruling out page reloads as a navigation
mechanism); and writing documentation aimed at someone other than
yourself, which this file is itself an example of.

## Future displays under consideration (not commitments)

Ideas for what to build into `#homeScreen` next, roughly in order of how
little new infrastructure each one needs:

- **Home server health** — CPU/RAM/disk/uptime for `gsuaha-home-server`
  itself (and the Apache/GitHub Actions runner status). Lowest-effort
  next display by far: it reuses the exact same pattern already built
  for prayer times (a small JSON endpoint, polled client-side every few
  minutes) — the only new work is writing that endpoint.
- **Electricity / gas usage** — via a UK smart meter data source (e.g.
  Hildebrand Glow or n3rgy). If on a dynamic tariff (Octopus Agile/
  Cosy), a "current rate + cheapest window tonight" view is genuinely
  useful, not just decorative.
- **Water usage** — depends on whether the local supplier exposes any
  API/export at all; worth checking before committing design time to
  the display itself.
- **Bin collection countdown** — low effort, high daily usefulness for
  a kitchen/hallway placement, if the local council publishes a feed.
- **Ambient/screensaver mode** — a photo-frame idle state (family
  photos + a small clock) any display could fall back to after
  inactivity, distinct from the "pick a display" home screen — suits
  the picture-frame form factor directly.

## Other engineering ideas (learning-oriented, not commitments)

- Have the workflow run a quick check (e.g. that `index.html` is valid
  and the JS parses) *before* the rsync step, so a broken push never
  reaches the live display — introduces the "CI" half of CI/CD, not just
  the "CD" half already built.
- Add a minimal backend (even a 20-line one) to move the prayer-time
  fetch server-side, removing the cross-origin dependency at request
  time and opening the door to caching, rate-limit protection, or
  serving multiple masjids from one instance.
- Containerize the deployment (Docker + Apache or nginx) for a
  reproducible server setup instead of hand-configured system packages.
- Add automated tests around the pure logic (time parsing, next-prayer
  selection, countdown math) — currently verified by hand in a browser
  each time, which doesn't scale as more features are added.
- Basic uptime/health monitoring for the home server + display, since
  right now there's no alert if the display silently goes offline.
- Once more than one or two displays exist: rename the GitHub repo,
  local folder, and server directory from `cheadle-masjid-display` to
  something that describes the multi-display hub (e.g.
  `home-dashboard-hub`), and update the deploy workflow/git remotes to
  match. Deliberately deferred rather than done alongside the first
  home-screen/navigation change, to avoid touching the live deployment
  pipeline mid-build (see the naming note in README.md).
