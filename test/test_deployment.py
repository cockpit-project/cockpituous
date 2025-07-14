import json
import os
import re
import shutil
import ssl
import subprocess
import textwrap
import time
import urllib.request
from pathlib import Path
from typing import Iterator

import pytest

# optional `pip install types-PyYAML`
import yaml  # type: ignore[import-untyped]

TASKS_IMAGE = os.environ.get('TASKS_IMAGE', 'ghcr.io/cockpit-project/tasks:latest')
ROOT_DIR = Path(__file__).parent.parent
PODMAN_SOCKET = Path(os.getenv('XDG_RUNTIME_DIR', '/run'), 'podman', 'podman.sock')
# AMQP address from inside the cockpituous pod
AMQP_POD = 'localhost:5671'
# S3 address from inside cockpituous pod
S3_URL_POD = 'https://localhost.localdomain:9000'
# S3 proxy URL for logs, used in mock_runner_proxy_config
S3_PROXY_URL = 'https://logs.example.com/'
# mock GitHub API running in tasks pod
GHAPI_URL_POD = 'http://127.0.0.7:8443'


#
# Deployment configuration and secrets (global, session scope)
#

class Config:
    rabbitmq: Path
    secrets: Path
    webhook: Path
    tasks: Path
    s3_keys: Path
    s3_server: Path


@pytest.fixture(scope='session')
def config(tmp_path_factory) -> Config:
    configdir = tmp_path_factory.mktemp('config')
    config = Config()

    # generate flat files from RabbitMQ config map; keep in sync with ansible/roles/webhook/tasks/main.yml
    config.rabbitmq = configdir / 'rabbitmq-config'
    config.rabbitmq.mkdir(parents=True)

    for doc in yaml.full_load_all((ROOT_DIR / 'tasks/cockpit-tasks-webhook.yaml').read_text()):
        if doc['metadata']['name'] == 'amqp-config':
            files = doc['data']
            for name, contents in files.items():
                (config.rabbitmq / name).write_text(contents)
            break
    else:
        raise ValueError('amqp-config not found in the webhook task')

    config.secrets = configdir / 'secrets'

    # webhook secrets
    os.makedirs(config.secrets)
    subprocess.run(ROOT_DIR / 'tasks/credentials/generate-ca.sh', cwd=config.secrets, check=True)
    config.webhook = config.secrets / 'webhook'
    config.webhook.mkdir()
    subprocess.run(ROOT_DIR / 'tasks/credentials/webhook/generate.sh', cwd=config.webhook, check=True)

    # default to dummy token, tests need to opt into real one with user_github_token
    (config.webhook / '.config--github-token').write_text('0123abc')

    # minio S3 certificate
    config.s3_server = config.secrets / 's3-server'
    config.s3_server.mkdir()
    subprocess.run(ROOT_DIR / 'local-s3/generate-s3-cert.sh', cwd=config.s3_server, check=True)

    # minio S3 key
    config.s3_keys = config.secrets / 's3-keys'
    config.s3_keys.mkdir()
    (config.s3_keys / 'localhost.localdomain').write_text('cockpituous foobarfoo')

    # tasks secrets: none right now, but do create an empty directory to keep production structure
    config.tasks = config.secrets / 'tasks'
    config.tasks.mkdir()

    # need to make secrets world-readable, as containers run as non-root
    subprocess.run(['chmod', '-R', 'go+rX', configdir], check=True)

    # start podman API
    user_opt = [] if os.geteuid() == 0 else ['--user']
    subprocess.run(['systemctl', *user_opt, 'start', 'podman.socket'], check=True)
    # make podman socket accessible to the container user
    # the socket's directory is only accessible for the user, so 666 permissions don't hurt
    PODMAN_SOCKET.chmod(0o666)

    return config


@pytest.fixture()
def user_github_token(config: Config, request) -> None:
    if request.config.getoption('github_token'):
        shutil.copy(request.config.getoption('--github-token'), config.webhook / '.config--github-token')
    return None  # silence ruff PT004


