#!/usr/bin/env python3
"""
Bricolage update tool — opens a local webpage to update now/games/books data.
Double-click this file (or run: python3 update.command) to launch.
Server shuts down automatically after saving.
"""
import json, os, subprocess, webbrowser, threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs
from datetime import date

BASE        = os.path.dirname(os.path.abspath(__file__))
NOW_FILE    = os.path.join(BASE, "data/now.json")
GAMES_FILE  = os.path.join(BASE, "data/games.json")
BOOKS_FILE  = os.path.join(BASE, "data/books.json")
PORT        = 8765

# ── load helpers ─────────────────────────────────────────────────────────────
def load():
    with open(NOW_FILE)   as f: now   = json.load(f)
    with open(GAMES_FILE) as f: games = json.load(f)
    with open(BOOKS_FILE) as f: books = json.load(f)
    return now, games, books

def get_now_item(now, label):
    for item in now["items"]:
        if item["label"] == label:
            return item
    return {}

def save_and_push(now, games, books):
    with open(NOW_FILE,   "w") as f: json.dump(now,   f, indent=2)
    with open(GAMES_FILE, "w") as f: json.dump(games, f, indent=2)
    with open(BOOKS_FILE, "w") as f: json.dump(books, f, indent=2)
    subprocess.run(["git", "add", "data/now.json", "data/games.json", "data/books.json"], cwd=BASE)
    subprocess.run(["git", "commit", "-m", "Update now/games/books data", "--quiet"], cwd=BASE)
    result = subprocess.run(["git", "push", "--quiet"], cwd=BASE, capture_output=True)
    return result.returncode == 0

# ── HTML page ─────────────────────────────────────────────────────────────────
def build_html(now, games, books):
    reading  = now_item(now, "Reading")
    playing  = now_item(now, "Playing")
    watching = now_item(now, "Watching")
    np       = games["now_playing"][0] if games["now_playing"] else {}
    cur_book = books["reading"][0]     if books["reading"]     else {}
    today    = str(date.today())

    def val(d, k, fallback=""): return str(d.get(k, fallback))
    def finrow(i, g):
        return f"""
        <tr>
          <td class="num">{i+1}</td>
          <td>{g['title']}</td>
          <td>{g.get('platform','')}</td>
          <td>{g.get('finished','')}</td>
          <td>{'★' * g.get('rating',0)}{'☆' * (5 - g.get('rating',0))}</td>
        </tr>"""
    def bookrow(i, b):
        pct = int((b.get('progress') or 0) * 100)
        return f"""
        <tr>
          <td class="num">{i+1}</td>
          <td>{b['title']}</td>
          <td>{b.get('author','')}</td>
          <td>{b.get('finished','')}</td>
          <td>{'★' * b.get('rating',0)}{'☆' * (5 - b.get('rating',0))}</td>
        </tr>"""

    fin_rows  = "".join(finrow(i,g)  for i,g in enumerate(games["finished"]))
    book_rows = "".join(bookrow(i,b) for i,b in enumerate(books["finished"] or []))

    fin_table = f"""
      <table>
        <thead><tr><th>#</th><th>Title</th><th>Platform</th><th>Finished</th><th>Rating</th></tr></thead>
        <tbody>{fin_rows}</tbody>
      </table>""" if fin_rows else "<p class='empty'>No finished games yet.</p>"

    book_fin_table = f"""
      <table>
        <thead><tr><th>#</th><th>Title</th><th>Author</th><th>Finished</th><th>Rating</th></tr></thead>
        <tbody>{book_rows}</tbody>
      </table>""" if book_rows else "<p class='empty'>No finished books yet.</p>"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Bricolage · Update</title>
