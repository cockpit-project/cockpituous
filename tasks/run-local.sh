#!/bin/sh
# Run a local pod with a AMQP and a tasks container
# You can run against a tasks container tag different than latest by setting "$TASKS_TAG"
set -eu

MYDIR=$(realpath $(dirname $0))
ROOTDIR=$(dirname $MYDIR)
DATADIR=$ROOTDIR/local-data
RABBITMQ_CONFIG=$DATADIR/rabbitmq-config
SECRETS=$DATADIR/secrets
IMAGE_PORT=${IMAGE_PORT:-8080}
S3_PORT=${S3_PORT:-9000}
# S3 address from inside cockpituous pod
S3_URL_POD=https://localhost.localdomain:9000
# S3 address from host
S3_URL_HOST=https://localhost.localdomain:$S3_PORT
# AMQP address from inside the cockpituous pod
AMQP_POD=localhost:5671
# mock GitHub API running in tasks pod
GHAPI_URL_POD="http://127.0.0.7:8443"

# CLI option defaults/values
PR=
PR_REPO=cockpit-project/cockpituous
TOKEN=
INTERACTIVE=

assert_in() {
    if ! echo "$2" | grep -q "$1"; then
        echo "ERROR: did not find '$1' in '$2'" >&2
        exit 1
    fi
}

parse_options() {
    while getopts "his:t:p:r:" opt "$@"; do
        case $opt in
            h)
                echo '-p run unit tests in the local deployment against a real PR'
                echo "-r run unit tests in the local deployment against an owner/repo other than $PR_REPO"
                echo '-t supply a token which will be copied into the webhook secrets'
                echo "-i interactive mode: disable cockpit-tasks script, no automatic shutdown"
                exit 0
                ;;
            p) PR="$OPTARG" ;;
            r) PR_REPO="$OPTARG" ;;
            i) INTERACTIVE="1" ;;
            t)
                if [ ! -e "$OPTARG" ]; then
                    echo $OPTARG does not exist
                    exit 1
                fi
                TOKEN="$OPTARG"
                ;;
            esac
    done
}

# initialize DATADIR and config files
setup_config() {
    # clean up data dir from previous round
    rm -rf "$DATADIR"

    # generate flat files from RabbitMQ config map
    mkdir -p $RABBITMQ_CONFIG
    python3 - <<EOF
import os.path
import yaml

with open("$MYDIR/cockpit-tasks-webhook.yaml") as f:
    for doc in yaml.full_load_all(f):
        if doc["metadata"]["name"] == "amqp-config":
            break
files = doc["data"]
for name, contents in files.items():
    with open(os.path.join('$RABBITMQ_CONFIG', name), 'w') as f:
        f.write(contents)
EOF
    # need to make files world-readable, as rabbitmq container runs as different user
    chmod -R go+rX "$RABBITMQ_CONFIG"

    # generate secrets, unless they are already present in the source tree
    if [ -e "$MYDIR/credentials/webhook/amqp-client.key" ]; then
        SECRETS="$MYDIR/credentials"
    else
        (mkdir -p "$SECRETS"
        cd "$SECRETS"
        $MYDIR/credentials/generate-ca.sh
        (mkdir -p webhook; cd webhook; $MYDIR/credentials/webhook/generate.sh)
        (mkdir -p tasks; cd tasks; $ROOTDIR/local-s3/generate-s3-cert.sh)

        # default to dummy token, tests need to opt into real one
        echo 0123abc > webhook/.config--github-token

        # minio S3 key
        mkdir tasks/s3-keys
        echo 'cockpituous foobarfoo' > tasks/s3-keys/localhost.localdomain
        )

        # start podman API
        systemctl $([ $(id -u) -eq 0 ] || echo "--user") start podman.socket

        # need to make files world-readable, as containers run as different user 1111
        chmod -R go+rX "$SECRETS"
        # for the same reason, make podman socket accessible to that container user
        # the directory is only accessible for the user, so 666 permissions don't hurt
        chmod o+rw ${XDG_RUNTIME_DIR:-/run}/podman/podman.sock
    fi
}

