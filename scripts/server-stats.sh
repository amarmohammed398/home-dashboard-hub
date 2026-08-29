#!/bin/bash
# Collects a snapshot of this server's health into server-stats.json,
# served by Apache as a plain static file right next to index.html
# (same-origin, no CORS needed) — the Server Health tablet display
# polls it every ~10s. Run periodically by server-stats.timer
# (systemd), NOT a long-running daemon: this script runs once, writes
# the file, exits. See ARCHITECTURE.md's "server health display"
# section for the full design, and CHANGELOG.md for the exact JSON
# schema this produces.
#
# Requires: jq (JSON construction), ping and getent (both standard,
# already present) for the connectivity check. lm-sensors is optional —
# the temperature reading degrades to `null` if it isn't installed/
# configured, everything else still works. Docker container reporting
# is optional too — skipped entirely (empty list) if `docker` isn't on
# PATH or the current user can't query it.
set -euo pipefail

OUT_FILE="/var/www/home-dashboard-hub/server-stats.json"
HIST_FILE="$HOME/.server-stats-history.json"
PREV_SAMPLE_FILE="$HOME/.server-stats-prev-sample"
UPDATES_CACHE_FILE="$HOME/.server-stats-updates-cache"
DEPLOY_MARKER="/var/www/home-dashboard-hub/.last-successful-deploy"
HIST_LEN=24          # ~4 minutes of history at the default 10s run interval
UPDATES_CACHE_MAX_AGE=3600   # re-check available package updates at most hourly — this barely
                             # changes between runs, and `apt list` is unnecessary overhead every 10s

now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
now_epoch=$(date +%s)
hostname_val=$(hostname)
uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
cpu_cores=$(nproc)

read -r load1 load5 load15 _ < /proc/loadavg

mem_total_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
mem_total_mb=$(( mem_total_kb / 1024 ))
mem_used_mb=$(( mem_used_kb / 1024 ))
mem_percent=$(( mem_used_kb * 100 / mem_total_kb ))

# Swap — 0% (not null) when there's no swap configured at all, since
# "no swap" is a normal, common setup, not a missing-data case.
swap_total_kb=$(awk '/SwapTotal/{print $2}' /proc/meminfo)
swap_free_kb=$(awk '/SwapFree/{print $2}' /proc/meminfo)
swap_used_kb=$(( swap_total_kb - swap_free_kb ))
swap_total_mb=$(( swap_total_kb / 1024 ))
swap_used_mb=$(( swap_used_kb / 1024 ))
if [ "$swap_total_kb" -gt 0 ]; then
  swap_percent=$(( swap_used_kb * 100 / swap_total_kb ))
else
  swap_percent=0
fi

# Disk — just root ("/") by default, since /var/www almost certainly
# lives on the same filesystem as root on this box (a single-disk home
# server), which would make a second row just repeat the same numbers
# under a different label. If you do have a genuinely separate mount
# worth watching (an external drive, say), duplicate the disk_row call
# below with its path/label and add it into the `disks_json` array.
disk_row() {
  local path="$1" label="$2" line used total pct
  line=$(df -BG --output=used,size,pcent "$path" | tail -1)
  used=$(echo "$line" | awk '{gsub("G","",$1); print $1}')
  total=$(echo "$line" | awk '{gsub("G","",$2); print $2}')
  pct=$(echo "$line" | awk '{gsub("%","",$3); print $3}')
  jq -n --arg mount "$label" --argjson used "$used" --argjson total "$total" --argjson percent "$pct" \
    '{mount: $mount, used_gb: $used, total_gb: $total, percent: $percent}'
}
disks_json=$(jq -s '.' <(disk_row / "/"))

# Temperature — the first sensor "_input" reading lm-sensors reports.
# Home servers vary a lot in what chips/labels `sensors` exposes; if
# this picks up the wrong one (e.g. a drive instead of the CPU
# package), run `sensors -u` yourself, find the label you actually
# want, and tell me — the awk line below is the only thing that needs
# adjusting to target it specifically.
temp_c=$(sensors -u 2>/dev/null | awk '/_input/{print $2; exit}')
if [ -z "${temp_c:-}" ]; then temp_c="null"; fi

is_active() {
  systemctl is-active --quiet "$1" 2>/dev/null && echo true || echo false
}
apache_active=$(is_active apache2)
ssh_active=$(is_active ssh)
runner_active=$(systemctl is-active --quiet 'actions.runner.*' 2>/dev/null && echo true || echo false)

# Connectivity — two separate checks, deliberately, not one combined
# "internet: yes/no": DNS resolution and actual reachability can fail
# independently (see the 29 Aug 2026 outage in ARCHITECTURE.md, where
# DNS was broken but the network route itself was fine) — collapsing
# them into one flag would hide exactly the distinction that mattered
# then. `github.com` for DNS (matches what actually broke that day);
# 1.1.1.1 by raw IP for reachability, so a DNS failure can't also make
# this check fail for an unrelated reason.
dns_ok=false
if getent hosts github.com >/dev/null 2>&1; then dns_ok=true; fi
internet_ok=false
if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then internet_ok=true; fi

