The Cockpit Continuous Delivery Tools
=====================================

These directories define our infrastructure related containers, and OpenShift
deployment resources:

 * [learn](./learn/): Machine learning for test results
 * [release](./release/): container to run releases
 * [sink](./sink/): log sink used by testing infrastructure
 * [tasks](./tasks/): run cockpit bots tasks like integration tests or image rebuilds

The [ansible](./ansible/) directory contains playbooks for setting up our CI/CD
infrastructure.