#
# Container deployment
#

class PodData:
    pod: str
    # container names
    rabbitmq: str
    s3: str
    mc: str
    tasks: str
    webhook: str | None  # only in "shell" marker
    # forwarded ports
    host_port_s3: int


@pytest.fixture(scope='session')
def pod(config: Config, pytestconfig) -> Iterator[PodData]:
    """Deployment pod definition"""

    launch_args = ['--stop-timeout=0', '--security-opt=label=disable']

    # we want to have useful pod/container names for interactive debugging and log dumping, but still allow
    # parallel tests (with e.g. xdist), so disambiguate them with the pid
    test_instance = str(os.getpid())
    data = PodData()
    data.pod = f'cockpituous-{test_instance}'

    # RabbitMQ, also defines/starts pod
    data.rabbitmq = f'cockpituous-rabbitmq-{test_instance}'
    subprocess.run(['podman', 'run', '-d', '--name', data.rabbitmq, f'--pod=new:{data.pod}', *launch_args,
                    # you can set 9000:9000 to make S3 log URLs work; but it breaks parallel tests
                    '--publish', '9000',
                    '-v', f'{config.rabbitmq}:/etc/rabbitmq:ro',
                    '-v', f'{config.webhook}:/run/secrets/webhook:ro',
                    'docker.io/rabbitmq'],
                   check=True)

    # minio S3 store
    data.s3 = f'cockpituous-s3-{test_instance}'
    subprocess.run(['podman', 'run', '-d', '--name', data.s3, f'--pod={data.pod}', *launch_args,
                    '-v', f'{config.s3_server}/s3-server.key:/root/.minio/certs/private.key:ro',
                    '-v', f'{config.s3_server}/s3-server.pem:/root/.minio/certs/public.crt:ro',
                    '-e', 'MINIO_ROOT_USER=minioadmin',
                    '-e', 'MINIO_ROOT_PASSWORD=minioadmin',
                    'quay.io/minio/minio', 'server', '/data', '--console-address', ':9001'],
                   check=True)

    proc = subprocess.run(['podman', 'port', data.s3, '9000'], capture_output=True, text=True, check=True)
    # looks like "0.0.0.0:12345"
    data.host_port_s3 = int(proc.stdout.strip().split(':')[-1])

    # minio S3 console
    data.mc = f'cockpituous-mc-{test_instance}'
    subprocess.run(['podman', 'run', '-d', '--interactive', '--name', data.mc, f'--pod={data.pod}', *launch_args,
                    '--entrypoint', '/bin/sh',
                    '-v', f'{config.secrets}/ca.pem:/etc/pki/ca-trust/source/anchors/ca.pem:ro',
                    'quay.io/minio/mc'],
                   check=True)

    # wait until S3 started, create bucket
    (s3user, s3key) = (config.s3_keys / 'localhost.localdomain').read_text().strip().split()
    exec_c(data.mc, f'''
set -e
cat /etc/pki/ca-trust/source/anchors/ca.pem >> /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
until mc alias set minio '{S3_URL_POD}' minioadmin minioadmin; do sleep 1; done
mc mb minio/images
mc mb minio/logs
mc anonymous set download minio/images
mc anonymous set download minio/logs
mc admin user add minio/ {s3user} {s3key}
mc admin policy attach minio/ readwrite --user {s3user}
''', timeout=30)

    # tasks
    data.tasks = f'cockpituous-tasks-{test_instance}'
    subprocess.run(['podman', 'run', '-d', '--interactive', '--name', data.tasks, f'--pod={data.pod}', *launch_args,
                    '-v', f'{PODMAN_SOCKET}:/podman.sock',
                    '-v', f'{config.webhook}:/run/secrets/webhook:ro',
                    '-v', f'{config.tasks}:/run/secrets/tasks:ro',
                    '-v', f'{config.s3_keys}:/run/secrets/s3-keys:ro',
                    '-e', 'COCKPIT_GITHUB_TOKEN_FILE=/run/secrets/webhook/.config--github-token',
                    '-e', 'COCKPIT_CA_PEM=/run/secrets/webhook/ca.pem',
                    '-e', f'COCKPIT_BOTS_REPO={os.getenv("COCKPIT_BOTS_REPO", "")}',
                    '-e', f'COCKPIT_BOTS_BRANCH={os.getenv("COCKPIT_BOTS_BRANCH", "")}',
                    '-e', 'COCKPIT_TESTMAP_INJECT=main/unit-tests',
                    '-e', 'JOB_RUNNER_CONFIG=/run/secrets/tasks/job-runner.toml',
                    '-e', f'AMQP_SERVER={AMQP_POD}',
                    '-e', f'S3_LOGS_URL={S3_URL_POD}/logs/',
                    '-e', 'COCKPIT_S3_KEY_DIR=/run/secrets/s3-keys',
                    '-e', f'COCKPIT_IMAGE_UPLOAD_STORE={S3_URL_POD}/images/',
                    '-e', 'COCKPIT_IMAGES_DATA_DIR=/cache/images',
                    '-e', 'GIT_COMMITTER_NAME=Cockpituous',
                    '-e', 'GIT_COMMITTER_EMAIL=cockpituous@cockpit-project.org',
                    '-e', 'GIT_AUTHOR_NAME=Cockpituous',
                    '-e', 'GIT_AUTHOR_EMAIL=cockpituous@cockpit-project.org',
                    '-e', 'SLUMBER=1',
                    TASKS_IMAGE],
                   check=True)

    # check out the correct bots, as part of what cockpit-tasks would usually do
    exec_c(data.tasks,
           f'git clone --quiet --depth=1 -b {os.getenv("COCKPIT_BOTS_BRANCH", "main")}'
           f'  {os.getenv("COCKPIT_BOTS_REPO", "https://github.com/cockpit-project/bots")} bots')

    # install our mock git-push
    subprocess.run(['podman', 'cp', str(ROOT_DIR / 'tasks/mock-git-push'), f'{data.tasks}:/usr/local/bin/git'],
                   check=True)

    # scanning/queueing actual cockpit PRs interferes with automatic tests; but do this in
    # shell mode to have a complete deployment
    if 'not shell' not in pytestconfig.option.markexpr:
        data.webhook = f'cockpituous-webhook-{test_instance}'
        subprocess.run(['podman', 'run', '-d', '--name', data.webhook, f'--pod={data.pod}', *launch_args,
                        '-v', f'{config.webhook}:/run/secrets/webhook:ro',
                        '-e', f'AMQP_SERVER={AMQP_POD}',
                        '-e', 'COCKPIT_GITHUB_TOKEN_FILE=/run/secrets/webhook/.config--github-token',
                        '-e', 'COCKPIT_GITHUB_WEBHOOK_TOKEN_FILE=/run/secrets/webhook/.config--github-webhook-token',
                        TASKS_IMAGE, 'webhook'],
                       check=True)

    # wait until RabbitMQ initialized
    exec_c(data.tasks, f'until bots/inspect-queue --amqp {AMQP_POD}; do sleep 1; done', timeout=30)

    yield data

    subprocess.run(['podman', 'pod', 'rm', '-f', data.pod], check=True)


