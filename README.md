# Home Dashboard Hub

> **[ARCHITECTURE.md](ARCHITECTURE.md)** explains how this works at a
> system level — data flow, deployment pipeline, and the real
> engineering problems solved along the way (start there if you want the
> "how/why" rather than the "how do I run this").
>
> **[CHANGELOG.md](CHANGELOG.md)** is the full feature baseline and
> dated change history — the source of truth for what currently works.
> Check it before making changes, and update it after.

A wall/stand-mounted iPad (in a picture-frame case) that shows one of
several full-screen **displays** — a home screen lets you pick which one.
**Prayer Times** (for Cheadle Masjid) is the first one built; more are
planned (home server health, energy/water/gas usage, and others — see
the dated entries in [CHANGELOG.md](CHANGELOG.md) for what exists today,
and the "Where this could go next" section of
[ARCHITECTURE.md](ARCHITECTURE.md) for ideas not built yet).

> **Naming note:** this project started as a single-purpose prayer-times
> display, hence the repo/folder/server path still being named
> `cheadle-masjid-display` throughout this doc. That's staying as-is
> deliberately for now — renaming a live GitHub repo, server directory,
> and Apache vhost is its own careful piece of work, tracked to happen
> once a couple more displays exist rather than mid-build. Every command
> below still uses the current name; nothing here is stale.

Everything lives in one self-contained page (`index.html`, still plain
ES5 JavaScript — see "Written in plain ES5" below), which is what makes
switching between displays instant: it's all one document, and switching
just shows/hides a section rather than navigating to a new page (a real
page navigation would silently break the Prayer Times adhan — see
"Why the page no longer auto-reloads" further down).

## Navigating the display

- **Home icon** (top-left, outside the main panel) → goes to the home
  screen, where each display appears as a tile. Tap a tile to open it.
  It's hidden while you're already on the home screen — there's nothing
  to navigate to from there yet.
- **⋮ icon** (top-right) → opens a small menu. Today it has one entry,
  **Settings** (gear icon), which opens the current display's settings
  panel — for Prayer Times that's Appearance (dark mode) and Adhan. Both
  the ⋮ icon and the Settings panel are specific to whichever display is
  currently open; the home screen itself has neither yet.
- Reopening the app (e.g. after the iPad restarts) goes straight back to
  whichever display you last had open — not the home screen — so the
  always-on kiosk behaviour is unaffected by adding a home screen at all.

## Prayer Times display

The first, currently only, display: today's prayer times for Cheadle
Masjid — live clock, Hijri + Gregorian date, Begins/Iqamah table, a
countdown to the next Iqamah, and an optional adhan (call to prayer)
played through the tablet's speaker at the start of whichever prayers
you enable. On Fridays it swaps Dhuhr for the Jumu'ah row (1st/2nd
Khutbah), matching the masjid's own display screen.

It pulls live data straight from the masjid's own website
(`https://cheadlemasjid.org/wp-json/dpt/v1/prayertime?filter=today`) every
5 minutes, so **you never edit prayer times by hand** — the masjid keeps
that accurate, you just keep the page's look/behaviour maintained.

### Written in plain ES5

No `fetch`, no arrow functions, no CSS variables — that was originally
to support a 2013 Galaxy Tab 3's ancient browser engine. The current
deployment target is an iPad Pro 11" (iOS 26), which is modern enough
that none of that was necessary any more — but the ES5 code runs
identically well there, so it's been left as-is rather than rewritten
for no functional gain. Future displays should follow the same
convention unless there's a real reason not to, so the whole page stays
one consistent, easy-to-follow style.

### Adhan (call to prayer)

Open the Prayer Times display, then **⋮ → Settings** to get there. Under **Adhan** there's a
toggle for each of Fajr, Dhuhr/Jumu'ah, Asr, Maghrib and Isha — turn on
whichever ones you want played out loud, and a small speaker icon appears
next to that prayer's name on the main display as a reminder it's armed.
Each row also has a ▶ button to preview the sound immediately, without
waiting for the real prayer time.

- The audio file is `adhan.mp3` in this folder — swap it for any recording
  you like (same filename), or ask me to wire up a separate file for Fajr
  if you later want its distinct "as-salatu khayrun minan nawm" version.
  **It's `.gitignore`'d and not part of git history** (it's a copyrighted
  recitation, kept out of the now-public GitHub repo) — it still lives as
  a plain file locally and on the server, but if you ever clone this repo
  fresh, you'll need to copy it in by hand before adhan playback works.
- It plays once, right when a prayer's **Begins** time arrives (not
  Iqamah), and won't repeat again that day even if the page reloads.
- **Autoplay on iOS**: Safari blocks audio from playing on its own until
  someone has tapped the screen at least once. The page "unlocks" itself
  permanently on the first tap after each launch — after that, every
  scheduled adhan plays with zero interaction. This is exactly why the
  page no longer force-reloads itself (see below): a reload would throw
  that unlock away and need another tap before audio worked again.
  Practically: after mounting the iPad, tap the screen once yourself, and
  you're done — leave it running indefinitely.
