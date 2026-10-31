"""tools/pysqf_modules/webpages.py -- the serve() handshake.

The server hands a page to a client only when the client does not already
have those bytes. Two ways a client can already have them:

  * it cached a previous reply and sends that reply's version back as `have`;
  * it has never asked before (`have == ""`) and the served file is byte-identical
    to the mission baseline this repo packs into the PBO -- which is the state
    every deploy leaves behind, so it is the common case and must cost no bytes.

Run:  python3 -m unittest tools/test_webpages.py
"""
import hashlib
import os
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "pysqf_modules"))
sys.path.insert(0, str(Path.home() / "PySQF" / "python"))

import webpages  # noqa: E402


class ServeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.web = root / "web"
        self.base = root / "mission"
        (self.web / "ui" / "html").mkdir(parents=True)
        (self.base / "ui" / "html").mkdir(parents=True)
        self._saved = (webpages.ROOT, webpages.BASELINE)
        webpages.ROOT = self.web.resolve()
        webpages.BASELINE = self.base.resolve()

    def tearDown(self):
        webpages.ROOT, webpages.BASELINE = self._saved
        self.tmp.cleanup()

    def _write(self, tree, rel, text):
        p = tree / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(text.encode("utf-8"))
        return p

    def test_missing_page_is_nothing_to_serve(self):
        self.assertEqual(webpages.serve("ui\\html\\nope.html", ""), ["", "", ""])

    def test_identical_to_baseline_and_no_have_is_unchanged(self):
        html = "<!doctype html><title>x</title>\n"
        self._write(self.web, "ui/html/deck.html", html)
        self._write(self.base, "ui/html/deck.html", html)
        status, markup, version = webpages.serve("ui\\html\\deck.html", "")
        self.assertEqual(status, "unchanged")
        self.assertEqual(markup, "")
        self.assertEqual(version, hashlib.sha1(html.encode()).hexdigest())

    def test_differs_from_baseline_ships_page_with_version(self):
        self._write(self.web, "ui/html/deck.html", "<p>new</p>")
        self._write(self.base, "ui/html/deck.html", "<p>old</p>")
        status, markup, version = webpages.serve("ui\\html\\deck.html", "")
        self.assertEqual(status, "page")
        self.assertEqual(markup, "<p>new</p>")
        self.assertEqual(version, hashlib.sha1(b"<p>new</p>").hexdigest())

    def test_no_baseline_at_all_ships_page(self):
        self._write(self.web, "ui/html/only.html", "<p>x</p>")
        status, markup, _ = webpages.serve("ui\\html\\only.html", "")
        self.assertEqual((status, markup), ("page", "<p>x</p>"))

    def test_have_matching_version_is_unchanged_even_when_baseline_differs(self):
        self._write(self.web, "ui/html/deck.html", "<p>new</p>")
        self._write(self.base, "ui/html/deck.html", "<p>old</p>")
        v = hashlib.sha1(b"<p>new</p>").hexdigest()
        self.assertEqual(webpages.serve("ui\\html\\deck.html", v), ["unchanged", "", v])

    def test_stale_have_ships_page(self):
        self._write(self.web, "ui/html/deck.html", "<p>v2</p>")
        self._write(self.base, "ui/html/deck.html", "<p>v2</p>")   # baseline identical, but the
        v1 = hashlib.sha1(b"<p>v1</p>").hexdigest()                 # client says it holds v1
        status, markup, version = webpages.serve("ui\\html\\deck.html", v1)
        # The client's cached override is older than the file: ship the file so the
        # cache is corrected, even though the PBO happens to match it too.
        self.assertEqual(status, "page")
        self.assertEqual(markup, "<p>v2</p>")
        self.assertEqual(version, hashlib.sha1(b"<p>v2</p>").hexdigest())

    def test_bytes_are_exact_not_newline_translated(self):
        html = "a\r\nb\r\n"
        self._write(self.web, "ui/html/crlf.html", html)
        status, markup, _ = webpages.serve("ui\\html\\crlf.html", "")
        self.assertEqual((status, markup), ("page", html))

    def test_traversal_and_non_page_refused(self):
        self._write(self.web, "secret.txt", "nope")
        self.assertEqual(webpages.serve("..\\..\\etc\\passwd", ""), ["", "", ""])
        self.assertEqual(webpages.serve("secret.txt", ""), ["", "", ""])

    def test_oversized_page_not_served(self):
        self._write(self.web, "ui/html/big.html", "x" * (webpages.MAX_BYTES + 1))
        self.assertEqual(webpages.serve("ui\\html\\big.html", ""), ["", "", ""])


if __name__ == "__main__":
    unittest.main()