@pytest.fixture()
def clean_s3(pod: PodData) -> None:
    """Remove all S3 objects in the logs and images buckets

    This is used to clean up after tests that leave S3 objects behind.
    """
    exec_c(pod.mc, 'mc rm --recursive --force minio/logs')
    exec_c(pod.mc, 'mc rm --recursive --force minio/images')


#
# Utilities
#

def exec_c(container: str, command: str, timeout=None, *, capture: bool = False,
           exec_opts: list[str] | None = None) -> str | None:
    """Run shell command in a container

    Assert that it succeeds.
    Return stdout if capture is True. stderr is not captured.

    Default timeout is 5s.
    """
    res = subprocess.run(
        ['podman', 'exec', '-i', *(exec_opts or []), container, 'sh', '-ec', command],
        check=True,
        stdout=subprocess.PIPE if capture else None,
        timeout=5 if timeout is None else timeout)

    return res.stdout.decode() if capture else None


def exec_c_out(container: str, command: str, timeout=None) -> str:
    """Run shell command in a container

    Assert that it succeeds.
    Return stdout. stderr is not captured.

    Default timeout is 5s.
    """
    out = exec_c(container, command, timeout, capture=True)
    assert out is not None  # mypy
    return out


def get_s3(config: Config, pod: PodData, path: str) -> str:
    """Return the content of an S3 object"""

    s3_base = f'https://localhost.localdomain:{pod.host_port_s3}'

    context = ssl.create_default_context(cafile=config.secrets / 'ca.pem')
    with urllib.request.urlopen(f'{s3_base}/{path}', context=context) as f:
        return f.read().decode()


