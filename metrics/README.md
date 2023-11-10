# Cockpit CI metrics

Our CI system regularly [builds](https://github.com/cockpit-project/bots/blob/main/prometheus-stats) a [metrics file](https://prometheus.io/docs/instrumenting/exposition_formats/) which is stored on our log S3 bucket]: https://cockpit-logs.us-east-1.linodeobjects.com/prometheus

These kubernetes resources deploy [Prometheus](https://prometheus.io/) to
regularly read these metrics and store them in a database, and [Grafana](https://grafana.com/) to visualize these metrics as graphs.

## Deployment to Kubernetes

 - For the first-ever installation, create a persistent volume claim to store
   the Prometheus database (as that is somewhat precious):

       kubectl create -f prometheus-claim.yaml

   Once this gets bound, it is ready to use. If that does not happen
   automatically, file a support ticket like [#341](https://pagure.io/centos-infra/issue/341).

 - Whenever the YAML resources or the dashboards change, this script cleans up all old resources and re-deploys everything:

       metrics/deploy-k8s.sh

   After that, Grafana should be available at https://grafana-cockpit.apps.ocp.cloud.ci.centos.org and show the Cockpit CI dashboard at https://grafana-cockpit.apps.ocp.cloud.ci.centos.org/d/ci/cockpit-ci


## Local deployment to podman

For development, you can also deploy everything into podman:

    metrics/deploy-podman.sh

Note that if you have `cockpit.socket` running, this will conflict on port
9090, so stop that first.

This will remove a previous deployment and volumes, except for the
`prometheus-data` one. If you want to start from scratch, clean that up with

    podman volume rm prometheus-data

Then you can access Prometheus on [localhost:9090](http://localhost:9090) and
Grafana on [localhost:3000](http://localhost:3000). You have to log into
Grafana as "admin:foobar" and go to Menu → Dashboards to see the deployed
boards.

## Dashboard maintenance

You can log into Grafana with "Sign in" from the left menu bar at the bottom, as user `admin`. The password is in the [internal CI secrets repository](https://gitlab.cee.redhat.com/front-door-ci-wranglers/ci-secrets/-/blob/master/metrics/grafana-admin) for k8s deployment, or "foobar" for local podman deployment.

The metrics are meant to implement and measure our [Service Level objectives](https://github.com/cockpit-project/cockpit/wiki/DevelopmentPrinciples#our-testsci-error-budget). They are not complete yet.

Whenever you change the dashboard, use the "Dashboard settings" button (cog
icon at the top right) → JSON model, copy&paste it to
[cockpit.ci-json](./dashboards/cockpit-ci.json), and send a pull request to update it.

## CI weather

We also have a [static viewer](https://github.com/cockpit-project/bots/blob/main/tests.html) for the test result database. It is *really* slow, but still has features which Grafana doesn't -- in particular, showing example log URLs for failures. This is deployed as a separate [centosci-ci-weather.yaml](./centosci-ci-weather.yaml) resource and accessible here: https://ci-weather-cockpit.apps.ocp.cloud.ci.centos.org/tests.html
