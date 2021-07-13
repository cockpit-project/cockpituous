#!/bin/sh
# Generate/Update grafana-dashboards ConfigMap for the default dashboards, and (re)deploy Prometheus/Grafana
set -eux
MYDIR=$(realpath -m "$0"/..)

# clean up old deployment
kubectl delete configmap/grafana-dashboards || true
kubectl delete -f $MYDIR/metrics.yaml || true

filearg=""
for f in $MYDIR/*.json; do
    filearg="$filearg --from-file $f"
done
kubectl create configmap grafana-dashboards $filearg
kubectl create -f $MYDIR/metrics.yaml