#
# Per test fixtures
#

@pytest.fixture()
def bots_sha(pod: PodData) -> str:
    """Return the SHA of the bots checkout"""

    return exec_c_out(pod.tasks, 'git -C bots rev-parse HEAD').strip()


@pytest.fixture()
def mock_github(pod: PodData, bots_sha: str) -> Iterator[str]:
    """Start mock GitHub API server

    Return environment shell command for using it
    """
    subprocess.run(['podman', 'cp', str(ROOT_DIR / 'tasks/mock-github'), f'{pod.tasks}:/work/bots/mock-github'],
                   check=True)

    mock_github = subprocess.Popen(
        ['podman', 'exec', '-i',  '--env=PYTHONPATH=bots', pod.tasks,
         'bots/mock-github', '--log', '/tmp/mock.log', 'cockpit-project/bots', bots_sha])
    # wait until it started
    exec_c_out(pod.tasks, f'curl --retry 5 --retry-connrefused --fail {GHAPI_URL_POD}/repos/cockpit-project/bots')

    yield f'export GITHUB_API={GHAPI_URL_POD}; SHA={bots_sha}'

    exec_c_out(pod.tasks, 'pkill -f mock-github')
    mock_github.wait()


def generate_config(config: Config, forge_opts: str, s3_opts: str, run_args: str) -> Path:
    conf = textwrap.dedent(f'''\
        [logs]
        driver='s3'

        [forge.github]
        token = [{{file="/run/secrets/webhook/.config--github-token"}}]
        {forge_opts}

        [logs.s3]
        url = '{S3_URL_POD}/logs'
        ca = [{{file='/run/secrets/webhook/ca.pem'}}]
        key = [{{file="/run/secrets/s3-keys/localhost.localdomain"}}]
        {s3_opts}

        [container]
        command = ['podman-remote', '--url=unix:///podman.sock']
        run-args = [
            '--security-opt=label=disable',
            '--volume={ROOT_DIR / 'tasks'}/mock-git-push:/usr/local/bin/git:ro',
            '--env=COCKPIT_IMAGE_UPLOAD_STORE={S3_URL_POD}/images/',
            '--env=GIT_AUTHOR_*',
            '--env=GIT_COMMITTER_*',
            {run_args}
        ]

        [container.secrets]
        # these are *host* paths, this is podman-remote
        image-upload=[
            '--volume={config.s3_keys}:/run/secrets/s3-keys:ro',
            '--env=COCKPIT_S3_KEY_DIR=/run/secrets/s3-keys',
            '--volume={config.webhook}/ca.pem:/run/secrets/ca.pem:ro',
            '--env=COCKPIT_CA_PEM=/run/secrets/ca.pem',
        ]
        github-token=[
            '--volume={config.webhook}/.config--github-token:/run/secrets/github-token:ro',
            '--env=COCKPIT_GITHUB_TOKEN_FILE=/run/secrets/github-token',
        ]
        ''')

    job_conf = config.tasks / 'job-runner.toml'
    job_conf.write_text(conf)
    return job_conf


