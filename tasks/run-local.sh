#!/bin/sh
# Run a local pod with a AMQP and a tasks container
# You can run against a tasks container tag different than latest by setting "$TASKS_TAG"
# similar for "$IMAGES_TAG" for images/sink
set -eu

PR=
PR_REPO=cockpit-project/cockpituous
TOKEN=

while getopts "hs:t:p:r:" opt; do
    case $opt in
        h)
            echo '-p run unit tests in the local deployment against a real PR'
            echo "-r run unit tests in the local deployment against an owner/repo other than $PR_REPO"
            echo '-t supply a token which will be copied into the webhook secrets'
            exit 0
            ;;
        p) PR="$OPTARG" ;;
        r) PR_REPO="$OPTARG" ;;
        t)
            if [ ! -e "$OPTARG" ]; then
                echo $OPTARG does not exist
                exit 1
            fi
            TOKEN="$OPTARG"
            ;;
        esac
done

MYDIR=$(realpath $(dirname $0))
ROOTDIR=$(dirname $MYDIR)
DATADIR=$ROOTDIR/local-data
RABBITMQ_CONFIG=$DATADIR/rabbitmq-config
SECRETS=$DATADIR/secrets
IMAGES=$DATADIR/images
IMAGE_PORT=${IMAGE_PORT:-8080}

trap "podman pod rm -f cockpituous" EXIT INT QUIT PIPE

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

     ssh-keygen -f tasks/id_rsa -P ''
     cat <<EOF > tasks/ssh-config
Host sink-local
    Hostname cockpituous-images
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

# start podman and run RabbitMQ in the background
# HACK: put data into a tmpfs instead of anonymous volume, see https://github.com/containers/podman/issues/9432
podman run -d --name cockpituous-rabbitmq --pod=new:cockpituous \
    --publish $IMAGE_PORT:8080 \
    --tmpfs /var/lib/rabbitmq \
    -v "$RABBITMQ_CONFIG":/etc/rabbitmq:ro \
    -v "$SECRETS"/webhook:/run/secrets/webhook:ro \
    docker.io/rabbitmq:3-management

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
    -v "$SINK_CONFIG":/run/config/sink:ro \
    -v "$SECRETS"/tasks:/secrets:ro \
    -v "$SECRETS"/webhook:/run/secrets/webhook:ro \
    quay.io/cockpit/images:${IMAGES_TAG:-latest} \
    sh -ec '/usr/sbin/sshd -p 8022 -o StrictModes=no -E /dev/stderr; /usr/sbin/nginx -g "daemon off;"'

# wait until AMQP initialized
sleep 5
until podman exec -i cockpituous-rabbitmq sh -ec 'ls /var/lib/rabbitmq/mnesia/*.pid'; do
    echo "waiting for RabbitMQ to come up..."
    sleep 3
done

# Run tasks container in the backgroud
podman run -d -it --name cockpituous-tasks --pod=cockpituous \
    -v "$SECRETS"/tasks:/secrets:ro \
    -v "$SECRETS"/webhook:/run/secrets/webhook:ro \
    -e COCKPIT_CA_PEM=/run/secrets/webhook/ca.pem \
    -e COCKPIT_BOTS_REPO=${COCKPIT_BOTS_REPO:-} \
    -e COCKPIT_BOTS_BRANCH=${COCKPIT_BOTS_BRANCH:-} \
    -e COCKPIT_TESTMAP_INJECT=master/unit-tests \
    -e AMQP_SERVER=localhost:5671 \
    -e TEST_PUBLISH=sink-local \
    quay.io/cockpit/tasks:${TASKS_TAG:-latest}

# Follow the output
podman logs -f cockpituous-tasks &

# test image upload (htpasswd credentials setup)
podman exec -i cockpituous-tasks timeout 30 sh -ec '
    # wait until tasks container has set up itself and checked out bots
    until [ -f bots/tests-trigger ]; do echo "waiting for tasks to initialize"; sleep 5; done

    for retry in $(seq 10); do
        echo "waiting for image server to initialize"
        curl --silent --fail --head --cacert $COCKPIT_CA_PEM https://cockpituous-images:8443 && break
        sleep 5
    done

    # test image-upload
    cd bots
    echo world  > /cache/images/hello.txt
    ./image-upload --store https://cockpituous-images:8443 --state hello.txt
    '
test "$(cat "$IMAGES/hello.txt")" = "world"

# validate image downloading
podman exec -i cockpituous-tasks sh -exc '
    rm /cache/images/hello.txt
    cd bots
    ./image-download --store https://cockpituous-images:8443 --state hello.txt
    grep -q "^world" /cache/images/hello.txt
    '

# if we have a PR number, run a unit test inside local deployment, and update PR status
if [ -n "$PR" ]; then
    # need to use real GitHub token for this
    [ -z "$TOKEN" ] || cp -fv "$TOKEN" "$SECRETS"/webhook/.config--github-token

    podman exec -i cockpituous-tasks sh -exc "
    cd bots;
    ./tests-scan -p $PR --amqp 'localhost:5671' --repo $PR_REPO;
    for retry in \$(seq 10); do
        ./tests-scan --repo $PR_REPO -vd;
        OUT=\$(./tests-scan --repo $PR_REPO -p $PR -dv);
        [ \"\${OUT%unit-tests*}\" = \"\$OUT\" ] || break;
        echo waiting until the status is visible;
        sleep 10;
    done;
    ./inspect-queue --amqp localhost:5671;"

    # wait until the unit-test got run and published
    for retry in $(seq 60); do
        [ -e $IMAGES/logs/pull-$PR-*-unit-tests/status ] && break
        echo waiting for unit-tests run to finish...
        sleep 10
    done

    # spot-checks that it produced sensible logs
    LOG_ID=$(basename $IMAGES/logs/pull-$PR-*-unit-tests)
    RESULTS_DIR_URL=http://localhost:$IMAGE_PORT/logs/$LOG_ID
    # download the log from the images server instead of the file system, to validate that the former works properly
    STATUS=$(curl $RESULTS_DIR_URL/status)
    LOG=$(curl $RESULTS_DIR_URL/log)
    LOG_HTML=$(curl $RESULTS_DIR_URL/log.html)
    echo "--------------- test log -----------------"
    echo  "$LOG"
    echo "--------------- test log end -------------"
    echo "$STATUS" | grep -q '"message": "Tests passed"'
    echo "$LOG_HTML" | grep -q '<html>'
    echo "$LOG" | grep -q 'Running on: `cockpituous`'
    echo "$LOG" | grep -q '^OK'
    echo "$LOG" | grep -q 'Test run finished, return code: 0'
    # validate test attachment if we ran cockpituous' own tests
    if [ "${PR_REPO%/cockpituous}" != "$PR_REPO" ]; then
        BOGUS_LOG=$(curl $RESULTS_DIR_URL/bogus.log)
        echo "$BOGUS_LOG" | grep -q 'heisenberg compensator'
    fi
else
    # clean up dummy token, so that image-prune does not try to use it
    rm "$SECRETS"/webhook/.config--github-token
fi

# bring logs -f to the foreground; press Control-C or let the "30 polls" iteration finish
wait
