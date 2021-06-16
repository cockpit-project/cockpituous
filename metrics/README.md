# Cockpit CI metrics

Our CI system regularly [builds](https://github.com/cockpit-project/bots/blob/master/prometheus-stats) a [metrics file](https://prometheus.io/docs/instrumenting/exposition_formats/) which is stored on CentOS CI's [logs web server](../sink/sink-centosci.yaml): https://logs-https-frontdoor.apps.ocp.ci.centos.org/prometheus

These kubernetes resources deploy [Prometheus](https://prometheus.io/) to
regularly read these metrics and store them in a database, and [Grafana](https://grafana.com/) to visualize these metrics as graphs.

## Deployment

 - For the first-ever installation, create a persistent volume claim to store
   the Prometheus database (as that is somewhat precious):

       oc create -f prometheus-claim.yaml

   Once this gets bound, it is ready to use. If that does not happen
   automatically, file a support ticket like [#341](https://pagure.io/centos-infra/issue/341).

 - Whenever the YAML resources change, first clean up all old resources and re-deploy everything:

       oc delete -f metrics.yaml
       oc create -f metrics.yaml

   After that, Grafana should be available at https://grafana-frontdoor.apps.ocp.ci.centos.org

## Configuration

These steps are not automated yet, but should be at some point:

 - On Grafana, choose "Sign in" from the left menu bar at the bottom, log in as `admin` with the initial password "admin", and immediately change it to the password mentioned in the [internal CI secrets repository](https://gitlab.cee.redhat.com/front-door-ci-wranglers/ci-secrets/-/blob/master/cockpituous.txt).

 - On Dashboards → Manage, click "Import", paste in the contents of [cockpit-ci.json](./cockpit-ci.json) (e.g. with `wl-copy < metrics/cockpit-ci.json` under Wayland) and confirm the loading.

 - Sign out again.

 - Confirm that https://grafana-frontdoor.apps.ocp.ci.centos.org/d/ci/cockpit-ci exists and shows the metrics.

## Dashboard maintenance

The metrics are meant to implement and measure our [Service Level objectives](https://github.com/cockpit-project/cockpit/wiki/DevelopmentPrinciples#our-testsci-error-budget). They are not complete yet.

Whenever you change the dashboard, use the "Dashboard settings" button (cog
icon at the top right) → JSON model, copy&paste it to
[cockpit.ci-json](./cockpit-ci.json), and send a pull request to update it.
