# CentOS CI OpenShift

Various parts of Cockpit's infrastructure, in particular parts of
[tasks](tasks/README.md) and [metrics docs](metrics/README.md), run on
[CentOS CI OpenShift](https://docs.centos.org/infra-docs/infra/openshift/):

https://console-openshift-console.apps.ocp.cloud.ci.centos.org/project-details/ns/cockpit/

It is acceptable to do transient changes like terminating the webhook or tasks
container to have it restarted (via their `ReplicationController`). But don't do
persistent/structural changes there -- all deployments happen via YAML files,
see the per-directory README.md files.

## Members

Access to the project is provided through the [`cockpit` Fedora group](https://accounts.fedoraproject.org/group/ocp-cico-cockpit/).

## Administrators/contact

That OpenShift cluster is maintained by the [Community Linux Engineering](https://docs.fedoraproject.org/en-US/cle/)
Fedora team, see the "How to contact us" → "Infrastructure" section on that page.
File an [infra ticket](https://forge.fedoraproject.org/infra/tickets/) for
requesting changes to the group or cluster config.

## Install client tools

Deploying resources on the command line or with our Ansible playbooks requires
the `oc` command line client. It's not packaged in Fedora, get the latest
"openshift-origin-client-tools" Linux release from
<https://github.com/openshift/origin/releases>.

## Logging in

Choose "centos_account", and log in with your Fedora account (user/password/2FA
token).

From there, authenticate on the command line:

 1. Click on your name on the top right
 2. Choose "Copy login command"
 3. Choose "centos_account" again
 4. Click on "Display token"
 5. Copy the `oc login` command from "Log in with this token" and run it in a terminal.

This should say

> You have one project on this server: "cockpit"
>
> Using project "cockpit".

Validate with `oc get pods` that you see e.g. the metrics and ci-weather pods.
