import os
import hmac
import logging
import json
import http.server

__all__ = (
    "GithubHandler",
)

class GithubHandler(http.server.BaseHTTPRequestHandler):
    def check_sig(self, request):
        '''Validate github signature of request.

        See https://developer.github.com/webhooks/securing/
        '''
        # load key
        keyfile = os.path.expanduser('~/.config/github-webhook-token')
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

        request = request.decode('UTF-8')
        logging.debug('event: %s, path: %s', event, self.path)

        request = json.loads(request)
        logging.debug('repository: %s', request['repository']['full_name'])

        try:
            request['repository']['clone_url']
        except KeyError:
            self.fail('Request misses repository clone_url')
            return

        if event == 'ping':
            self.success()
            return
        err = self.handle_event(event, request)
        if err:
            self.fail(err[1], code=err[0])
        else:
            self.success()

    def handle_event(self, event, request):
        '''Handle GitHub event type "event"

        "ping" is already handled internally.

        Returns: None for success, or a (code, message) tuple on errors.
        '''
        raise NotImplementedError('must be implemented in subclasses')
