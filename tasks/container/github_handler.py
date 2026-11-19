import os
import hmac
import logging
import json
import http.server

__all__ = (
    "GithubHandler",
    "WebhookError",
)


class WebhookError(Exception):
    def __init__(self, code: int, message: str) -> None:
        self.code = code
        self.message = message


class GithubHandler(http.server.BaseHTTPRequestHandler):
    def check_sig(self, request):
        '''Validate github signature of request.

        See https://developer.github.com/webhooks/securing/
        '''
        # load key
        keyfile = os.getenv("COCKPIT_GITHUB_WEBHOOK_TOKEN_FILE", os.path.expanduser('~/.config/github-webhook-token'))
        try:
            with open(keyfile, 'rb') as f:
                key = f.read().strip()
        except IOError as e:
            logging.error('Failed to load GitHub key: %s', e)
            return False

        sig_sha1 = self.headers.get('X-Hub-Signature', '')
        payload_sha1 = 'sha1=' + hmac.new(key, request, 'sha1').hexdigest()
        if hmac.compare_digest(sig_sha1, payload_sha1):
            return True
        logging.error('GitHub signature mismatch! received: %s calculated: %s',
                      sig_sha1, payload_sha1)
        return False

    def fail(self, reason, code=404):
        logging.error(reason)
        self.send_response(code)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(reason.encode())
        self.wfile.write(b'\n')

    def success(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'OK\n')

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        request = self.rfile.read(content_length)

        if not self.check_sig(request):
            self.send_response(403)
            self.end_headers()
            return

        event = self.headers.get('X-GitHub-Event')
        logging.debug('event: %r, path: %r', event, self.path)

        try:
            self.handle_event(event, json.loads(request.decode('UTF-8')))
            self.success()
        except WebhookError as e:
            self.fail(e.message, code=e.code)

    def handle_event(self, event, request):
        """Handle GitHub event type "event".

        Raise WebhookError on failure.
        """
        raise NotImplementedError('must be implemented in subclasses')
