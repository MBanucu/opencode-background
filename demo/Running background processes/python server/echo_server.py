import http.server
import socketserver
from datetime import datetime
import json

class EchoHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        msg = post_data.decode('utf-8')
        print(msg, flush=True)
        now = datetime.now().astimezone().isoformat(timespec='seconds')
        try:
            server_ip, server_port = self.connection.getsockname()[:2]
            server_info = f'{server_ip}:{server_port}'
        except Exception:
            server_info = 'unknown'
        log_object = {
            'timestamp': now,
            'message': msg,
            'client_ip': self.client_address[0],
            'server': server_info
        }
        log_line = json.dumps(log_object, indent=2)
        with open('echo_server.log', 'a') as f:
            f.write(log_line + '\n')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(log_line.encode('utf-8'))

if __name__ == '__main__':
    with socketserver.TCPServer(("", 0), EchoHandler) as httpd:
        port = httpd.server_address[1]
        print(f"Server running on port {port}", flush=True)
        httpd.serve_forever()