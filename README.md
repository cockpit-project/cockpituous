The Cockpit Continuous Delivery Tools
=====================================

These directories define our CI infrastructure.

 * [ansible](./ansible/): playbooks for deploying our CI to various clouds
 * [e2e](./e2e/): automatically set up e2e cluster machines through the chassis domain controller
 * [local-s3](./local-s3/): local S3 container for image caching (e2e and integration tests)
 * [metrics](./metrics/): Prometheus, Grafana, and CI weather (running on OpenShift)
 * [tasks](./tasks/): tasks container and related setup scripts for integration tests or image rebuilds
