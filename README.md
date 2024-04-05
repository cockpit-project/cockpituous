The Cockpit Continuous Delivery Tools
=====================================

These directories define our CI infrastructure.

 * [ansible](./ansible/): playbooks for deploying our CI to various clouds
 * [local-s3](./local-s3/): local S3 container for per-cluster image caching
 * [metrics](./metrics/): Prometheus, Grafana, and CI weather (running on OpenShift)
 * [tasks](./tasks/): tasks container and related setup scripts for integration tests or image rebuilds
