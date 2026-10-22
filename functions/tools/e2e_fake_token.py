"""A local stand-in for Google's OAuth token endpoint, for the emulator run.

The Firebase Admin SDK insists on credentials before it will build a Storage
client, even for the emulator. Instead of letting the emulator use the
developer's real Application Default Credentials (which could reach
production), tool/e2e_coaching.sh points a throwaway authorized-user file at
this server, which answers every refresh with a dummy token. Nothing here can
authenticate anywhere real.

    python -m tools.e2e_fake_token PORT
"""

from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802
        self.rfile.read(int(self.headers.get("Content-Length") or 0))
        body = json.dumps({"access_token": "e2e-local", "expires_in": 3600, "token_type": "Bearer"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
