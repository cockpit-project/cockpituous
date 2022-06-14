# Cockpit CI metrics

Our CI system regularly [builds](https://github.com/cockpit-project/bots/blob/main/prometheus-stats) a [metrics file](https://prometheus.io/docs/instrumenting/exposition_formats/) which is stored on our log S3 bucket]: https://cockpit-logs.us-east-1.linodeobjects.com/prometheus

These kubernetes resources deploy [Prometheus](https://prometheus.io/) to
regularly read these metrics and store them in a database, and [Grafana](https://grafana.com/) to visualize these metrics as graphs.

## Deployment

 - For the first-ever installation, create a persistent volume claim to store
   the Prometheus database (as that is somewhat precious):

       oc create -f prometheus-claim.yaml

   Once this gets bound, it is ready to use. If that does not happen
   automatically, file a support ticket like [#341](https://pagure.io/centos-infra/issue/341).

 - Whenever the YAML resources or the dashboards change, this script cleans up all old resources and re-deploys everything:

       metrics/deploy.sh

   After that, Grafana should be available at https://grafana-frontdoor.apps.ocp.ci.centos.org and show the Cockpit CI dashboard at https://grafana-frontdoor.apps.ocp.ci.centos.org/d/ci/cockpit-ci


## Dashboard maintenance

You can log into Grafana with "Sign in" from the left menu bar at the bottom, as user `admin`. The password is in the [internal CI secrets repository](https://gitlab.cee.redhat.com/front-door-ci-wranglers/ci-secrets/-/blob/master/metrics/grafana-admin).

The metrics are meant to implement and measure our [Service Level objectives](https://github.com/cockpit-project/cockpit/wiki/DevelopmentPrinciples#our-testsci-error-budget). They are not complete yet.

Whenever you change the dashboard, use the "Dashboard settings" button (cog
icon at the top right) → JSON model, copy&paste it to
[cockpit.ci-json](./cockpit-ci.json), and send a pull request to update it.
