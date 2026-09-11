#!/usr/bin/env python3
"""Tiny server for the target page: serves it and collects the event log back.

A page loaded over file:// cannot POST anywhere, so exactly one local server is needed.
The log is written as JSONL, one event per line — readable by anything.
"""
import http.server, json, os, socketserver, sys, threading

ROOT = os.path.dirname(os.path.abspath(__file__))
EVENTS = os.path.join(ROOT, "events.jsonl")
TARGETS = os.path.join(ROOT, "targets.json")
LOCK = threading.Lock()


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def log_message(self, *a):
        pass  # stay quiet, or the server's own log drowns the event log

    def _ok(self, body=b"ok"):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/clear"):
            with LOCK:
                open(EVENTS, "w").close()
            return self._ok(b"cleared")
        return super().do_GET()

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.path.startswith("/targets"):
            with LOCK:
                with open(TARGETS, "wb") as f:
                    f.write(raw)
            return self._ok()
        if self.path.startswith("/events"):
            try:
                events = json.loads(raw)
            except json.JSONDecodeError:
                return self._ok(b"bad json")
            with LOCK:
                with open(EVENTS, "a") as f:
                    for e in events:
                        f.write(json.dumps(e, ensure_ascii=False) + "\n")
            return self._ok()
        return self._ok(b"unknown path")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8777
    open(EVENTS, "a").close()
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", port), Handler) as srv:
        print(f"target page: http://127.0.0.1:{port}/target-page.html")
        srv.serve_forever()
