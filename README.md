# Cheadle Masjid — Living Room Prayer Display

A single self-contained page (`index.html`) that shows today's prayer times
for Cheadle Masjid: live clock, Hijri + Gregorian date, Begins/Iqamah table,
a countdown to the next Iqamah, and an optional adhan (call to prayer) played
through the tablet's speaker at the start of whichever prayers you enable.
On Fridays it swaps Dhuhr for the Jumu'ah row (1st/2nd Khutbah), matching
the masjid's own display screen.

It pulls live data straight from the masjid's own website
(`https://cheadlemasjid.org/wp-json/dpt/v1/prayertime?filter=today`) every
5 minutes, so **you never edit prayer times by hand** — the masjid keeps
that accurate, you just keep the page's look/behaviour maintained.

Written in plain ES5 JavaScript (no `fetch`, no arrow functions, no CSS
variables) on purpose — the Galaxy Tab 3's browser engine is from ~2013
and doesn't support modern JS/CSS.

## Adhan (call to prayer)

Tap the gear icon (top-right) to open Settings. Under **Adhan** there's a
toggle for each of Fajr, Dhuhr/Jumu'ah, Asr, Maghrib and Isha — turn on
whichever ones you want played out loud, and a small speaker icon appears
next to that prayer's name on the main display as a reminder it's armed.
Each row also has a ▶ button to preview the sound immediately, without
waiting for the real prayer time.

- The audio file is `adhan.mp3` in this folder — swap it for any recording
  you like (same filename), or ask me to wire up a separate file for Fajr
  if you later want its distinct "as-salatu khayrun minan nawm" version.
- It plays once, right when a prayer's **Begins** time arrives (not
  Iqamah), and won't repeat again that day even if the page reloads.
- **Autoplay**: browsers normally block audio from playing on its own,
  without you having tapped the screen first. Fully Kiosk Browser has a
  setting for exactly this — in its settings look for **Autoplay Audio**
  (under the web/media settings) and enable it. Without that, the display
  will still work, it'll just silently skip a scheduled adhan until
  someone next taps the screen (which "unlocks" audio for the rest of that
  session).

## How the "push and it updates on the tablet" workflow works

1. You edit `index.html` on your computer and push to GitHub.
2. GitHub Pages rebuilds the site automatically (usually live within ~1 minute).
3. The tablet's kiosk browser is just pointed at that URL and reloads itself
   periodically (see kiosk setup below) — so it always shows your latest
   pushed version. You never touch the tablet again after the first setup.

### One-time setup (do this once)

1. Create a free GitHub account if you don't have one: https://github.com/signup
2. Create a new **public** repository, e.g. `cheadle-masjid-display`
   (public is required for free GitHub Pages on a free personal account).
3. In this folder, run:
   ```bash
   git remote add origin https://github.com/<your-username>/cheadle-masjid-display.git
   git add -A
   git commit -m "Initial prayer times display"
   git push -u origin main
   ```
4. On GitHub: go to the repo → **Settings → Pages** → under "Build and
   deployment", set **Source: Deploy from a branch**, branch **main**,
   folder **/(root)** → Save.
5. After ~1 minute your page is live at:
   `https://<your-username>.github.io/cheadle-masjid-display/`
   That's the URL you'll point the tablet at.

### Every future update

```bash
git add -A
git commit -m "describe your change"
git push
```
GitHub Pages redeploys automatically. The tablet picks it up on its next
reload (see below) — nothing else to do.

## Setting up the Samsung Galaxy Tab 3 as a kiosk display

The Tab 3 (2013, Android 4.4) is too old for the Play Store version of most
kiosk apps, so you'll sideload an older APK. This is safe and free.

1. **Enable installing unknown apps**: Settings → Security → turn on
   "Unknown sources".
2. **Install Fully Kiosk Browser (legacy build)** — the last version that
   supports Android 4.4 is **v2.9.3 (build 360)**. Download the APK from
   the official site's download page: https://www.fully-kiosk.com/en/
   (look for the "old version for Android 4.4/5" link on their FAQ/download
   page) and open the downloaded file on the tablet to install it.
3. Open Fully Kiosk Browser → in its settings set:
   - **Start URL**: your GitHub Pages URL from above
   - **Web Content Settings → Enable JavaScript**: on
   - **Reload page after (seconds)**: e.g. `1800` (30 min) — belt-and-braces
     reload on top of the page's own 5-minute data refresh, so it also
     picks up any code you've pushed
   - **Kiosk Mode**: enable "Start on boot", "Keep screen on", disable
     status bar / navigation bar, enable "Screensaver: disabled"
4. Prop the tablet up (a cheap stand or photo frame stand works), plug it
   into permanent power, and leave it running.

If Fully Kiosk Browser won't install/run on this specific device, the
fallback is: stock browser → bookmark the URL → manually reopen it after
each reboot, and use Settings → Display → "Stay awake while charging" +
max screen timeout. Less robust, but zero extra installs.