- **Full-screen alert while it plays**: when an adhan starts (scheduled or
  via a Test button), a green full-screen alert shows which prayer it is,
  with a "Tap anywhere to stop" hint. Tapping it stops the adhan
  immediately and dismisses the alert; if you don't tap, it dismisses
  itself automatically once the adhan finishes playing on its own.

## Deployment: self-hosted on your Linux server, displayed on the iPad

No GitHub account needed. Your Linux box serves the page over your home
WiFi; `git push` to it deploys instantly; the iPad just points its
browser at that local address, added to the Home Screen so it opens
full-screen with no Safari chrome.

```
 [your Mac]  --git push-->  [Linux server: bare repo + post-receive hook]
                                        |
                                        v
                              [nginx serves /var/www/cheadle-masjid-display]
                                        |
                                        v (home WiFi, plain HTTP is fine)
                              [iPad Safari, added to Home Screen]
```

### One-time setup on the Linux server

> **Run each numbered step below as one single paste**, not line-by-line
> across separate terminal sessions. If you're pasting into a "Run
> this block" button (like in this chat), each block spawns a fresh
> shell — so a `cd` in one block does **not** carry over to the next
> one. Steps 2 and 3 below are combined into one block for exactly this
> reason: splitting them is what caused `hooks/post-receive` to end up
> missing/misnamed the first time round.

1. If you don't already have a web server, install nginx:
   ```bash
   sudo apt update && sudo apt install nginx    # Debian/Ubuntu
   ```
2. Create the folder nginx will serve, the bare git repo, and the deploy
   hook — all in one go, so the `cd` below stays in effect the whole way
   through:
   ```bash
   sudo mkdir -p /var/www/cheadle-masjid-display
   sudo chown $USER:$USER /var/www/cheadle-masjid-display
   mkdir -p ~/git/cheadle-masjid-display.git
   cd ~/git/cheadle-masjid-display.git
   git init --bare
   cat > hooks/post-receive <<'EOF'
   #!/bin/bash
   GIT_WORK_TREE=/var/www/cheadle-masjid-display git checkout -f main
   EOF
   chmod +x hooks/post-receive
   ls -la hooks/post-receive && cat hooks/post-receive
   ```
   The last line should print `-rwxr-xr-x ... hooks/post-receive` followed
   by the two-line script above — if it doesn't, something in the paste
   got cut off; re-run the whole block rather than just the missing line.
3. Point nginx at that folder. This needs `sudo` because `/etc/nginx` is
   root-owned — note the `sudo tee ... > /dev/null` trick below rather
   than `sudo cat > file`: with a plain `>` redirect, the *shell* opens
   the file before `sudo` ever runs, so it still fails with "permission
   denied" even though the command itself has `sudo` in front of it.
   `tee` is a normal program that `sudo` can actually elevate.
   ```bash
   sudo tee /etc/nginx/sites-available/cheadle-display > /dev/null <<'EOF'
   server {
       listen 80;
       server_name _;
       root /var/www/cheadle-masjid-display;
       index index.html;
   }
   EOF
   sudo ln -s /etc/nginx/sites-available/cheadle-display /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```
   `nginx -t` checks the config is valid before reloading — it should
   print `syntax is ok` / `test is successful`. If it errors instead,
   paste the error back and we'll fix it before reloading.
4. **Give the server a stable address** so you're not hunting for its IP
   later. Easiest: make sure `avahi-daemon` is running (usually already is
   on Debian/Ubuntu) — that gives you `http://<hostname>.local` for free.
   Otherwise, set a static DHCP reservation for it in your router.

### One-time setup on your Mac (this project)

```bash
git remote add home ssh://<user>@<server-host>/home/<user>/git/cheadle-masjid-display.git
git push home main
```
Your site is now live at `http://<server-host>.local/` (or the IP) —
that's the URL you'll open on the iPad.

### Every future update

```bash
git add -A
git commit -m "describe your change"
git push origin main
```
That's it — pushing to GitHub is now the primary deploy trigger (see
"Automated deployment" below). The iPad won't see it until the app is
next manually reopened though — see the note on removing the automatic
reload, below.

### GitHub + automated deployment