launch_containers() {
    cleanup() {
        if [ $? -ne 0 ] && [ -z "$INTERACTIVE" ] && [ -t 0 ]; then
            echo "Test failure; investigate, and press Enter to shut down"
            read
        fi
        podman pod rm -f cockpituous
    }

    trap cleanup EXIT INT QUIT PIPE

    # start podman and run RabbitMQ in the background
    podman run -d --name cockpituous-rabbitmq --pod=new:cockpituous \
        --security-opt=label=disable \
        --publish $IMAGE_PORT:8080 \
        --publish $S3_PORT:9000 \
        --publish 9001:9001 \
        -v "$RABBITMQ_CONFIG":/etc/rabbitmq:ro \
        -v "$SECRETS"/webhook:/run/secrets/webhook:ro \
        docker.io/rabbitmq

    # S3
    local admin_password="$(dd if=/dev/urandom bs=10 count=1 status=none | base64)"
    podman run -d --name cockpituous-s3 --pod=cockpituous \
        --security-opt=label=disable \
        -e MINIO_ROOT_USER="minioadmin" \
        -e MINIO_ROOT_PASSWORD="$admin_password" \
        -v "$SECRETS"/tasks/s3-server.key:/root/.minio/certs/private.key:ro \
        -v "$SECRETS"/tasks/s3-server.pem:/root/.minio/certs/public.crt:ro \
        quay.io/minio/minio server /data --console-address :9001
    # wait until it started, create bucket
    podman run -d --interactive --name cockpituous-mc --pod=cockpituous \
        --security-opt=label=disable \
        -v "$SECRETS"/ca.pem:/etc/pki/ca-trust/source/anchors/ca.pem:ro \
        --entrypoint /bin/sh quay.io/minio/mc
    read s3user s3key < "$SECRETS/tasks/s3-keys/localhost.localdomain"
    podman exec -i cockpituous-mc /bin/sh <<EOF
set -e
cat /etc/pki/ca-trust/source/anchors/ca.pem >> /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
until mc alias set minio '$S3_URL_HOST' minioadmin '$admin_password'; do sleep 1; done
mc mb minio/images
mc mb minio/logs
mc anonymous set download minio/images
mc anonymous set download minio/logs
mc admin user add minio/ $s3user $s3key
mc admin policy attach minio/ readwrite --user $s3user
EOF
    unset s3key

    # scanning actual cockpit PRs interferes with automatic tests; but do this in interactive mode to have a complete deployment
    if [ -n "$INTERACTIVE" ]; then
        [ -z "$TOKEN" ] || cp -fv "$TOKEN" "$SECRETS"/webhook/.config--github-token
        podman run -d --name cockpituous-webhook --pod=cockpituous --user user \
            --security-opt=label=disable \
            -v "$SECRETS"/webhook:/run/secrets/webhook:ro \
            --env=AMQP_SERVER=$AMQP_POD \
            --env=COCKPIT_GITHUB_TOKEN_FILE=/run/secrets/webhook/.config--github-token \
            --env=COCKPIT_GITHUB_WEBHOOK_TOKEN_FILE=/run/secrets/webhook/.config--github-webhook-token \
            quay.io/cockpit/tasks:${TASKS_TAG:-latest} webhook
    fi

    # wait until AMQP initialized
    sleep 5
    until podman exec -i cockpituous-rabbitmq timeout 5 rabbitmqctl list_queues; do
        echo "waiting for RabbitMQ to come up..."
        sleep 3
    done

    # Run tasks container in the background
    # use bash as pid 1 to mop up zombies
    # we always want to upload images to our local S3 store
    podman run -d -it --name cockpituous-tasks --pod=cockpituous \
        --security-opt=label=disable \
        -v "$SECRETS"/tasks:/run/secrets/tasks:ro \
        -v "$SECRETS"/webhook:/run/secrets/webhook:ro \
        -v "${XDG_RUNTIME_DIR:-/run}/podman/podman.sock:/podman.sock" \
        --env=COCKPIT_GITHUB_TOKEN_FILE=/run/secrets/webhook/.config--github-token \
        --env=COCKPIT_CA_PEM=/run/secrets/webhook/ca.pem \
        --env=COCKPIT_BOTS_REPO=${COCKPIT_BOTS_REPO:-} \
        --env=COCKPIT_BOTS_BRANCH=${COCKPIT_BOTS_BRANCH:-} \
        --env=COCKPIT_TESTMAP_INJECT=main/unit-tests \
        --env=AMQP_SERVER=$AMQP_POD \
        --env=S3_LOGS_URL=$S3_URL_POD/logs/ \
        --env=COCKPIT_S3_KEY_DIR=/run/secrets/tasks/s3-keys \
        --env=COCKPIT_IMAGE_UPLOAD_STORE=$S3_URL_POD/images/ \
        --env=SKIP_STATIC_CHECK=1 \
        quay.io/cockpit/tasks:${TASKS_TAG:-latest} bash

    # check out the correct bots, as part of what cockpit-tasks would usually do
    podman exec -i cockpituous-tasks sh -euc \
        'git clone --quiet --depth=1 -b "${COCKPIT_BOTS_BRANCH:-main}" "${COCKPIT_BOTS_REPO:-https://github.com/cockpit-project/bots}"'
}

