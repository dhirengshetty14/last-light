"""Serve the live Last Light dashboard on this machine only, and keep Bruin refreshing behind it.

    python3 telemetry/dashboard.py --open

The page shows where each robot is failing, task by task and check by check, while a match is being
played. It reads one file, telemetry/local/dashboard.json, which the Bruin pipeline writes on every
run (asset flight.dashboard_feed). So a refresh of the page costs no query, and nothing here listens
beyond 127.0.0.1.
"""

import argparse
import json
import signal
import subprocess
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / "telemetry" / "local"
PAGE = ROOT / "telemetry" / "dashboard.html"
FEED = LOCAL / "dashboard.json"
PANELS = LOCAL / "panels"


def sponsor_state():
    """What Coach Bruin, BAND and Runware have produced, for the report's sponsor card."""
    state = {"coach": None, "band_room": None, "panel": None}
    for name, key in (("bruin-coach.json", "coach"), ("panels/latest.json", "panel")):
        try:
            state[key] = json.loads((LOCAL / name).read_text())
        except (OSError, ValueError):
            pass
    try:
        state["band_room"] = json.loads((LOCAL / "band.json").read_text()).get("room")
    except (OSError, ValueError):
        pass
    return state


class Handler(BaseHTTPRequestHandler):
    # The last feed that parsed, served again if Bruin is writing the file at this very moment.
    last_good = b"{}"

    def log_message(self, *args):
        pass

    def reply(self, status, body, kind):
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            return self.reply(200, PAGE.read_bytes(), "text/html; charset=utf-8")
        if path == "/sponsors.json":
            return self.reply(200, json.dumps(sponsor_state()).encode(), "application/json")
        if path == "/analyst":
            # The Bruin Analyst's page, rewritten by the watcher after every pipeline run.
            page = LOCAL / "analyst.html"
            if page.is_file():
                return self.reply(200, page.read_bytes(), "text/html; charset=utf-8")
            waiting = b"<!doctype html><meta http-equiv=refresh content=3><p>No robot reactions scored yet. Play a match.</p>"
            return self.reply(200, waiting, "text/html; charset=utf-8")
        if path.startswith("/panels/") and path.endswith(".png"):
            picture = PANELS / Path(path).name
            if picture.is_file():
                return self.reply(200, picture.read_bytes(), "image/png")
            return self.reply(404, b"{}", "application/json")
        if path == "/data.json":
            try:
                body = FEED.read_bytes()
                json.loads(body)
                Handler.last_good = body
            except (OSError, ValueError):
                body = Handler.last_good
            return self.reply(200, body, "application/json")
        return self.reply(404, b"{}", "application/json")


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--port", type=int, default=8960)
    cli.add_argument("--open", action="store_true", help="Open the page in your browser.")
    cli.add_argument(
        "--flights",
        type=Path,
        help="Watch this folder of match logs instead of the game's own.",
    )
    cli.add_argument(
        "--no-watch",
        action="store_true",
        help="Only serve the page; something else is running telemetry/watch.py.",
    )
    args = cli.parse_args()
    LOCAL.mkdir(exist_ok=True)
    url = f"http://127.0.0.1:{args.port}/"
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    except OSError:
        # The report is already being served, most likely by another copy of this script.
        print(f"Last Light dashboard is already running: {url}", flush=True)
        if args.open:
            webbrowser.open(url)
        return
    watcher = None
    helpers = []
    if not args.no_watch:
        command = [sys.executable, str(ROOT / "telemetry" / "watch.py"), "--watch"]
        if args.flights:
            command += ["--flights", str(args.flights)]
        # If a watcher is already running (the Mac launcher starts one), this one steps aside.
        log = (LOCAL / "live.log").open("a")
        watcher = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
        # The sponsor bridges, when they have been configured: robot talk into a BAND room, and a
        # Runware comic panel of each finished match.
        for script, needs in (("band.py", LOCAL / "band.json"), ("panels.py", LOCAL / "runware.key")):
            if needs.exists():
                side = [sys.executable, str(ROOT / "telemetry" / script), "run"]
                if args.flights:
                    side += ["--flights", str(args.flights)]
                out = (LOCAL / script.replace(".py", ".log")).open("a")
                helpers.append(subprocess.Popen(side, cwd=ROOT, stdout=out, stderr=out))
    # A plain kill (what the game launcher sends on exit) must also stop the watcher.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    print(f"Last Light dashboard: {url}", flush=True)
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if watcher:
            watcher.terminate()
        for helper in helpers:
            helper.terminate()


if __name__ == "__main__":
    main()