<style>
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  :root {{
    --bg:       #0f0f11;
    --surface:  #1a1a1e;
    --border:   #2e2e34;
    --text:     #e8e6e1;
    --dim:      #888;
    --accent:   oklch(72% 0.18 260);
    --green:    oklch(72% 0.18 145);
    --red:      oklch(65% 0.20 25);
    --radius:   10px;
    --font:     -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    --mono:     "JetBrains Mono", "Fira Mono", monospace;
  }}
  body {{ background: var(--bg); color: var(--text); font-family: var(--font);
         font-size: 15px; line-height: 1.6; padding: 2rem; max-width: 760px; margin: 0 auto; }}
  h1 {{ font-size: 1.6rem; font-weight: 700; margin-bottom: 0.25rem; }}
  .subtitle {{ color: var(--dim); font-size: 0.85rem; font-family: var(--mono); margin-bottom: 2.5rem; }}
  section {{ background: var(--surface); border: 1px solid var(--border);
             border-radius: var(--radius); padding: 1.5rem; margin-bottom: 1.25rem; }}
  h2 {{ font-size: 0.7rem; font-family: var(--mono); text-transform: uppercase;
        letter-spacing: 0.1em; color: var(--accent); margin-bottom: 1.25rem; }}
  .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }}
  .grid.three {{ grid-template-columns: 1fr 1fr 1fr; }}
  .field {{ display: flex; flex-direction: column; gap: 0.35rem; }}
  label {{ font-size: 0.75rem; font-family: var(--mono); color: var(--dim); text-transform: uppercase; letter-spacing: 0.05em; }}
  input, select {{
    background: var(--bg); border: 1px solid var(--border); border-radius: 6px;
    color: var(--text); font-family: var(--font); font-size: 0.95rem;
    padding: 0.5rem 0.75rem; width: 100%;
    transition: border-color 0.15s;
  }}
  input:focus, select:focus {{ outline: none; border-color: var(--accent); }}
  .stars-input {{ display: flex; gap: 0.5rem; align-items: center; padding-top: 0.15rem; }}
  .stars-input input[type=radio] {{ display: none; }}
  .stars-input label {{ font-size: 1.4rem; cursor: pointer; color: var(--dim);
                        text-transform: none; letter-spacing: 0; padding: 0; }}
  .stars-input input[type=radio]:checked ~ label,
  .stars-input label:hover,
  .stars-input label:hover ~ label {{ color: oklch(80% 0.18 60); }}
  .progress-wrap {{ display: flex; align-items: center; gap: 0.75rem; }}
  .progress-wrap input[type=range] {{ flex: 1; accent-color: var(--accent); }}
  .progress-wrap .pct {{ font-family: var(--mono); font-size: 0.8rem; color: var(--dim); min-width: 3ch; }}
  table {{ width: 100%; border-collapse: collapse; margin-top: 1rem; font-size: 0.875rem; }}
  th {{ text-align: left; font-family: var(--mono); font-size: 0.65rem; text-transform: uppercase;
        letter-spacing: 0.08em; color: var(--dim); padding: 0 0.5rem 0.5rem; border-bottom: 1px solid var(--border); }}
  td {{ padding: 0.45rem 0.5rem; border-bottom: 1px solid var(--border); vertical-align: middle; }}
  td.num {{ color: var(--dim); font-family: var(--mono); font-size: 0.75rem; width: 2rem; }}
  tr:last-child td {{ border-bottom: none; }}
  .empty {{ color: var(--dim); font-family: var(--mono); font-size: 0.8rem; margin-top: 0.75rem; }}
  .divider {{ height: 1px; background: var(--border); margin: 1.25rem 0; }}
  .finish-toggle {{ font-family: var(--mono); font-size: 0.8rem; color: var(--accent);
                    cursor: pointer; background: none; border: none; padding: 0;
                    margin-top: 0.75rem; display: block; }}
  .finish-toggle:hover {{ text-decoration: underline; }}
  .finish-fields {{ margin-top: 1rem; display: none; }}
  .finish-fields.open {{ display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }}
  .save-bar {{ position: sticky; bottom: 1.5rem; text-align: center; margin-top: 1.5rem; }}
  .save-btn {{
    background: var(--accent); color: #fff; border: none; border-radius: 8px;
    font-size: 1rem; font-weight: 600; padding: 0.75rem 3rem; cursor: pointer;
    box-shadow: 0 4px 24px oklch(72% 0.18 260 / 0.35);
    transition: opacity 0.15s;
  }}
  .save-btn:hover {{ opacity: 0.85; }}
  .save-btn:disabled {{ opacity: 0.4; cursor: not-allowed; }}
  #status {{ font-family: var(--mono); font-size: 0.85rem; margin-top: 0.75rem;
             min-height: 1.2em; color: var(--dim); }}
  #status.ok  {{ color: var(--green); }}
  #status.err {{ color: var(--red); }}