@pytest.fixture()
def mock_runner_config(config: Config, pod: PodData) -> Path:
    return generate_config(config,
                           forge_opts=f'api-url = "{GHAPI_URL_POD}"',
                           s3_opts='',
                           run_args=f'"--pod={pod.pod}", "--env=GITHUB_API={GHAPI_URL_POD}"')


@pytest.fixture()
def mock_runner_proxy_config(config: Config, pod: PodData) -> Path:
    return generate_config(config,
                           forge_opts=f'api-url = "{GHAPI_URL_POD}"',
                           s3_opts=f'proxy_url = "{S3_PROXY_URL}"\nacl = "authenticated-read"',
                           run_args=f'"--pod={pod.pod}", "--env=GITHUB_API={GHAPI_URL_POD}"')


@pytest.fixture()
def real_runner_config(config: Config) -> Path:
    return generate_config(config, forge_opts='', s3_opts='', run_args='')


#
# Integration tests
#

def test_podman(pod: PodData) -> None:
    """tasks can connect to host's podman service

    This is covered implicitly by job-runner, but as a more basal plumbing test
    this is easier to debug.
    """
    assert 'cockpituous-tasks' in exec_c_out(pod.tasks, 'podman-remote --url unix:///podman.sock ps')
    out = exec_c_out(pod.tasks, f'podman-remote --url unix:///podman.sock run -i --rm {TASKS_IMAGE} whoami')
    assert out.strip() == 'user'


def test_images(pod: PodData) -> None:
    """test image upload/download/prune"""

    exec_c(pod.tasks, f'''
        cd bots

        # fake an image
        echo world  > /cache/images/testimage
        NAME="testimage-$(sha256sum /cache/images/testimage | cut -f1 -d' ').qcow2"
        mv /cache/images/testimage /cache/images/$NAME
        ln -s $NAME images/testimage

        # test image-upload to S3
        ./image-upload --store {S3_URL_POD}/images/ testimage
        ''')
    # S3 store received this
    out = exec_c_out(pod.tasks, f'cd bots; python3 -m lib.s3 ls {S3_URL_POD}/images/')
    assert re.search(r'testimage-[0-9a-f]+\.qcow2', out)

    # image downloading from S3
    exec_c(pod.tasks, f'''
        rm --verbose /cache/images/testimage*
        cd bots
        ./image-download --store {S3_URL_POD}/images/ testimage
        grep -q "^world" /cache/images/testimage-*.qcow2
        rm --verbose /cache/images/testimage*
        ''')

    # image pruning on s3
    exec_c(pod.tasks, f'''
      cd bots
      rm images/testimage
      ./image-prune --s3 {S3_URL_POD}/images/ --force --checkout-only
      ''')
    # S3 store removed it
    assert 'testimage' not in exec_c_out(pod.tasks, f'cd bots; python3 -m lib.s3 ls {S3_URL_POD}/images/')


def test_queue(pod: PodData) -> None:
    """tasks can connect to AMQP"""

    out = exec_c_out(pod.tasks, f'bots/inspect-queue --amqp {AMQP_POD}')
    # this depends on whether the test runs first or not
    assert 'queue public does not exist' in out or 'queue public is empty' in out


def make_pr_event_commands(env: str) -> str:
    """Create tasks container commands to simulate and process a PR event"""
    return f'''set -ex
      {env}

      cd bots

      # simulate GitHub webhook event, put that into the webhook queue
      PYTHONPATH=. ./mock-github --print-pr-event cockpit-project/bots $SHA | \
          ./publish-queue --amqp {AMQP_POD} --create --queue webhook

      ./inspect-queue --amqp {AMQP_POD}

      # first run-queue processes webhook → tests-scan → public queue
      ./run-queue --amqp {AMQP_POD}
      ./inspect-queue --amqp {AMQP_POD}

      # second run-queue actually runs the test
      ./run-queue --amqp {AMQP_POD}
      '''