cleanup_containers() {
    echo "Cleaning up..."

    # clean up token, so that image-prune does not try to use it
    rm "$SECRETS"/webhook/.config--github-token

    # revert podman socket permission change
    chmod o-rw ${XDG_RUNTIME_DIR:-run}/podman/podman.sock

    podman stop --time=0 cockpituous-tasks
}

test_image() {
    # test image upload
    podman exec -i cockpituous-tasks timeout 30 sh -euxc '
        cd bots

        # fake an image
        echo world  > /cache/images/testimage
        NAME="testimage-$(sha256sum /cache/images/testimage | cut -f1 -d\ ).qcow2"
        mv /cache/images/testimage /cache/images/$NAME
        ln -s $NAME images/testimage

        # test image-upload to S3
        ./image-upload --store '$S3_URL_POD'/images/ testimage
        # S3 store received this
        python3 -m lib.s3 ls '$S3_URL_POD'/images/ | grep -q "testimage.*qcow"
        '

    # validate image downloading from S3
    podman exec -i cockpituous-tasks sh -euxc '
        rm --verbose /cache/images/testimage*
        cd bots
        ./image-download --store '$S3_URL_POD'/images/ testimage
        grep -q "^world" /cache/images/testimage-*.qcow2
        rm --verbose /cache/images/testimage*
        '

    # validate image pruning on s3
    podman exec -i cockpituous-tasks sh -euxc '
      cd bots
      rm images/testimage
      ./image-prune --s3 '$S3_URL_POD'/images/ --force --checkout-only
      # S3 store removed it
      [ -z "$(python3 -m lib.s3 ls '$S3_URL_POD'/images/ | grep testimage)" ]
    '
}

test_mock_pr() {
    podman cp "$MYDIR/mock-github" cockpituous-tasks:/work/bots/mock-github
    podman exec -i cockpituous-tasks sh -euxc "
        cd bots
        # test mock PR against our checkout, so that cloning will work
        SHA=\$(git rev-parse HEAD)

        # start mock GH server
        PYTHONPATH=. ./mock-github cockpit-project/bots \$SHA &
        GH_MOCK_PID=\$!
        export GITHUB_API=$GHAPI_URL_POD
        until curl --silent --fail \$GITHUB_API/repos/cockpit-project/bots; do sleep 0.1; done

        # simulate GitHub webhook event, put that into the webhook queue
        PYTHONPATH=. ./mock-github --print-pr-event cockpit-project/bots \$SHA | \
            ./publish-queue --amqp $AMQP_POD --create --queue webhook

        ./inspect-queue --amqp $AMQP_POD

        # first run-queue processes webhook → tests-scan → public queue
        ./run-queue --amqp $AMQP_POD
        ./inspect-queue --amqp $AMQP_POD

        # second run-queue actually runs the test
        ./run-queue --amqp $AMQP_POD

        kill \$GH_MOCK_PID
    "

    LOGS_URL="$S3_URL_HOST/logs/"
    CURL="curl --cacert $SECRETS/ca.pem --silent --fail --show-error"
    LOG_MATCH="$($CURL $LOGS_URL| grep -o "pull-1-[[:alnum:]-]*-unit-tests/log<")"
    LOG="$($CURL "${LOGS_URL}${LOG_MATCH%<}")"
    echo "--------------- mock PR test log -----------------"
    echo  "$LOG"
    echo "--------------- mock PR test log end -------------"
    assert_in 'Test run finished, return code: 0\|Job ran successfully' "$LOG"
    assert_in 'Running on:.*cockpituous' "$LOG"
}