</style>
</head>
<body>
<h1>Bricolage</h1>
<p class="subtitle">bricolage.micro.blog · update data</p>

<form id="form" method="POST" action="/save">

  <!-- ── NOW PANEL ──────────────────────────────────────────────── -->
  <section>
    <h2>Now panel</h2>
    <div class="grid">
      <div class="field">
        <label>Reading</label>
        <input name="reading_value" value="{val(reading,'value')}">
      </div>
      <div class="field">
        <label>Sub-line</label>
        <input name="reading_sub" value="{val(reading,'sub')}">
      </div>
      <div class="field">
        <label>Playing</label>
        <input name="playing_value" value="{val(playing,'value')}">
      </div>
      <div class="field">
        <label>Sub-line</label>
        <input name="playing_sub" value="{val(playing,'sub')}">
      </div>
      <div class="field">
        <label>Watching</label>
        <input name="watching_value" value="{val(watching,'value')}">
      </div>
      <div class="field">
        <label>Sub-line</label>
        <input name="watching_sub" value="{val(watching,'sub')}">
      </div>
    </div>
  </section>

  <!-- ── NOW PLAYING ────────────────────────────────────────────── -->
  <section>
    <h2>Now playing</h2>
    <div class="grid three">
      <div class="field">
        <label>Title</label>
        <input name="game_title" value="{val(np,'title')}">
      </div>
      <div class="field">
        <label>Platform</label>
        <input name="game_platform" value="{val(np,'platform','PC')}">
      </div>
      <div class="field">
        <label>Hours</label>
        <input name="game_hours" type="number" min="0" step="0.5" value="{val(np,'hours',0)}">
      </div>
    </div>

    <button type="button" class="finish-toggle" onclick="toggleFinish(this)">
      + Mark as finished &amp; start new game
    </button>
    <div class="finish-fields" id="finish-game">
      <div class="field">
        <label>Finished date</label>
        <input name="game_fin_date" type="date" value="{today}">
      </div>
      <div class="field">
        <label>Rating</label>
        <div class="stars-input" id="game-stars">
          {"".join(f'<input type="radio" name="game_rating" id="gr{i}" value="{i}"><label for="gr{i}">★</label>' for i in range(5,0,-1))}
        </div>
      </div>
      <div class="field">
        <label>New game title (optional)</label>
        <input name="new_game_title" placeholder="leave blank to clear now-playing">
      </div>
      <div class="field">
        <label>New game platform</label>
        <input name="new_game_platform" value="PC">
      </div>
    </div>

    <div class="divider" style="margin-top:1.5rem"></div>
    <h2 style="margin-top:1rem">Finished games</h2>
    {fin_table}
  </section>

  <!-- ── NOW READING ────────────────────────────────────────────── -->
  <section>
    <h2>Now reading</h2>
    <div class="grid">
      <div class="field">
        <label>Title</label>
        <input name="book_title" value="{val(cur_book,'title')}">
      </div>
      <div class="field">
        <label>Author</label>
        <input name="book_author" value="{val(cur_book,'author')}">
      </div>
      <div class="field" style="grid-column:span 2">
        <label>Cover URL (optional)</label>
        <input name="book_cover" value="{val(cur_book,'cover_url')}">
      </div>
      <div class="field">
        <label>Started</label>
        <input name="book_started" type="date" value="{val(cur_book,'started',today)}">
      </div>
      <div class="field">
        <label>Progress — <span id="pct-label">{int((cur_book.get('progress') or 0)*100)}%</span></label>
        <div class="progress-wrap">
          <input type="range" name="book_progress" min="0" max="100" step="1"
                 value="{int((cur_book.get('progress') or 0)*100)}"
                 oninput="document.getElementById('pct-label').textContent=this.value+'%'">
        </div>
      </div>
    </div>

    <button type="button" class="finish-toggle" onclick="toggleFinish(this)">
      + Mark as finished &amp; start new book
    </button>
    <div class="finish-fields" id="finish-book">
      <div class="field">
        <label>Finished date</label>
        <input name="book_fin_date" type="date" value="{today}">
      </div>
      <div class="field">
        <label>Rating</label>
        <div class="stars-input" id="book-stars">
          {"".join(f'<input type="radio" name="book_rating" id="br{i}" value="{i}"><label for="br{i}">★</label>' for i in range(5,0,-1))}
        </div>
      </div>
      <div class="field">
        <label>New book title (optional)</label>
        <input name="new_book_title" placeholder="leave blank to clear now-reading">
      </div>
      <div class="field">
        <label>New book author</label>
        <input name="new_book_author">
      </div>
    </div>

    <div class="divider" style="margin-top:1.5rem"></div>
    <h2 style="margin-top:1rem">Finished books</h2>
    {book_fin_table}
  </section>

