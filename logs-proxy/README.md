# Cockpit S3 logs proxy

This service implements an [Anubis](https://anubis.techaro.lol/) log proxy for
our `cockpit-logs` S3 bucket. This will soon be changed from `public` to
`authenticated-read` to prevent unrestricted access to the logs, in particular
to fend off aggressive AI scrapers.

This re-uses our [bots S3 signing algorithm](https://github.com/cockpit-project/bots/blob/main/lib/s3.py).
S3 signing is hard with nginx/lua, but we don't care about performance here, so
Python will be fine.

# Deployment

The proxy runs on Kubernetes, in particular our CentOS CI OpenShift. That's
much less efficient than running it on Linode, but maintaining an instance with
a domain name and valid TLS certificate requires a lot more effort and
overhead. Given how rarely humans look at logs, the extra traffic shouldn't
hurt much.

The proxy requires an S3 token with read access, which is stored in the
`cockpit-s3-log-read-secrets` Kubernetes secret. Run

```
ansible-playbook -i inventory -f20 maintenance/sync-secrets.yml
```

first to create/update the secret. Then deploy the proxy with

```
oc create configmap logs-proxy-app --from-file logs-proxy/s3-proxy.py
oc apply -f logs-proxy/proxy.yaml
```