services_json=$(jq -n \
  --argjson apache "$apache_active" \
  --argjson ssh "$ssh_active" \
  --argjson runner "$runner_active" \
  --argjson dns "$dns_ok" \
  --argjson internet "$internet_ok" \
  '[
    {name: "apache2", label: "Apache", active: $apache},
    {name: "ssh", label: "SSH", active: $ssh},
    {name: "actions.runner", label: "GitHub Actions runner", active: $runner},
    {name: "dns", label: "DNS Resolution", active: $dns},
    {name: "internet", label: "Internet", active: $internet}
  ]')

containers_json="[]"
if command -v docker >/dev/null 2>&1; then
  if docker_out=$(docker ps -a --format '{{.Names}}|{{.State}}' 2>/dev/null); then
    containers_json=$(printf '%s\n' "$docker_out" | jq -R -s '
      split("\n") | map(select(length > 0)) | map(split("|")) |
      map({name: .[0], status: .[1]})
    ')
  fi
  # If this comes back empty/"[]" even though you know containers are
  # running, gsuaha probably isn't in the `docker` group yet — see the
  # setup notes for `sudo usermod -aG docker gsuaha`.
fi

if [ -f "$DEPLOY_MARKER" ]; then
  last_deploy=$(cat "$DEPLOY_MARKER")
else
  last_deploy=""
fi

# Reboot required — Ubuntu/Debian drop this file after a kernel (or
# other reboot-needing) package update.
if [ -f /var/run/reboot-required ]; then reboot_required=true; else reboot_required=false; fi

# Pending package updates — cached hourly (see UPDATES_CACHE_MAX_AGE
# above). `apt list --upgradable` only reads the already-fetched local
# package lists, no network call, but there's still no reason to run it
# every 10 seconds when it can only change after an `apt update`.
run_updates_check=true
if [ -f "$UPDATES_CACHE_FILE" ]; then
  cache_mtime=$(stat -c %Y "$UPDATES_CACHE_FILE" 2>/dev/null || echo 0)
  cache_age=$(( now_epoch - cache_mtime ))
  if [ "$cache_age" -lt "$UPDATES_CACHE_MAX_AGE" ]; then run_updates_check=false; fi
fi
if [ "$run_updates_check" = true ]; then
  apt list --upgradable 2>/dev/null | grep -c upgradable > "$UPDATES_CACHE_FILE" || echo 0 > "$UPDATES_CACHE_FILE"
fi
updates_available=$(cat "$UPDATES_CACHE_FILE" 2>/dev/null || echo 0)

# ---- CPU % and network throughput: both need a previous sample to
# diff against, since /proc/stat and /proc/net/dev are cumulative
# counters, not instantaneous readings. First run after install (or
# after this file is ever deleted) has nothing to diff against, so
# both come back null for exactly that one run, then are correct from
# the second run onward. ----
read -r _ c_user c_nice c_system c_idle c_iowait c_irq c_softirq c_steal _ < /proc/stat
cpu_idle_now=$(( c_idle + c_iowait ))
cpu_total_now=$(( c_user + c_nice + c_system + c_idle + c_iowait + c_irq + c_softirq + c_steal ))

iface=$(ip route show default 2>/dev/null | awk '/default/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | head -1)
rx_now=0
tx_now=0
if [ -n "$iface" ]; then
  netline=$(grep -E "^ *${iface}:" /proc/net/dev || true)
  if [ -n "$netline" ]; then
    rx_now=$(echo "$netline" | awk -F: '{print $2}' | awk '{print $1}')
    tx_now=$(echo "$netline" | awk -F: '{print $2}' | awk '{print $9}')
  fi
fi

cpu_percent="null"
rx_kbps="null"
tx_kbps="null"
if [ -f "$PREV_SAMPLE_FILE" ]; then
  read -r prev_ts prev_total prev_idle prev_rx prev_tx < "$PREV_SAMPLE_FILE"
  elapsed=$(( now_epoch - prev_ts ))
  delta_total=$(( cpu_total_now - prev_total ))
  delta_idle=$(( cpu_idle_now - prev_idle ))
  cpu_percent=$(awk -v dt="$delta_total" -v di="$delta_idle" \
    'BEGIN { if (dt <= 0) { print "null" } else { printf "%.1f", 100 * (dt - di) / dt } }')
  if [ "$elapsed" -gt 0 ]; then
    rx_kbps=$(awk -v now="$rx_now" -v prev="$prev_rx" -v e="$elapsed" \
      'BEGIN { d = now - prev; if (d < 0) { print "null" } else { printf "%.1f", (d / 1024) / e } }')
    tx_kbps=$(awk -v now="$tx_now" -v prev="$prev_tx" -v e="$elapsed" \
      'BEGIN { d = now - prev; if (d < 0) { print "null" } else { printf "%.1f", (d / 1024) / e } }')
  fi
fi
echo "$now_epoch $cpu_total_now $cpu_idle_now $rx_now $tx_now" > "$PREV_SAMPLE_FILE"

network_kbps="null"
if [ "$rx_kbps" != "null" ] && [ "$tx_kbps" != "null" ]; then
  network_kbps=$(awk -v r="$rx_kbps" -v t="$tx_kbps" 'BEGIN { printf "%.1f", r + t }')
fi

network_json=$(jq -n \
  --arg iface "${iface:-}" \
  --argjson rx "$rx_kbps" \
  --argjson tx "$tx_kbps" \
  '{interface: (if $iface == "" then null else $iface end), rx_kbps: $rx, tx_kbps: $tx}')

maintenance_json=$(jq -n \
  --argjson reboot "$reboot_required" \
  --argjson updates "$updates_available" \
  '{reboot_required: $reboot, updates_available: $updates}')

# ---- rolling history (persisted between runs in $HIST_FILE) ----
if [ -f "$HIST_FILE" ]; then
  prev_hist=$(cat "$HIST_FILE")
else
  prev_hist='{"cpu_load":[],"cpu_percent":[],"memory_percent":[],"temp_c":[],"network_kbps":[]}'
fi

new_hist=$(echo "$prev_hist" | jq \
  --argjson load "$load1" \
  --argjson cpu_pct "$cpu_percent" \
  --argjson mem "$mem_percent" \
  --argjson temp "$temp_c" \
  --argjson netkbps "$network_kbps" \
  --argjson n "$HIST_LEN" \
  '.cpu_load = ((.cpu_load + [$load]) | if length > $n then .[1:] else . end) |
   .memory_percent = ((.memory_percent + [$mem]) | if length > $n then .[1:] else . end) |
   .temp_c = ((if $temp == null then .temp_c else (.temp_c + [$temp]) end)
              | if length > $n then .[1:] else . end) |
   .cpu_percent = ((if $cpu_pct == null then .cpu_percent else (.cpu_percent + [$cpu_pct]) end)
              | if length > $n then .[1:] else . end) |
   .network_kbps = ((if $netkbps == null then .network_kbps else (.network_kbps + [$netkbps]) end)
              | if length > $n then .[1:] else . end)')
# temp_c/cpu_percent/network_kbps are all only appended when a real
# reading exists (not on the very first run, or if a sensor is
# missing) — pushing `null` into any of these would break the client's
# sparkline math (plain arithmetic over the values, not null-aware) for
# every point on that chart, not just the missing one.
echo "$new_hist" > "$HIST_FILE"

jq -n \
  --arg generated_at "$now_iso" \
  --arg hostname "$hostname_val" \
  --argjson uptime_seconds "$uptime_seconds" \
  --argjson cpu_cores "$cpu_cores" \
  --argjson cpu_percent "$cpu_percent" \
  --argjson load_avg "[$load1, $load5, $load15]" \
  --argjson mem_used_mb "$mem_used_mb" \
  --argjson mem_total_mb "$mem_total_mb" \
  --argjson mem_percent "$mem_percent" \
  --argjson swap_used_mb "$swap_used_mb" \
  --argjson swap_total_mb "$swap_total_mb" \
  --argjson swap_percent "$swap_percent" \
  --argjson disks "$disks_json" \
  --argjson temp_c "$temp_c" \
  --argjson history "$new_hist" \
  --argjson services "$services_json" \
  --argjson network "$network_json" \
  --argjson maintenance "$maintenance_json" \
  --arg last_successful_deploy "$last_deploy" \
  --argjson containers "$containers_json" \
  '{
    generated_at: $generated_at,
    hostname: $hostname,
    uptime_seconds: $uptime_seconds,
    cpu: {cores: $cpu_cores, percent: $cpu_percent, load_avg: $load_avg},
    memory: {used_mb: $mem_used_mb, total_mb: $mem_total_mb, percent: $mem_percent},
    swap: {used_mb: $swap_used_mb, total_mb: $swap_total_mb, percent: $swap_percent},
    disks: $disks,
    temp_c: $temp_c,
    history: $history,
    services: $services,
    network: $network,
    maintenance: $maintenance,
    last_successful_deploy: (if $last_successful_deploy == "" then null else $last_successful_deploy end),
    containers: $containers
  }' > "${OUT_FILE}.tmp"

# Atomic-ish swap so the client never reads a half-written file.
mv "${OUT_FILE}.tmp" "$OUT_FILE"
