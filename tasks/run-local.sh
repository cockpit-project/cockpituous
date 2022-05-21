#!/bin/sh
# Run a local pod with a AMQP and a tasks container
# You can run against a tasks container tag different than latest by setting "$TASKS_TAG"
# similar for "$IMAGES_TAG" for images/sink
set -eu

MYDIR=$(realpath $(dirname $0))
ROOTDIR=$(dirname $MYDIR)
DATADIR=$ROOTDIR/local-data
RABBITMQ_CONFIG=$DATADIR/rabbitmq-config
SECRETS=$DATADIR/secrets
IMAGES=$DATADIR/images
IMAGE_PORT=${IMAGE_PORT:-8080}
S3_PORT=${S3_PORT:-9000}

# CLI option defaults/values
PR=
PR_REPO=cockpit-project/cockpituous
TOKEN=
INTERACTIVE=

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
    y = yaml.full_load(f)
files = [item for item in y["items"] if item["metadata"]["name"] == "amqp-config"][0]["data"]
for name, contents in files.items():
    with open(os.path.join('$RABBITMQ_CONFIG', name), 'w') as f:
        f.write(contents)
print(files)
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
        (mkdir -p tasks; cd tasks; $ROOTDIR/images/generate-image-certs.sh)

        # dummy token, for image-upload
        echo 0123abc > "$SECRETS"/webhook/.config--github-token
        echo 'user:$apr1$FzL9bivD$AzG7R8RNjuR.9DQRUrV.k.' > "$SECRETS"/tasks/htpasswd

        # dummy S3 keys in OpenShift tasks/build-secrets encoding, for testing their setup
        mkdir tasks/..data
        echo 'id12 geheim' > tasks/..data/s3-keys--r1.cloud.com
        echo 'id34 shhht' > tasks/..data/s3-keys--r2.cloud.com
        ln -s ..data/s3-keys--r1.cloud.com tasks/s3-keys--r1.cloud.com
        ln -s ..data/s3-keys--r2.cloud.com tasks/s3-keys--r2.cloud.com

        # minio S3 key
        echo 'cockpituous foobarfoo' > tasks/..data/s3-keys--localhost.localdomain
        ln -s ..data/s3-keys--localhost.localdomain tasks/s3-keys--localhost.localdomain

        ssh-keygen -f tasks/id_rsa -P ''
        cat <<EOF > tasks/ssh-config
Host sink-local
    Hostname cockpituous
    User user
    Port 8022
    IdentityFile /secrets/id_rsa
    UserKnownHostsFile /dev/null
    # cluster-local, don't bother with host keys
    StrictHostKeyChecking no
    CheckHostIP no
EOF
        )

        # need to make files world-readable, as containers run as different user
        chmod -R go+rX "$SECRETS"
    fi
}