</form>

<div class="save-bar">
  <button class="save-btn" onclick="save()">Save &amp; Push</button>
  <div id="status"></div>
</div>

<script>
function toggleFinish(btn) {{
  var id  = btn.nextElementSibling.id;
  var el  = document.getElementById(id);
  var open = el.classList.toggle('open');
  btn.textContent = open
    ? btn.textContent.replace('+ Mark','− Cancel')
    : btn.textContent.replace('− Cancel','+ Mark');
}}

function save() {{
  var btn = document.querySelector('.save-btn');
  var st  = document.getElementById('status');
  btn.disabled = true;
  st.className = '';
  st.textContent = 'Saving…';
  var data = new FormData(document.getElementById('form'));
  fetch('/save', {{ method:'POST', body: new URLSearchParams(data) }})
    .then(function(r) {{ return r.json(); }})
    .then(function(d) {{
      if (d.ok) {{
        st.className = 'ok';
        st.textContent = '✓ Pushed — site updates on next page load.';
        setTimeout(function() {{ window.close(); }}, 1800);
      }} else {{
        st.className = 'err';
        st.textContent = '✗ ' + (d.error || 'Something went wrong');
        btn.disabled = false;
      }}
    }})
    .catch(function() {{
      st.className = 'err';
      st.textContent = '✗ Could not reach local server.';
      btn.disabled = false;
    }});
}}
</script>
</body>
</html>"""

def now_item(now, label):
    for item in now["items"]:
        if item["label"] == label:
            return item
    return {}

# ── request handler ───────────────────────────────────────────────────────────
server_ref = None

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass   # silence request logs

    def do_GET(self):
        now, games, books = load()
        html = build_html(now, games, books)
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode())

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body   = self.rfile.read(length).decode()
        params = {k: v[0] for k, v in parse_qs(body).items() if v}

        try:
            now, games, books = load()

            # ── now panel ────────────────────────────────────────
            for label, key in [("Reading","reading"), ("Playing","playing"), ("Watching","watching")]:
                item = now_item(now, label)
                if not item:
                    item = {"label": label, "value": ""}
                    now["items"].append(item)
                item["value"] = params.get(f"{key}_value", item.get("value",""))
                sub = params.get(f"{key}_sub","").strip()
                if sub: item["sub"] = sub
                elif "sub" in item: del item["sub"]

            # ── game: update or finish ────────────────────────────
            finish_game = params.get("game_fin_date","").strip()
            if finish_game and games["now_playing"]:
                old = games["now_playing"][0]
                rating = int(params.get("game_rating", 4))
                games["finished"].insert(0, {
                    "title":    old["title"],
                    "platform": old["platform"],
                    "finished": finish_game,
                    "rating":   rating,
                })
                new_title = params.get("new_game_title","").strip()
                if new_title:
                    from datetime import date as dt
                    games["now_playing"] = [{
                        "title":    new_title,
                        "platform": params.get("new_game_platform","PC"),
                        "hours":    0,
                        "started":  str(dt.today()),
                    }]
                    # update now panel playing line
                    pi = now_item(now, "Playing")
                    if pi: pi["value"] = new_title; pi["sub"] = params.get("new_game_platform","PC") + " · just started"
                else:
                    games["now_playing"] = []
            else:
                title = params.get("game_title","").strip()
                if title:
                    if not games["now_playing"]:
                        from datetime import date as dt
                        games["now_playing"] = [{"title":title,"platform":"PC","hours":0,"started":str(dt.today())}]
                    np = games["now_playing"][0]
                    np["title"]    = title
                    np["platform"] = params.get("game_platform","PC")
                    np["hours"]    = float(params.get("game_hours",0) or 0)

            # ── book: update or finish ────────────────────────────
            finish_book = params.get("book_fin_date","").strip()
            if finish_book and books["reading"]:
                old = books["reading"][0]
                rating = int(params.get("book_rating", 4))
                if "finished" not in books: books["finished"] = []
                books["finished"].insert(0, {
                    "title":    old["title"],
                    "author":   old.get("author",""),
                    "finished": finish_book,
                    "rating":   rating,
                })
                new_title = params.get("new_book_title","").strip()
                if new_title:
                    from datetime import date as dt
                    books["reading"] = [{
                        "title":     new_title,
                        "author":    params.get("new_book_author",""),
                        "cover_url": "",
                        "progress":  0.0,
                        "started":   str(dt.today()),
                    }]
                    ri = now_item(now, "Reading")
                    if ri: ri["value"] = new_title; ri["sub"] = "by " + params.get("new_book_author","")
                else:
                    books["reading"] = []
            else:
                btitle = params.get("book_title","").strip()
                if btitle:
                    if not books["reading"]:
                        from datetime import date as dt
                        books["reading"] = [{"title":btitle,"author":"","cover_url":"","progress":0,"started":str(dt.today())}]
                    cb = books["reading"][0]
                    cb["title"]     = btitle
                    cb["author"]    = params.get("book_author","")
                    cb["cover_url"] = params.get("book_cover","")
                    cb["started"]   = params.get("book_started","")
                    cb["progress"]  = round(int(params.get("book_progress",0)) / 100, 2)
                    # sync now panel reading sub
                    ri = now_item(now, "Reading")
                    if ri:
                        pct = int(cb["progress"]*100)
                        ri["value"] = btitle
                        ri["sub"]   = "by " + cb["author"] + (" · " + str(pct) + "%" if pct else "")

            ok = save_and_push(now, games, books)
            resp = json.dumps({"ok": ok, "error": "git push failed" if not ok else ""})

        except Exception as e:
            resp = json.dumps({"ok": False, "error": str(e)})

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(resp.encode())

        if json.loads(resp).get("ok"):
            threading.Thread(target=lambda: (
                __import__("time").sleep(0.5),
                server_ref.shutdown()
            ), daemon=True).start()

    def log_request(self, *a): pass

# ── main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    server_ref = HTTPServer(("localhost", PORT), Handler)
    url = f"http://localhost:{PORT}"
    threading.Timer(0.3, lambda: webbrowser.open(url)).start()
    print(f"Opening {url} …  (server shuts down after saving)")
    try:
        server_ref.serve_forever()
    except KeyboardInterrupt:
        pass
    print("Done.")