def test_mock_pr(config: Config,
                 pod: PodData,
                 clean_s3,
                 bots_sha: str,
                 mock_github,
                 mock_runner_config) -> None:
    """almost end-to-end PR test

    Starting with GitHub webhook JSON payload injection; fully local, no privileges needed.
    """
    exec_c(pod.tasks, make_pr_event_commands(mock_github), timeout=360)

    # check log in S3
    # looks like <Key>pull-1-a4d25bb9-20240315-135902-unit-tests/log</Key>
    m = re.search(r'pull-1-[a-z0-9-]*-unit-tests/log(?=<)', get_s3(config, pod, 'logs/'))
    assert m
    slug = m.group(0)
    log = get_s3(config, pod, f'logs/{slug}')
    assert 'Job ran successfully' in log
    assert re.search(r'Running on:\s+cockpituous', log)

    # 3 status updates posted
    gh_mock_log = exec_c_out(pod.tasks, 'cat /tmp/mock.log')
    jsons = re.findall(f'POST /repos/cockpit-project/bots/statuses/{bots_sha} (.*)$', gh_mock_log, re.M)
    assert len(jsons) == 3
    assert json.loads(jsons[0]) == {"state": "pending", "description": "Not yet tested", "context": "unit-tests"}
    assert json.loads(jsons[1]) == {
        "state": "pending",
        "description": f"In progress [{pod.pod}]",
        "context": "unit-tests",
        "target_url": f"https://localhost.localdomain:9000/logs/{slug}.html"
    }
    assert json.loads(jsons[2]) == {
        "state": "success",
        "description": f"Success [{pod.pod}]",
        "context": "unit-tests",
        "target_url": f"https://localhost.localdomain:9000/logs/{slug}.html"
    }


def test_mock_pr_url_proxy(config: Config,
                           pod: PodData,
                           clean_s3,
                           bots_sha: str,
                           mock_github,
                           mock_runner_proxy_config) -> None:
    """end to end test with proxy_url configuration"""

    exec_c(pod.tasks, make_pr_event_commands(mock_github), timeout=360)

    # check log in S3
    # looks like <Key>pull-1-a4d25bb9-20240315-135902-unit-tests/log</Key>
    m = re.search(r'pull-1-[a-z0-9-]*-unit-tests/log(?=<)', get_s3(config, pod, 'logs/'))
    assert m
    slug = m.group(0)
    log = get_s3(config, pod, f'logs/{slug}')
    assert 'Job ran successfully' in log
    assert re.search(r'Running on:\s+cockpituous', log)

    # 3 status updates posted, with proxy target URLs
    gh_mock_log = exec_c_out(pod.tasks, 'cat /tmp/mock.log')
    jsons = re.findall(f'POST /repos/cockpit-project/bots/statuses/{bots_sha} (.*)$', gh_mock_log, re.M)
    assert len(jsons) == 3
    assert json.loads(jsons[0]) == {"state": "pending", "description": "Not yet tested", "context": "unit-tests"}
    assert json.loads(jsons[1]) == {
        "state": "pending",
        "description": f"In progress [{pod.pod}]",
        "context": "unit-tests",
        "target_url": f"{S3_PROXY_URL}{slug}.html"
    }
    assert json.loads(jsons[2]) == {
        "state": "success",
        "description": f"Success [{pod.pod}]",
        "context": "unit-tests",
        "target_url": f"{S3_PROXY_URL}{slug}.html"
    }


