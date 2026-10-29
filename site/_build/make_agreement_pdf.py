#!/usr/bin/env python3
"""Print the coach agreement page to PDF, once per language.

    python3 _build/make_agreement_pdf.py            (from the site/ folder)

Serves site/ on a local port and prints /coach-agreement and
/ar/coach-agreement in headless Chrome, which applies the page's print
stylesheet (no header or footer, A4, black on white). Writes
coach-agreement.pdf and ar/coach-agreement.pdf next to the pages. Run it after
build.py whenever the agreement text changes, then build again so the
committed PDFs are the ones the site links to.
"""

import functools
import http.server
import os
import subprocess
import tempfile
import threading

CHROME = os.environ.get(
    "CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class _Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def translate_path(self, path):  # /coach-agreement -> coach-agreement.html
        out = super().translate_path(path)
        return out + ".html" if not os.path.exists(out) and os.path.exists(out + ".html") else out


def main() -> None:
    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", 0), functools.partial(_Quiet, directory=SITE))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    port = server.server_address[1]
    try:
        with tempfile.TemporaryDirectory() as profile:
            for url_path, out in (("/coach-agreement", "coach-agreement.pdf"),
                                  ("/ar/coach-agreement", "ar/coach-agreement.pdf")):
                target = os.path.join(SITE, out)
                subprocess.run(
                    [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
                     f"--user-data-dir={profile}", "--no-pdf-header-footer",
                     "--virtual-time-budget=4000", f"--print-to-pdf={target}",
                     f"http://127.0.0.1:{port}{url_path}"],
                    check=True, capture_output=True, timeout=120)
                print("  wrote", out, os.path.getsize(target), "bytes")
    finally:
        server.shutdown()


if __name__ == "__main__":
    main()
