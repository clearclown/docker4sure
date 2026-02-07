#!/usr/bin/env python3
"""docker4sure: Lightweight port monitor HTTP server.
Serves JSON output of listening ports on the host.
Runs on port 9999.
"""

import json
import subprocess
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler


def get_listening_ports():
    """Parse ss -tlnp output into structured data."""
    try:
        result = subprocess.run(
            ["ss", "-tlnp"],
            capture_output=True, text=True, timeout=5
        )
        lines = result.stdout.strip().split("\n")
    except (subprocess.TimeoutExpired, FileNotFoundError):
        try:
            result = subprocess.run(
                ["netstat", "-tlnp"],
                capture_output=True, text=True, timeout=5
            )
            lines = result.stdout.strip().split("\n")
        except Exception:
            return []

    ports = []
    for line in lines[1:]:  # skip header
        parts = line.split()
        if len(parts) < 4:
            continue
        local_addr = parts[3]
        # Extract port from address
        if ":" in local_addr:
            port_str = local_addr.rsplit(":", 1)[-1]
            try:
                port = int(port_str)
            except ValueError:
                continue
            addr = local_addr.rsplit(":", 1)[0]
        else:
            continue

        process = parts[-1] if len(parts) > 5 else ""
        ports.append({
            "port": port,
            "address": addr,
            "process": process,
            "raw": line.strip()
        })

    return ports


class PortMonitorHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/ports", "/", "/health"):
            data = {
                "hostname": socket.gethostname(),
                "ports": get_listening_ports()
            }
            response = json.dumps(data, indent=2)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(response.encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # suppress access logs


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 9999), PortMonitorHandler)
    print("Port monitor listening on :9999")
    server.serve_forever()
