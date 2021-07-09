#!/bin/sh
# Generate/Update grafana-dashboards ConfigMap for the default dashboards, and (re)deploy Prometheus/Grafana
set -eux
MYDIR=$(realpath -m "$0"/..)

# clean up old deployment
kubectl delete configmap/grafana-dashboards || true
kubectl delete -f $MYDIR/metrics.yaml || true

kubectl create configmap grafana-dashboards --from-file $MYDIR/cockpit-ci.json
kubectl create -f $MYDIR/metrics.yaml
