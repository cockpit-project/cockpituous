import hashlib
import hmac
import http.server
import socketserver
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


class S3ProxyHandler(http.server.BaseHTTPRequestHandler):
    def sign_request(self,
                     url: urllib.parse.ParseResult,
                     method: str,
                     headers: dict[str, str],
                     checksum: str) -> dict[str, str]:
        """Signs an AWS request using the AWS4-HMAC-SHA256 algorithm

        Taken from https://github.com/cockpit-project/bots/blob/main/lib/s3.py
        """

        # Read S3 credentials
        with open('/s3/access-key', 'r') as f:
            access_key = f.read().strip()
        with open('/s3/secret', 'r') as f:
            secret_key = f.read().strip()

        amzdate = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())

        # Header canonicalisation demands all header names in lowercase
        headers = {key.lower(): value for key, value in headers.items()}
        assert url.hostname
        headers.update({'host': url.hostname, 'x-amz-content-sha256': checksum, 'x-amz-date': amzdate})
        headers_str = ''.join(f'{k}:{v}\n' for k, v in sorted(headers.items()))
        headers_list = ';'.join(sorted(headers))

        credential_scope = f'{amzdate[:8]}/any/s3/aws4_request'
        signing_key = f'AWS4{secret_key}'.encode('ascii')
        for item in credential_scope.split('/'):
            signing_key = hmac.new(signing_key, item.encode('ascii'), hashlib.sha256).digest()

        algorithm = 'AWS4-HMAC-SHA256'
        canonical_request = f'{method}\n{url.path}\n{url.query}\n{headers_str}\n{headers_list}\n{checksum}'
        request_hash = hashlib.sha256(canonical_request.encode('ascii')).hexdigest()
        string_to_sign = f'{algorithm}\n{amzdate}\n{credential_scope}\n{request_hash}'
        signature = hmac.new(signing_key, string_to_sign.encode('ascii'), hashlib.sha256).hexdigest()
        headers['Authorization'] = (
            f'{algorithm} Credential={access_key}/{credential_scope},SignedHeaders={headers_list},Signature={signature}'
        )

        return headers

    def proxy_request(self, method: str):
        """Proxy the request to S3 with authentication"""
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'healthy\n')
            return

        # disallow directory listing
        if self.path == '/':
            self.send_response(403)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Forbidden: directory listing is not allowed\n')
            return

        s3_url = urllib.parse.urlparse(f'{S3_BUCKET_URL}{self.path}')
        headers = self.sign_request(s3_url, method, {}, hashlib.sha256(b'').hexdigest())
        request = urllib.request.Request(s3_url.geturl(), headers=headers, method=method)

        try:
            with urllib.request.urlopen(request) as response:
                # forward response
                self.send_response(response.getcode())
                # forward headers
                for header, value in response.headers.items():
                    if header.lower() not in ['connection', 'transfer-encoding']:
                        self.send_header(header, value)
                self.end_headers()
                # forward body
                self.wfile.write(response.read())

        except urllib.error.HTTPError as e:
            # forward HTTP errors
            self.send_response(e.code)
            for header, value in e.headers.items():
                if header.lower() not in ['connection', 'transfer-encoding']:
                    self.send_header(header, value)
            self.end_headers()
            self.wfile.write(e.read())

        except Exception as e:
            # Internal server error
            self.send_response(500)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Proxy error, see pod log\n')
            sys.stderr.write(f'Error while proxying request: {e}\n')

    def do_GET(self):
        self.proxy_request('GET')

    def do_HEAD(self):
        self.proxy_request('HEAD')

    def log_request(self, code='-', size='-'):
        """Log the request with X-Real-Ip and User-Agent headers"""
        x_real_ip = self.headers.get('X-Real-Ip', '-')
        user_agent = self.headers.get('User-Agent', '-')

        sys.stdout.write(f'[{self.log_date_time_string()}] {x_real_ip} '
                         f'"{self.requestline}" {code} {size} User-Agent="{user_agent}"\n')
        sys.stdout.flush()

    def log_message(self, format, *args):  # noqa: A002
        # Log to stdout
        sys.stderr.write(f"{self.address_string()} - - [{self.log_date_time_string()}] {format % args}\n")
        sys.stderr.flush()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: s3-proxy.py <s3-bucket-url> <port>")
        sys.exit(1)

    S3_BUCKET_URL = sys.argv[1]
    port = int(sys.argv[2])

    with socketserver.TCPServer(("", port), S3ProxyHandler) as httpd:
        print(f"S3 proxy server running on port {port} for bucket {S3_BUCKET_URL}")
        httpd.serve_forever()