This repo is public at
[github.com/amarmohammed398/cheadle-masjid-display](https://github.com/amarmohammed398/cheadle-masjid-display),
pushed over SSH (a dedicated key at `~/.ssh/id_ed25519_github`, configured
in `~/.ssh/config` for `github.com`).

A push to `main` there triggers `.github/workflows/deploy.yml`, which
runs on a **self-hosted GitHub Actions runner** installed directly on
the Linux home server (as a systemd service, under the `gsuaha` user).
The runner checks out the pushed commit and `rsync`s it straight into
`/var/www/cheadle-masjid-display` — no cloud runner involved, since a
GitHub-hosted one has no way to reach a server with no public IP. See
[ARCHITECTURE.md](ARCHITECTURE.md) for the full diagram and reasoning.

The original manual path still works as a fallback if the runner
service is ever down:
```bash
git push home main     # manual fallback — bare repo + post-receive hook
```
`adhan.mp3` is deliberately **not** in this public repo (see
CHANGELOG.md) — it's a copyrighted recitation kept out of git entirely
via `.gitignore`. The deploy workflow excludes it from `rsync` too, so
it's never touched by either deploy path — present only as a plain file
locally and on the server.

## Setting up the iPad Pro as the display

**Current method: [dotKiosk Full Screen Browser](https://apps.apple.com/us/app/dotkiosk-full-screen-browser/id6756888727)**
(free, App Store, by Free Tomorrow). Safari's "Add to Home Screen" mode
(documented further below as a fallback) can't hide iOS's own status
bar — that's a genuine platform limitation, not something fixable with
CSS/meta tags, since only native apps can request the status bar be
hidden. dotKiosk is a tiny native wrapper built exactly for this: it
loads one URL in true fullscreen, no status bar, no address bar.

1. Install **dotKiosk Full Screen Browser** from the App Store (free, no
   account or payment needed).
2. Open it, set a PIN when asked (protects the app's own settings —
   shake the device later to get back into them).
3. Enter your server's address (`http://<server-host>.local/` or the IP)
   as the URL. It loads fullscreen immediately, no status bar visible.
4. **Tap the screen once** — this unlocks audio autoplay for as long as
   the app keeps running (see the Autoplay note above). Nothing else to
   do after that.
5. **Settings → Display & Brightness → Auto-Lock → Never** (otherwise the
   screen will lock itself and the display goes dark).
6. **Lock it into this one app with Guided Access** (free, built into
   iOS): **Settings → Accessibility → Guided Access** → turn it on, set a
   passcode, then with dotKiosk open, **triple-click the side button** to
   start a session. To make changes later (e.g. after a `git push`),
   triple-click again + passcode to exit, then re-open dotKiosk.
7. Mount the iPad, keep it on permanent power, and leave it running.

dotKiosk also has a **remote admin** page (visit the iPad's IP on port
`8742` from another device on the same WiFi) for changing its settings
without touching the iPad directly — convenient, though it does mean
that port is open on the home network (fine on a private home LAN, just
worth knowing it's there).

### Fallback: plain Safari (status bar visible)

If dotKiosk is ever removed or you want zero third-party apps involved:

1. Open **Safari**, go to your server's address, tap **Share → Add to
   Home Screen**. Thanks to the meta tags in `index.html`, opening it
   from that icon still runs full-screen with no Safari address bar or
   toolbar — just with iOS's own status bar visible at the top, which
   this method can't remove.
2. Follow the same tap-once / Auto-Lock / Guided Access steps as above,
   just locking into that Home Screen icon instead of dotKiosk.

### Why the page no longer auto-reloads

Older versions of this page force-reloaded once a night to roll over the
day and pick up pushed updates. That's been removed: on iOS a reload
would throw away the one-time audio unlock from the "tap the screen
once" step above, silently breaking the adhan until someone tapped the
screen again. The day still
rolls over correctly without any reload — the countdown, active-row
highlight and adhan scheduling all key off the live clock, and prayer
data is refetched from the masjid's site every 5 minutes regardless.
The only trade-off: a pushed code change needs someone to manually
reopen the app (exit Guided Access, tap the icon again) to take effect,
rather than appearing on its own overnight.

## Alternative: the old Samsung Galaxy Tab 3 setup

Kept here in case you ever want to run the display on the Tab 3 again
(e.g. as a second screen) instead of, or alongside, the iPad.

The Tab 3 (2013, Android 4.4) is too old for the Play Store version of
most kiosk apps, so you'd sideload an older APK — and you'd want GitHub
Pages rather than the Linux server for hosting, since that setup assumed
a public HTTPS URL:

1. Create a free GitHub account, a public repo, push this project, and
   enable **Settings → Pages** (deploy from `main`, root) to get a
   `https://<user>.github.io/...` URL.
2. **Enable installing unknown apps**: Settings → Security → "Unknown
   sources".
3. **Install Fully Kiosk Browser (legacy build)** — the last version
   supporting Android 4.4 is **v2.9.3 (build 360)**, from
   https://www.fully-kiosk.com/en/ (see their FAQ for the old-Android
   download link).
4. In Fully Kiosk Browser's settings: **Start URL** = your GitHub Pages
   URL, enable JavaScript, set **Reload page after** ~1800 seconds,
   enable **Autoplay Audio**, and turn on Kiosk Mode (start on boot, keep
   screen on, screensaver disabled). Unlike the iPad, Fully Kiosk Browser
   can force autoplay on for every user, so the nightly-reload trade-off
   above doesn't apply to this setup — a periodic reload is fine here.
