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
# Requires: jq (JSON construction). lm-sensors is optional — the
# temperature reading degrades to `null` if it isn't installed/
# configured, everything else still works. Docker container reporting
# is optional too — skipped entirely (empty list) if `docker` isn't on
# PATH or the current user can't query it.
set -euo pipefail

OUT_FILE="/var/www/cheadle-masjid-display/server-stats.json"
HIST_FILE="$HOME/.server-stats-history.json"
DEPLOY_MARKER="/var/www/cheadle-masjid-display/.last-successful-deploy"
HIST_LEN=24   # ~4 minutes of history at the default 10s run interval

now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
hostname_val=$(hostname)
uptime_seconds=$(awk '{print int($1)}' /proc/uptime)

read -r load1 load5 load15 _ < /proc/loadavg

mem_total_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
mem_total_mb=$(( mem_total_kb / 1024 ))
mem_used_mb=$(( mem_used_kb / 1024 ))
mem_percent=$(( mem_used_kb * 100 / mem_total_kb ))

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

services_json=$(jq -n \
  --argjson apache "$apache_active" \
  --argjson ssh "$ssh_active" \
  --argjson runner "$runner_active" \
  '[
    {name: "apache2", label: "Apache", active: $apache},
    {name: "ssh", label: "SSH", active: $ssh},
    {name: "actions.runner", label: "GitHub Actions runner", active: $runner}
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

# ---- rolling history (persisted between runs in $HIST_FILE) ----
if [ -f "$HIST_FILE" ]; then
  prev_hist=$(cat "$HIST_FILE")
else
  prev_hist='{"cpu_load":[],"memory_percent":[],"temp_c":[]}'
fi

new_hist=$(echo "$prev_hist" | jq \
  --argjson load "$load1" \
  --argjson mem "$mem_percent" \
  --argjson temp "$temp_c" \
  --argjson n "$HIST_LEN" \
  '.cpu_load = ((.cpu_load + [$load]) | if length > $n then .[1:] else . end) |
   .memory_percent = ((.memory_percent + [$mem]) | if length > $n then .[1:] else . end) |
   .temp_c = ((if $temp == null then .temp_c else (.temp_c + [$temp]) end)
              | if length > $n then .[1:] else . end)')
# temp_c is deliberately only appended when a real reading exists —
# pushing `null` into the array would break the client's sparkline math
# (it does plain arithmetic over the values, not null-aware) for every
# point, not just the missing one.
echo "$new_hist" > "$HIST_FILE"

jq -n \
  --arg generated_at "$now_iso" \
  --arg hostname "$hostname_val" \
  --argjson uptime_seconds "$uptime_seconds" \
  --argjson load_avg "[$load1, $load5, $load15]" \
  --argjson mem_used_mb "$mem_used_mb" \
  --argjson mem_total_mb "$mem_total_mb" \
  --argjson mem_percent "$mem_percent" \
  --argjson disks "$disks_json" \
  --argjson temp_c "$temp_c" \
  --argjson history "$new_hist" \
  --argjson services "$services_json" \
  --arg last_successful_deploy "$last_deploy" \
  --argjson containers "$containers_json" \
  '{
    generated_at: $generated_at,
    hostname: $hostname,
    uptime_seconds: $uptime_seconds,
    load_avg: $load_avg,
    memory: {used_mb: $mem_used_mb, total_mb: $mem_total_mb, percent: $mem_percent},
    disks: $disks,
    temp_c: $temp_c,
    history: $history,
    services: $services,
    last_successful_deploy: (if $last_successful_deploy == "" then null else $last_successful_deploy end),
    containers: $containers
  }' > "${OUT_FILE}.tmp"

# Atomic-ish swap so the client never reads a half-written file.
mv "${OUT_FILE}.tmp" "$OUT_FILE"
