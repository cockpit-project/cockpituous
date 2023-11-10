#!/bin/sh
# (Re)deploy Prometheus/Grafana to local podman, for development
# Note: This keeps the prometheus-data volume
set -eux
MYDIR=$(realpath -m "$0"/..)

# clean up old deployment
podman kube down "${MYDIR}/metrics.yaml"
for filter in grafana prometheus-config; do
    podman volume ls -q --filter "name=$filter" | xargs --no-run-if-empty podman volume rm
done

# "foobar" password secret for Grafana "admin" user
cat << EOF | podman kube play -
---
apiVersion: v1
kind: Secret
metadata:
  name: metrics-secrets
data:
  grafana-admin: Zm9vYmFy
EOF

# adjust the k8s deployment to work for podman play kube: grafana-dashboards ConfigMap gets built dynamically in
# metrics/deploy-k8s.sh, but it is much more flexible and ergonomic to just mount the dashboards directory
patch -o- "$MYDIR/metrics.yaml" - <<EOF | podman kube play -
--- metrics/metrics.yaml
+++ metrics/metrics.yaml
@@ -75,9 +73,8 @@ spec:
           configMap:
             name: grafana-provisioning-dashboards
         - name: grafana-dashboards
-          configMap:
-            # this is not defined here, but gets built from *.json files in ./deploy.sh
-            name: grafana-dashboards
+          hostPath:
+            path: metrics/dashboards

 ---
 kind: ConfigMap
EOF
