#!/usr/bin/env python3
"""
Range-capable static file server for Arma mission HTTP download (dev box).

WHY NOT `python -m http.server`: it does not implement HTTP Range. Arma's mission downloader
issues ranged requests, and a server that answers a Range request with "200 + the whole file"
instead of "206 + the slice" makes the client give up on HTTP and fall back to the slow in-game
transfer -- silently, so it looks like HTTP download simply "doesn't work". Measured on this box:
`curl -r 0-999` returned 200 and all 155,969,074 bytes.

Also threaded: the stock handler is single-request, so one stalled client blocks every other.

Serves ONLY the mpmissions directory, read-only, GET/HEAD.
Usage: pbo_http.py [port] [--dir DIR]
"""
import os, re, sys, socketserver
from http.server import SimpleHTTPRequestHandler, HTTPServer

RANGE_RE = re.compile(r"bytes=(\d*)-(\d*)")


class RangeHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"          # keep-alive; Arma opens several connections

    def log_message(self, fmt, *args):     # quiet: this shares the deploy terminal
        pass

    def send_head(self):
        rng = self.headers.get("Range")
        if not rng:
            return super().send_head()
        path = self.translate_path(self.path)
        if os.path.isdir(path) or not os.path.exists(path):
            return super().send_head()
        m = RANGE_RE.match(rng.strip())
        if not m:
            return super().send_head()

        size = os.path.getsize(path)
        start_s, end_s = m.group(1), m.group(2)
        if start_s == "":                                   # suffix form: bytes=-N
            length = min(int(end_s or 0), size)
            start, end = size - length, size - 1
        else:
            start = int(start_s)
            end = int(end_s) if end_s else size - 1
        end = min(end, size - 1)
        if start > end or start >= size:                    # unsatisfiable
            self.send_response(416)
            self.send_header("Content-Range", "bytes */%d" % size)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None

        f = open(path, "rb")
        f.seek(start)
        self.send_response(206)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
        self.send_header("Content-Length", str(end - start + 1))
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        return _Slice(f, end - start + 1)

    def end_headers(self):
        self.send_header("Accept-Ranges", "bytes")          # advertise it on plain GETs too
        super().end_headers()


class _Slice:
    """File wrapper that stops after n bytes, so copyfile cannot overrun the range."""
    def __init__(self, f, n):
        self.f, self.left = f, n

    def read(self, amt=-1):
        if self.left <= 0:
            return b""
        if amt < 0 or amt > self.left:
            amt = self.left
        data = self.f.read(amt)
        self.left -= len(data)
        return data

    def close(self):
        self.f.close()


class Threaded(socketserver.ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 8092
    d = "/home/timb/arma3server_dev/mpmissions"
    if "--dir" in sys.argv:
        d = sys.argv[sys.argv.index("--dir") + 1]
    os.chdir(d)
    print("serving %s on 0.0.0.0:%d (Range enabled)" % (d, port), flush=True)
    Threaded(("0.0.0.0", port), RangeHandler).serve_forever()
