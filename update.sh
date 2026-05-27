#!/usr/bin/env bash
# update.sh — quickly update now.json and/or games.json and push to GitHub
set -e
cd "$(dirname "$0")"

NOW_FILE="data/now.json"
GAMES_FILE="data/games.json"

# ── helpers ──────────────────────────────────────────────────────────────────
current() { python3 -c "import json,sys; d=json.load(open('$1')); $2" 2>/dev/null || echo "?"; }
bold() { printf "\033[1m%s\033[0m" "$1"; }
dim()  { printf "\033[2m%s\033[0m" "$1"; }

ask() {
  local prompt="$1" current="$2" var="$3"
  printf "%s " "$(bold "$prompt")"
  [ -n "$current" ] && printf "%s " "$(dim "[$current]")"
  read -r input
  [ -z "$input" ] && input="$current"
  printf -v "$var" '%s' "$input"
}

# ── show current state ────────────────────────────────────────────────────────
echo ""
echo "$(bold 'Current values:')"
python3 - <<'PY'
import json
now   = json.load(open("data/now.json"))
games = json.load(open("data/games.json"))
for item in now["items"]:
    sub = f"  — {item['sub']}" if item.get("sub") else ""
    print(f"  {item['label']}: {item['value']}{sub}")
np = games["now_playing"]
if np:
    g = np[0]
    print(f"  Game detail: {g['platform']} · {g['hours']}h · started {g['started']}")
PY
echo ""

# ── what to update ────────────────────────────────────────────────────────────
echo "What do you want to update?"
echo "  1) Now Reading"
echo "  2) Now Playing"
echo "  3) Now Watching"
echo "  4) Game detail (platform / hours)"
echo "  5) Finish a game + add to finished list"
echo "  6) All of the above"
echo ""
printf "$(bold 'Choice [1-6]:') "
read -r choice
echo ""

CHANGED=0

update_now_item() {
  local label="$1"
  local cur_value cur_sub
  cur_value=$(python3 -c "import json; d=json.load(open('$NOW_FILE')); [print(i['value']) for i in d['items'] if i['label']=='$label']" 2>/dev/null)
  cur_sub=$(python3 -c "import json; d=json.load(open('$NOW_FILE')); [print(i.get('sub','')) for i in d['items'] if i['label']=='$label']" 2>/dev/null)

  ask "$label:" "$cur_value" new_value
  ask "Sub-line (author/platform/etc):" "$cur_sub" new_sub

  python3 - "$label" "$new_value" "$new_sub" <<'PY'
import json, sys
label, value, sub = sys.argv[1], sys.argv[2], sys.argv[3]
with open("data/now.json") as f: d = json.load(f)
for item in d["items"]:
    if item["label"] == label:
        item["value"] = value
        if sub: item["sub"] = sub
        elif "sub" in item: del item["sub"]
with open("data/now.json", "w") as f: json.dump(d, f, indent=2)
print(f"  ✓ {label} → {value}")
PY
  CHANGED=1
}

update_game_detail() {
  local cur_platform cur_hours cur_started
  cur_platform=$(python3 -c "import json; g=json.load(open('$GAMES_FILE'))['now_playing']; print(g[0]['platform'] if g else '')" 2>/dev/null)
  cur_hours=$(python3 -c "import json; g=json.load(open('$GAMES_FILE'))['now_playing']; print(g[0]['hours'] if g else '')" 2>/dev/null)
  cur_started=$(python3 -c "import json; g=json.load(open('$GAMES_FILE'))['now_playing']; print(g[0]['started'] if g else '')" 2>/dev/null)

  ask "Platform:" "$cur_platform" new_platform
  ask "Hours played:" "$cur_hours" new_hours
  ask "Started (YYYY-MM-DD):" "$cur_started" new_started

  python3 - "$new_platform" "$new_hours" "$new_started" <<'PY'
import json, sys
platform, hours, started = sys.argv[1], sys.argv[2], sys.argv[3]
with open("data/games.json") as f: d = json.load(f)
if d["now_playing"]:
    d["now_playing"][0].update({"platform": platform, "hours": int(hours or 0), "started": started})
with open("data/games.json", "w") as f: json.dump(d, f, indent=2)
print(f"  ✓ Game detail updated")
PY
  CHANGED=1
}

finish_game() {
  local cur_title cur_platform
  cur_title=$(python3 -c "import json; g=json.load(open('$GAMES_FILE'))['now_playing']; print(g[0]['title'] if g else '')" 2>/dev/null)
  cur_platform=$(python3 -c "import json; g=json.load(open('$GAMES_FILE'))['now_playing']; print(g[0]['platform'] if g else '')" 2>/dev/null)

  echo "$(bold 'Finishing:') $cur_title"
  ask "Finished date (YYYY-MM-DD):" "$(date +%Y-%m-%d)" fin_date
  ask "Rating (1-5):" "4" fin_rating
  ask "New game title (leave blank to clear now-playing):" "" new_title

  python3 - "$cur_title" "$cur_platform" "$fin_date" "$fin_rating" "$new_title" <<'PY'
import json, sys
title, platform, fin_date, rating, new_title = sys.argv[1:]
with open("data/games.json") as f: d = json.load(f)
# Add to finished
d["finished"].insert(0, {"title": title, "platform": platform, "finished": fin_date, "rating": int(rating)})
# Replace now_playing
if new_title:
    from datetime import date
    d["now_playing"] = [{"title": new_title, "platform": "PC", "hours": 0, "started": str(date.today())}]
else:
    d["now_playing"] = []
with open("data/games.json", "w") as f: json.dump(d, f, indent=2)
print(f"  ✓ {title} → finished list (rated {rating}/5)")
if new_title: print(f"  ✓ Now playing → {new_title}")
PY

  # Also update now.json playing line
  if [ -n "$new_title" ]; then
    python3 - "$new_title" <<'PY'
import json, sys
title = sys.argv[1]
with open("data/now.json") as f: d = json.load(f)
for item in d["items"]:
    if item["label"] == "Playing":
        item["value"] = title
        item["sub"] = "PC · just started"
with open("data/now.json", "w") as f: json.dump(d, f, indent=2)
PY
  fi
  CHANGED=1
}

case "$choice" in
  1) update_now_item "Reading" ;;
  2) update_now_item "Playing"; update_game_detail ;;
  3) update_now_item "Watching" ;;
  4) update_game_detail ;;
  5) finish_game ;;
  6) update_now_item "Reading"; update_now_item "Playing"; update_now_item "Watching"; update_game_detail ;;
  *) echo "Invalid choice, nothing changed."; exit 0 ;;
esac

# ── push ─────────────────────────────────────────────────────────────────────
if [ "$CHANGED" -eq 1 ]; then
  echo ""
  git add data/now.json data/games.json
  git commit -m "Update now/games data" --quiet
  git push --quiet
  echo "$(bold '✓ Pushed to GitHub — site updates on next page load.')"
fi
echo ""