launch_containers() {
    trap "podman pod rm -f cockpituous" EXIT INT QUIT PIPE

    # start podman and run RabbitMQ in the background
    # HACK: put data into a tmpfs instead of anonymous volume, see https://github.com/containers/podman/issues/9432
    podman run -d --name cockpituous-rabbitmq --pod=new:cockpituous \
        --publish $IMAGE_PORT:8080 \
        --publish $S3_PORT:9000 \
        --publish 9001:9001 \
        --tmpfs /var/lib/rabbitmq \
        -v "$RABBITMQ_CONFIG":/etc/rabbitmq:ro,z \
        -v "$SECRETS"/webhook:/run/secrets/webhook:ro,z \
        docker.io/rabbitmq

    # start image+sink in the background; see sink/sink-centosci.yaml
    mkdir -p "$IMAGES"
    chmod -R go+w "$IMAGES"  # allow unprivileged sink container to write
    SINK_CONFIG="$DATADIR/sink.cfg"
    cat <<EOF > "$SINK_CONFIG"
[Sink]
Url: http://localhost:$IMAGE_PORT/logs/%(identifier)s/
Logs: /cache/images/logs
PruneInterval: 0.5
EOF
    podman run -d --name cockpituous-images --pod=cockpituous --user user \
        -v "$IMAGES":/cache/images:z \
        -v "$SINK_CONFIG":/run/config/sink:ro,z \
        -v "$SECRETS"/tasks:/secrets:ro,z \
        -v "$SECRETS"/webhook:/run/secrets/webhook:ro,z \
        quay.io/cockpit/images:${IMAGES_TAG:-latest} \
        sh -ec '/usr/sbin/sshd -p 8022 -o StrictModes=no -E /dev/stderr; /usr/sbin/nginx -g "daemon off;"'

    # S3
    local admin_password="$(dd if=/dev/urandom bs=10 count=1 status=none | base64)"
    podman run -d --name cockpituous-s3 --pod=cockpituous \
        -e MINIO_ROOT_USER="minioadmin" \
        -e MINIO_ROOT_PASSWORD="$admin_password" \
        docker.io/minio/minio server /data --console-address :9001
    # wait until it started, create bucket
    podman run -d --interactive --name cockpituous-mc --pod=cockpituous \
        --entrypoint /bin/sh docker.io/minio/mc
    read s3user s3key < "$SECRETS/tasks/..data/s3-keys--localhost.localdomain"
    podman exec -i cockpituous-mc /bin/sh <<EOF
set -e
until mc alias set minio http://127.0.0.1:9000  minioadmin '$admin_password'; do sleep 1; done
mc mb minio/images
mc mb minio/logs
mc policy set download minio/images
mc policy set download minio/logs
mc admin user add minio/ $s3user $s3key
mc admin policy set minio/ readwrite user=$s3user
EOF
    unset s3key

    # scanning actual cockpit PRs interferes with automatic tests; but do this in interactive mode to have a complete deployment
    if [ -n "$INTERACTIVE" ]; then
        [ -z "$TOKEN" ] || cp -fv "$TOKEN" "$SECRETS"/webhook/.config--github-token
        podman run -d --name cockpituous-webhook --pod=cockpituous --user user \
            -v "$SECRETS"/webhook:/run/secrets/webhook:ro,z \
            -e AMQP_SERVER=localhost:5671 \
            quay.io/cockpit/tasks:${TASKS_TAG:-latest} webhook
    fi

    # wait until AMQP initialized
    sleep 5
    until podman exec -i cockpituous-rabbitmq timeout 5 rabbitmqctl list_queues; do
        echo "waiting for RabbitMQ to come up..."
        sleep 3
    done

    # Run tasks container in the backgroud
    podman run -d -it --name cockpituous-tasks --pod=cockpituous \
        -v "$SECRETS"/tasks:/secrets:ro,z \
        -v "$SECRETS"/webhook:/run/secrets/webhook:ro,z \
        -e COCKPIT_CA_PEM=/run/secrets/webhook/ca.pem \
        -e COCKPIT_BOTS_REPO=${COCKPIT_BOTS_REPO:-} \
        -e COCKPIT_BOTS_BRANCH=${COCKPIT_BOTS_BRANCH:-} \
        -e COCKPIT_TESTMAP_INJECT=main/unit-tests \
        -e AMQP_SERVER=localhost:5671 \
        -e TEST_PUBLISH=sink-local \
        -e S3_LOGS_URL=http://localhost.localdomain:9000/logs/ \
        quay.io/cockpit/tasks:${TASKS_TAG:-latest} ${INTERACTIVE:+sleep infinity}
}

cleanup_containers() {
    echo "Cleaning up..."

    # clean up dummy token, so that image-prune does not try to use it
    rm "$SECRETS"/webhook/.config--github-token

    if [ -n "$INTERACTIVE" ]; then
        podman stop cockpituous-tasks
    else
        # tell the tasks container iteration that we are done
        podman exec cockpituous-tasks kill -TERM 1
    fi
}