def test_mock_cross_project_pr(config: Config,
                               pod: PodData,
                               clean_s3,
                               bots_sha: str,
                               mock_github,
                               mock_runner_config) -> None:
    """almost end-to-end PR cross-project test

    Starting with GitHub webhook JSON payload injection; fully local, no privileges needed.
    """
    cross_env = 'export COCKPIT_TESTMAP_INJECT=main/unit-tests@cockpit-project/cockpituous'
    exec_c(pod.tasks, make_pr_event_commands(mock_github + '\n' + cross_env), timeout=360)

    # check log in S3
    # looks like <Key>pull-1-a4d25bb9-20240315-135902-unit-tests.../log</Key>
    m = re.search(r'pull-1-[a-z0-9-]*-unit-tests-cockpit-project-cockpituous(?=/)', get_s3(config, pod, 'logs/'))
    assert m
    slug = m.group(0)
    log = get_s3(config, pod, f'logs/{slug}/log')
    assert 'Job ran successfully' in log
    assert re.search(r'Running on:\s+cockpituous', log)

    # validate test attachment
    assert 'heisenberg compensator' in get_s3(config, pod, f'logs/{slug}/bogus.log')

    # 3 status updates posted to bots project (the PR we are testing)
    gh_mock_log = exec_c_out(pod.tasks, 'cat /tmp/mock.log')
    context = "unit-tests@cockpit-project/cockpituous"
    jsons = re.findall(f'POST /repos/cockpit-project/bots/statuses/{bots_sha} (.*)$', gh_mock_log, re.M)
    assert len(jsons) == 3
    assert json.loads(jsons[0]) == {"state": "pending", "description": "Not yet tested", "context": context}
    assert json.loads(jsons[1]) == {
        "state": "pending",
        "description": f"In progress [{pod.pod}]",
        "context": context,
        "target_url": f"https://localhost.localdomain:9000/logs/{slug}/log.html"
    }
    assert json.loads(jsons[2]) == {
        "state": "success",
        "description": f"Success [{pod.pod}]",
        "context": context,
        "target_url": f"https://localhost.localdomain:9000/logs/{slug}/log.html"
    }


def test_mock_image_refresh(config: Config, pod: PodData, bots_sha: str,
                            mock_github, mock_runner_config) -> None:
    """almost end-to-end PR image refresh

    Starting with GitHub webhook JSON payload injection; fully local, no privileges needed.
    """
    exec_c(pod.tasks, f'''set -ex
      {mock_github}
      cd bots

      # simulate GitHub webhook event, put that into the webhook queue
      PYTHONPATH=. ./mock-github --print-image-refresh-event cockpit-project/bots $SHA | \
          ./publish-queue --amqp {AMQP_POD} --create --queue webhook

      ./inspect-queue --amqp {AMQP_POD}

      # first run-queue processes webhook → issue-scan → public queue
      ./run-queue --amqp {AMQP_POD}
      ./inspect-queue --amqp {AMQP_POD}

      # second run-queue actually runs the image refresh
      ./run-queue --amqp {AMQP_POD}
      ''', timeout=360)

    # check log in S3
    m = re.search(r'image-refresh-foonux-[a-z0-9-]*(?=/)', get_s3(config, pod, 'logs/'))
    assert m
    slug = m.group(0)
    log = get_s3(config, pod, f'logs/{slug}/log')
    assert re.search(r'Running on:\s+cockpituous', log)
    assert './image-refresh --verbose --issue=2 foonux\n' in log
    assert f'Uploading to {S3_URL_POD}/images/foonux' in log
    assert 'Success.' in log

    # branch was (mock) pushed
    push_log = get_s3(config, pod, f'logs/{slug}/git-push.log')
    assert 'push origin +HEAD:refs/heads/image-refresh-foonux-' in push_log

    exec_c(pod.tasks, f'''set -ex
        cd bots
        # image is on the S3 server
        name=$(python3 -m lib.s3 ls {S3_URL_POD}/images/ | grep -o "foonux.*qcow2")

        # download image (it was not pushed to git, so need to use --state)
        rm -f /cache/images/foonux*
        ./image-download --store $COCKPIT_IMAGE_UPLOAD_STORE --state "$name"

        # validate image contents
        qemu-img convert /cache/images/foonux-*.qcow2 /tmp/foonux.raw
        grep "^fakeimage" /tmp/foonux.raw
        rm /tmp/foonux.raw
        ''')

    # status updates posted to original bots SHA on which the image got triggered
    gh_mock_log = exec_c_out(pod.tasks, 'cat /tmp/mock.log')
    jsons = re.findall(f'POST /repos/cockpit-project/bots/statuses/{bots_sha} (.*)$', gh_mock_log, re.M)
    assert len(jsons) == 2
    assert json.loads(jsons[0]) == {
        "context": "image-refresh/foonux",
        "state": "pending",
        "description": f"In progress [{pod.pod}]",
        "target_url": f"https://localhost.localdomain:9000/logs/{slug}/log.html",
    }
    assert json.loads(jsons[1]) == {
        "context": "image-refresh/foonux",
        "state": "success",
        "description": f"Success [{pod.pod}]",
        "target_url": f"https://localhost.localdomain:9000/logs/{slug}/log.html",
    }

    # and forwarded to the converted PR (new SHA)
    assert re.search(r"POST /repos/cockpit-project/bots/statuses/a1b2c3 .*success.*Forwarded status.*target_url",
                     gh_mock_log)

    # posted new comment with log
    assert re.search(r"POST /repos/cockpit-project/bots/issues/2/comments .*Success. Log: https.*", gh_mock_log)