test_pr() {
    # need to use real GitHub token for this
    [ -z "$TOKEN" ] || cp -fv "$TOKEN" "$SECRETS"/webhook/.config--github-token

    # run the main loop in the background; we could do this with a single run-queue invocation,
    # but we want to test the cockpit-tasks script
    podman exec -i cockpituous-tasks cockpit-tasks &
    TASKS_PID=$!

    podman exec -i cockpituous-tasks sh -euxc "
    cd bots

    ./tests-scan -p $PR --amqp '$AMQP_POD' --repo $PR_REPO;
    for retry in \$(seq 10); do
        ./tests-scan --repo $PR_REPO --human-readable --dry;
        OUT=\$(./tests-scan --repo $PR_REPO -p $PR --human-readable --dry);
        [ \"\${OUT%unit-tests*}\" = \"\$OUT\" ] || break;
        echo waiting until the status is visible;
        sleep 10;
    done;
    ./inspect-queue --amqp $AMQP_POD;"

    LOGS_URL="$S3_URL_HOST/logs/"
    CURL="curl --cacert $SECRETS/ca.pem --silent --fail --show-error"

    # wait until the unit-test got run and published, i.e. until the non-chunked raw log file exists
    for retry in $(seq 60); do
        LOG_MATCH="$($CURL $LOGS_URL| grep -o "pull-${PR}-[[:alnum:]-]*-unit-tests/log<")" && break
        echo waiting for unit-tests run to finish...
        sleep 10
    done

    # tell the tasks container iteration that we are done
    kill -TERM $TASKS_PID
    wait $TASKS_PID || true

    LOG_PATH="${LOG_MATCH%<}"

    # spot-checks that it produced sensible logs in S3
    LOG_URL="$LOGS_URL$LOG_PATH"
    LOG="$($CURL $LOG_URL)"
    LOG_HTML="$($CURL ${LOG_URL}.html)"
    echo "--------------- test log -----------------"
    echo  "$LOG"
    echo "--------------- test log end -------------"
    assert_in '<html>' "$LOG_HTML"
    assert_in 'Running on:.*cockpituous' "$LOG"
    assert_in 'Test run finished, return code: 0\|Job ran successfully' "$LOG"
    # validate test attachment if we ran cockpituous' own tests
    if [ "${PR_REPO%/cockpituous}" != "$PR_REPO" ]; then
        BOGUS_LOG=$($CURL ${LOG_URL%/log}/bogus.log)
        assert_in 'heisenberg compensator' "$BOGUS_LOG"
    fi
}

test_mock_image_refresh() {
    podman cp "$MYDIR/mock-github" cockpituous-tasks:/work/bots/mock-github
    podman cp "$MYDIR/mock-git-push" cockpituous-tasks:/usr/local/bin/git

    podman exec -i cockpituous-tasks sh -euxc "
        cd bots
        # test mock PR against our checkout, so that cloning will work
        SHA=\$(git rev-parse HEAD)

        # start mock GH server
        PYTHONPATH=. ./mock-github cockpit-project/bots \$SHA &
        GH_MOCK_PID=\$!
        export GITHUB_API=$GHAPI_URL_POD
        until curl --silent --fail \$GITHUB_API/repos/cockpit-project/bots; do sleep 0.1; done

        # simulate GitHub webhook event, put that into the webhook queue
        PYTHONPATH=. ./mock-github --print-image-refresh-event cockpit-project/bots \$SHA | \
            ./publish-queue --amqp $AMQP_POD --create --queue webhook

        ./inspect-queue --amqp $AMQP_POD

        # first run-queue processes webhook → issue-scan → public queue
        ./run-queue --amqp $AMQP_POD
        ./inspect-queue --amqp $AMQP_POD

        # second run-queue actually runs the image refresh
        ./run-queue --amqp $AMQP_POD

        kill \$GH_MOCK_PID
    "

    # successful refresh log
    LOGS_URL="$S3_URL_HOST/logs/"
    CURL="curl --cacert $SECRETS/ca.pem --silent --fail --show-error"
    LOG_MATCH="$($CURL $LOGS_URL| grep -o "image-refresh-foonux-[[:alnum:]-]*/log<")"
    LOG="$($CURL "${LOGS_URL}${LOG_MATCH%<}")"
    echo "--------------- mock image-refresh test log -----------------"
    echo  "$LOG"
    echo "--------------- mock image-refresh test log end -------------"
    assert_in 'Running on:.*cockpituous' "$LOG"
    assert_in './image-create.*foonux' "$LOG"
    assert_in "Uploading to $S3_URL_POD/images/foonux.*qcow2" "$LOG"
    assert_in 'Success.' "$LOG"

    # branch was (mock) pushed
    PUSH_LOG_MATCH="$($CURL $LOGS_URL| grep -o "image-refresh-foonux-[[:alnum:]-]*/git-push.log<")"
    PUSH_LOG="$($CURL "${LOGS_URL}${PUSH_LOG_MATCH%<}")"
    assert_in 'push origin +HEAD:refs/heads/image-refresh-foonux-' "$PUSH_LOG"
    podman exec -i -u root cockpituous-tasks rm /usr/local/bin/git

    podman exec -i cockpituous-tasks sh -euxc '
        # validate image contents
        qemu-img convert /cache/images/foonux-*.qcow2 /tmp/foonux.raw
        grep "^fakeimage" /tmp/foonux.raw
        rm /tmp/foonux.raw

        # image is on the S3 server
        cd bots
        python3 -m lib.s3 ls '$S3_URL_POD'/images/ | grep "foonux.*qcow"
    '
}

test_queue() {
    # tasks can connect to queue
    OUT=$(podman exec -i cockpituous-tasks bots/inspect-queue --amqp $AMQP_POD)
    echo "$OUT" | grep -q 'queue public does not exist'
}

test_podman() {
    # tasks can connect to host's podman service
    # this will be covered implicitly by job-runner, but as a more basal plumbing test this is easier to debug
    out="$(podman exec -i cockpituous-tasks podman-remote --url unix:///podman.sock ps)"
    assert_in 'cockpituous-tasks' "$out"
    out="$(podman exec -i cockpituous-tasks podman-remote --url unix:///podman.sock run -it --rm quay.io/cockpit/tasks:latest whoami)"
    assert_in '^user' "$out"
}

#
# main
#

parse_options "$@"
setup_config
launch_containers

# Follow the output
podman logs -f cockpituous-tasks &

if [ -n "$INTERACTIVE" ]; then
    echo "Starting a tasks container shell; exit it to clean up the deployment"
    podman exec -it cockpituous-tasks bash
else
    # tests which don't need GitHub interaction
    test_image
    test_queue
    test_podman
    # "almost" end-to-end, starting with GitHub webhook JSON payload injection; fully localy, no privs
    test_mock_pr
    # similar structure for issue-scan for an image refresh
    test_mock_image_refresh
    # if we have a PR number, run a unit test inside local deployment, and update PR status
    [ -z "$PR" ] || test_pr
fi

cleanup_containers
# bring logs -f to the foreground
wait
