#!/bin/sh
# Run a local pod with a AMQP and a tasks container
# You can run against a tasks container tag different than latest by setting "$TASKS_TAG"
set -eu

DAEMON=
TASK_SECRETS=
TOKEN=

while getopts "dhs:t:" opt; do
    case $opt in
        h)
            echo '-d runs the cockpit-tasks container as daemon'
            echo '-s supply the tasks-secret directory'
            echo '-t supply a token which will be copied into the webhook secrets'
            exit 0
            ;;
        d)
            DAEMON="-d"
            ;;
        t)
            if [ ! -e "$OPTARG" ]; then
                echo $OPTARG does not exist
                exit 1
            fi
            TOKEN="$OPTARG"
            ;;
        s)
            if [ ! -e "$OPTARG" ]; then
                echo $OPTARG does not exist
                exit 1
            fi
            TASK_SECRETS="-v $OPTARG:/secrets:ro"
            ;;
        esac
done

MYDIR=$(realpath $(dirname $0))
ROOTDIR=$(dirname $MYDIR)
DATADIR=$ROOTDIR/local-data
RABBITMQ_CONFIG=$DATADIR/rabbitmq-config
SECRETS=$DATADIR/secrets

if [ -z "$DAEMON" ]; then
    trap "podman pod rm -f cockpituous" EXIT INT QUIT PIPE
fi

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
     mkdir -p webhook
     cd webhook
     $MYDIR/credentials/webhook/generate.sh
     cd ..
    )
    # need to make files world-readable, as rabbitmq container runs as different user
    chmod -R go+rX "$SECRETS"/webhook
fi

if [ -n "$TOKEN" ]; then
    cp -fv "$TOKEN" "$SECRETS"/webhook/.config--github-token
fi

# start podman and run RabbitMQ in the background
podman run -d --name cockpituous-rabbitmq --pod=new:cockpituous -v "$RABBITMQ_CONFIG":/etc/rabbitmq:ro -v "$SECRETS"/webhook:/run/secrets/webhook:ro docker.io/rabbitmq:3-management

# wait until AMQP initialized
sleep 5
until podman exec -i cockpituous-rabbitmq sh -ec 'ls /var/lib/rabbitmq/mnesia/*.pid'; do
    echo "waiting for RabbitMQ to come up..."
    sleep 3
done

# Run tasks container in the foreground to see the output
# Press Control-C or let the "30 polls" iteration finish
podman run "$DAEMON" -it --name cockpituous-tasks $TASK_SECRETS -v "$SECRETS"/webhook:/run/secrets/webhook:ro -e TEST_PUBLISH=sink -e AMQP_SERVER=localhost:5671 --pod=cockpituous quay.io/cockpit/tasks:${TASKS_TAG:-latest}
