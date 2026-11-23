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
    if not args.no_watch:
        command = [sys.executable, str(ROOT / "telemetry" / "watch.py"), "--watch"]
        if args.flights:
            command += ["--flights", str(args.flights)]
        # If a watcher is already running (the Mac launcher starts one), this one steps aside.
        log = (LOCAL / "live.log").open("a")
        watcher = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
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


if __name__ == "__main__":
    main()
