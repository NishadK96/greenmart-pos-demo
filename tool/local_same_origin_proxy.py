#!/usr/bin/env python3
"""Serve Flutter Web and proxy Connector requests through one local origin."""

from http.client import HTTPConnection
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse


HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}


class SameOriginHandler(SimpleHTTPRequestHandler):
    backend_host = "127.0.0.1"
    backend_port = 8080

    def _proxy(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else None
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_BY_HOP and key.lower() != "host"
        }
        headers["Host"] = f"{self.backend_host}:{self.backend_port}"
        connection = HTTPConnection(self.backend_host, self.backend_port, timeout=30)
        try:
            connection.request(self.command, self.path, body=body, headers=headers)
            response = connection.getresponse()
            payload = response.read()
            self.send_response(response.status, response.reason)
            for key, value in response.getheaders():
                if key.lower() not in HOP_BY_HOP and key.lower() != "content-length":
                    self.send_header(key, value)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        finally:
            connection.close()

    def _serve(self):
        requested = Path(self.translate_path(self.path.split("?", 1)[0]))
        if not requested.exists() and "." not in requested.name:
            self.path = "/index.html"
        super().do_GET()

    def do_GET(self):
        if self.path.startswith("/connector/"):
            self._proxy()
        else:
            self._serve()

    def do_POST(self):
        self._proxy()

    def do_PUT(self):
        self._proxy()

    def do_PATCH(self):
        self._proxy()

    def do_DELETE(self):
        self._proxy()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8081)
    parser.add_argument("--backend-port", type=int, default=8080)
    parser.add_argument("--directory", default="build/web")
    args = parser.parse_args()
    SameOriginHandler.backend_port = args.backend_port
    handler = lambda *handler_args, **kwargs: SameOriginHandler(
        *handler_args, directory=args.directory, **kwargs
    )
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Eazy POS local web: http://127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