test_image() {
    # test image upload
    podman exec -i cockpituous-tasks timeout 30 sh -exc '
        # wait until tasks container has set up itself and checked out bots
        until [ -f bots/tests-trigger ]; do echo "waiting for tasks to initialize"; sleep 5; done

        for retry in $(seq 10); do
            echo "waiting for image server to initialize"
            curl --silent --fail --head --cacert $COCKPIT_CA_PEM https://cockpituous:8443 && break
            sleep 5
        done

        cd bots

        # fake an image
        echo world  > /cache/images/testimage
        NAME="testimage-$(sha256sum /cache/images/testimage | cut -f1 -d\ ).qcow2"
        mv /cache/images/testimage /cache/images/$NAME
        ln -s $NAME images/testimage

        # test image-upload to S3
        ./image-upload --store http://localhost.localdomain:9000/images/ testimage
        # S3 store received this
        curl http://localhost.localdomain:9000/images/ | grep -q "testimage.*qcow"

        # test image-upload to cockpit/image container (htpasswd credentials setup)
        ./image-upload --store https://cockpituous:8443 testimage
        '
    # image container received this
    test "$(cat "$IMAGES"/testimage-*.qcow2)" = "world"

    # validate OpenShift s3 keys secrets setup
    R1=$(podman exec -i cockpituous-tasks sh -ec 'cat ~/.config/cockpit-dev/s3-keys/r1.cloud.com')
    test "$R1" = "id12 geheim"
    R2=$(podman exec -i cockpituous-tasks sh -ec 'cat ~/.config/cockpit-dev/s3-keys/r2.cloud.com')
    test "$R2" = "id34 shhht"

    # validate cockpit/image downloading
    podman exec -i cockpituous-tasks sh -exc '
        rm --verbose /cache/images/testimage*
        cd bots
        ./image-download --store https://cockpituous:8443 testimage
        grep -q "^world" /cache/images/testimage-*.qcow2
        rm /cache/images/testimage*

        ./image-download --store http://localhost.localdomain:9000/images/ testimage
        grep -q "^world" /cache/images/testimage-*.qcow2
        '

    # validate that sink has the GitHub token to do status updates
    podman exec -i cockpituous-images cat /home/user/.config/github-token | grep -q ^0123abc
}

test_pr() {
    # need to use real GitHub token for this
    [ -z "$TOKEN" ] || cp -fv "$TOKEN" "$SECRETS"/webhook/.config--github-token

    podman exec -i cockpituous-tasks sh -exc "
    cd bots;
    ./tests-scan -p $PR --amqp 'localhost:5671' --repo $PR_REPO;
    for retry in \$(seq 10); do
        ./tests-scan --repo $PR_REPO --human-readable --dry;
        OUT=\$(./tests-scan --repo $PR_REPO -p $PR --human-readable --dry);
        [ \"\${OUT%unit-tests*}\" = \"\$OUT\" ] || break;
        echo waiting until the status is visible;
        sleep 10;
    done;
    ./inspect-queue --amqp localhost:5671;"

    LOGS_URL=http://localhost.localdomain:$S3_PORT/logs/

    # wait until the unit-test got run and published, i.e. until the non-chunked raw log file exists
    for retry in $(seq 60); do
        LOG_MATCH="$(curl --silent --show-error $LOGS_URL| grep -o "pull-${PR}-[[:alnum:]-]*-unit-tests/log<")" && break
        echo waiting for unit-tests run to finish...
        sleep 10
    done
    LOG_PATH="${LOG_MATCH%<}"

    # spot-checks that it produced sensible logs in S3
    LOG_URL="$LOGS_URL$LOG_PATH"
    LOG="$(curl $LOG_URL)"
    LOG_HTML="$(curl ${LOG_URL}.html)"
    echo "--------------- test log -----------------"
    echo  "$LOG"
    echo "--------------- test log end -------------"
    echo "$LOG_HTML" | grep -q '<html>'
    echo "$LOG" | grep -q 'Running on:.*cockpituous'
    echo "$LOG" | grep -q '^OK'
    echo "$LOG" | grep -q 'Test run finished, return code: 0'
    # validate test attachment if we ran cockpituous' own tests
    if [ "${PR_REPO%/cockpituous}" != "$PR_REPO" ]; then
        BOGUS_LOG=$(curl ${LOG_URL%/log}/bogus.log)
        echo "$BOGUS_LOG" | grep -q 'heisenberg compensator'
    fi
}

test_queue() {
    # tasks can connect to queue
    OUT=$(podman exec -i cockpituous-tasks bots/inspect-queue --amqp localhost:5671)
    echo "$OUT" | grep -q 'queue public is empty'
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
    # check out the correct bots, as part of what cockpit-tasks would usually do
    podman exec cockpituous-tasks sh -ec \
        'git clone --quiet --depth=1 -b "${COCKPIT_BOTS_BRANCH:-main}" "${COCKPIT_BOTS_REPO:-https://github.com/cockpit-project/bots}"'

    echo "Starting a tasks container shell; exit it to clean up the deployment"
    podman exec -it cockpituous-tasks bash
else
    # tests which don't need GitHub interaction
    test_image
    test_queue
    # if we have a PR number, run a unit test inside local deployment, and update PR status
    [ -z "$PR" ] || test_pr
fi

cleanup_containers
# bring logs -f to the foreground
wait