def test_real_pr(config: Config, request, pod: PodData, bots_sha: str, real_runner_config,
                 user_github_token) -> None:
    """full end-to-end PR test

    Requires --pr and --github-token.
    """
    pr = request.config.getoption('--pr', skip=True)
    pr_repo = request.config.getoption('--pr-repository')

    # run the main loop in the background; we could do this with a single run-queue invocation,
    # but we want to test the cockpit-tasks script
    tasks_pid = exec_c_out(
        pod.tasks, '(nohup cockpit-tasks </dev/null >/tmp/cockpit-tasks.log 2>&1 & echo $!)'
    ).strip()

    # wait until test status appears
    exec_c(pod.tasks, f'''set -ex
      cd bots
      ./tests-scan -p {pr} --amqp {AMQP_POD} --repo {pr_repo}
      for retry in $(seq 10); do
          OUT=$(./tests-scan --repo {pr_repo} -p {pr} --human-readable --dry)
          [ "${{OUT%unit-tests*}}" = "$OUT" ] || break
          echo waiting until the status is visible
          sleep 10
      done''', timeout=360)

    # wait until the unit-test got run and published, i.e. until the non-chunked raw log file exists
    for _retry in range(60):
        logs_dir = get_s3(config, pod, 'logs/')
        m = re.search(f'pull-{pr}-[a-z0-9-]*-unit-tests/log(?=<)', logs_dir)
        if m:
            log_name = m.group(0)
            break
        print('waiting for unit-tests run to finish...')
        time.sleep(10)
    else:
        raise SystemError('unit-tests run did not finish')

    # tell the tasks container iteration that we are done, and wait for it to finish
    exec_c(pod.tasks,
           f'set -ex; kill {tasks_pid}; while kill -0 {tasks_pid} 2>/dev/null; do sleep 1; done',
           timeout=360)

    # spot-check the log
    log = get_s3(config, pod, f'logs/{log_name}')
    print(f'----- PR unit-tests log -----\n{log}\n-----------------')
    assert re.search(r'Running on:\s+cockpituous', log)
    assert 'Job ran successfully' in log
    assert '<html>' in get_s3(config, pod, f'logs/{log_name}.html')

    # validate test attachment if we ran cockpituous' own tests
    if pr_repo.endswith('/cockpituous'):
        print(f'----- S3 logs/ dir -----\n{logs_dir}\n-----------------')
        slug = os.path.dirname(log_name)  # strip off '/log'
        assert 'heisenberg compensator' in get_s3(config, pod, f'logs/{slug}/bogus.log')
        assert 'subdir-file' in get_s3(config, pod, f'logs/{slug}/data/subdir-file.txt')


#
# Interactive scenarios
#

@pytest.mark.shell()
def test_shell(pod: PodData, user_github_token) -> None:
    """interactive shell for development; run with `pytest -sm shell`"""

    subprocess.run(["podman", "exec", "-it", pod.tasks, "bash"])
