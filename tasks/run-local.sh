#!/bin/sh
# Run a local pod with a AMQP and a tasks container
# You can run against a tasks container tag different than latest by setting "$TASKS_TAG"
set -eu

MYDIR=$(realpath $(dirname $0))
RABBITMQ_CONFIG=$(mktemp -dt rabbitmq-config.XXXXXX)
# SECRETS=$(mktemp -dt cockpituous-secrets.XXXXXX)
SECRETS="$MYDIR/secrets"
mkdir -p "$SECRETS"
# trap "rm -rf '$RABBITMQ_CONFIG' '$SECRETS'; podman pod rm -f cockpituous" EXIT INT QUIT PIPE

# generate flat files from RabbitMQ config map
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
    (cd $SECRETS
     $MYDIR/credentials/generate-ca.sh
     mkdir -p webhook
     cd webhook
     $MYDIR/credentials/webhook/generate.sh
     cd ..
    )
    # need to make files world-readable, as rabbitmq container runs as different user
    chmod -R go+rX "$SECRETS"/webhook
fi

# start podman and run RabbitMQ in the background
podman run -d --name cockpituous-rabbitmq --pod=new:cockpituous -v "$RABBITMQ_CONFIG":/etc/rabbitmq:ro -v "$SECRETS"/webhook:/run/secrets/webhook:ro -p 5671:5671 docker.io/rabbitmq:3-management

# wait until AMQP initialized
sleep 5
until podman exec -i cockpituous-rabbitmq sh -ec 'ls /var/lib/rabbitmq/mnesia/*.pid'; do
    echo "waiting for RabbitMQ to come up..."
    sleep 3
done

# Run tasks container in the foreground to see the output
# Press Control-C or let the "30 polls" iteration finish
# TODO run it in daemon mode so it doesn't block
podman run -d -it --name cockpituous-tasks -v "$SECRETS"/webhook:/run/secrets/webhook:ro -e AMQP_SERVER=localhost:5671 --pod=cockpituous quay.io/cockpit/tasks:${TASKS_TAG:-latest}
