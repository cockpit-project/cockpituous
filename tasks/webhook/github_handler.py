import os
import hmac
import logging
import json
import http.server

import distributed_queue

__all__ = (
    "GithubHandler",
    "aws_handler",
)

# 1 as basehttprequestHandler
# 1 as pure python function

def publish_to_queue(routing_key, event, request):
    body = {
        'event': event,
        'request': request,
    }
    with distributed_queue.DistributedQueue('amqp.cockpit.svc.cluster.local:5671') as queue:
        queue.basic_publish('', routing_key, json.dumps(body),
                            properties=pika.BasicProperties(content_type='application/json'))

class GithubHandler:
    def __init__(self, headers, body):
        self.headers = headers
        self.body = body

    def handle():
        if self.check_sig(self.headers, self.body):
            # TODO ERROR OUTputret
            return

        event = self.headers.get('X-GitHub-Event')
        request = request.decode('UTF-8')
        logging.debug('event: %s', event)
        request = json.loads(request)
        logging.debug('repository: %s', request['repository']['full_name'])

        self.handle_event(event, request) # what to return ?

    def check_sig(headers, request):
        '''Validate github signature of request.

        See https://developer.github.com/webhooks/securing/
        '''
            # load key
            # TODO where to store this?
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

    def handle_event(self, event, request):
        logging.info('Handling %s event', event)
        if event == 'create':
            return self.handle_create_event(event, request)
        elif event == 'pull_request':
            return self.handle_pull_request_event(event, request)
        elif event == 'status':
            return self.handle_status_event(event, request)
        elif event == 'issues':
            return self.handle_issues_event(event, request)
        return (501, 'unsupported event ' + event)

    def handle_ping_event(self, event, request):
        return # whatever

    def handle_pull_request_event(self, event, request):
        repo = request['pull_request']['base']['repo']['full_name']
        title = request['pull_request']['title']
        number = int(request['number'])
        action = request['action']
        merged = request['pull_request'].get('merged', False)

        logging.info('repo: %s; title: %s; number: %d; action: %s', repo, title, number, action)
        # see https://developer.github.com/v3/activity/events/types/#pullrequestevent for all actions
        if action not in ['opened', 'synchronize', 'edited', 'labeled']:
            logging.info("action %s unknown, skipping pull request event" % action)
            return None

        publish_to_queue('webhook', event, request)
        return None

    def handle_status_event(self, event, request):
        repo = request['repository']['full_name']
        sha = request['sha']
        state = request['state']
        description = request.get('description', '')
        if state != 'pending':
            return None
        # only allow manually triggered tests
        logging.info('repo: %s; sha: %s; state: %s; description: %s', repo, sha, state, description)
        if not description.rstrip().endswith('(direct trigger)'):
            logging.info("Status description doesn't end with '(direct trigger)', skipping testing")
            return None

        publish_to_queue('webhook', event, request)
        return None

    def handle_issues_event(self, event, request):
        action = request['action']
        if event == 'issues' and action not in ['opened', 'edited', 'labeled']:
            logging.info("action %s unknown, skipping issues event" % action)
            return None

        publish_to_queue('webhook', event, request)
        return None

    def handle_create_event(self, event, request):
        raise NotImplementedError("The basic GithubHandler doesn't handle create events")


# The ReleaseHandler requires an openshift environment
class ReleaseHandler(GithubHandler):
    def handle_create_event(self, event, request):
        ref_type = request.get('ref_type', '')
        if ref_type != 'tag':
            return (501, 'Ignoring ref_type %s, only doing releases on tags' % ref_type)

        try:
            tag = request['ref']
        except KeyError:
            return (400, 'Request is missing tag name in "ref" field')

        if self.path[0] != '/':
            return (400, 'Invalid path, should start with /: ' + self.path)

        # turn path into a relative one in the build dir
        return self.release(request['repository']['clone_url'], tag, '.' + self.path)

    @classmethod
    def release(klass, project, tag, script):
        logging.info('Releasing project %s, tag %s, script %s', project, tag, script)
        jobname = 'release-job-%s-%s' % (os.path.splitext(os.path.basename(project))[0], tag)

        # in case we want to restart a release, clean up the old job
        subprocess.call(['oc', 'delete', 'job', jobname])

        job = JOB % {'jobname': jobname, 'git_repo': project, 'tag': tag, 'script': script, 'sink': SINK}
        try:
            oc = subprocess.Popen(['oc', 'create', '-f', '-'], stdin=subprocess.PIPE)
            oc.communicate(job.encode('UTF-8'), timeout=60)
            if oc.wait(timeout=60) != 0:
                raise RuntimeError('creating release job failed with exit code %i' % oc.returncode)
        except (RuntimeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            logging.error(str(e))
            return (400, str(e))
        return None
