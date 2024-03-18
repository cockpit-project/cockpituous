import os
import subprocess
import sys


def pytest_addoption(parser):
    parser.addoption('--github-token', metavar='PATH',
                     help='path to real GitHub token, for testing real PR or shell mode')
    parser.addoption('--pr', metavar='NUMBER', type=int,
                     help='run unit tests in the local deployment against a real PR')
    parser.addoption('--pr-repository', metavar='OWNER/REPO', default='cockpit-project/cockpituous',
                     help='run --pr against owner/repo other than %(default)s')


def pytest_exception_interact(node, call, report):
    if report.failed:
        if os.isatty(0):
            print('Test failure; investigate, and press Enter to shut down')
            input()
        else:
            print('\n\n---------- cockpit-tasks log ------------')
            sys.stdout.flush()
            subprocess.run(['podman', 'exec', '-i', f'cockpituous-tasks-{os.getpid()}',
                            'cat', '/tmp/cockpit-tasks.log'])
            print('-----------------------------------------')
            sys.stdout.flush()
