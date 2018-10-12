# Test Flake Analysis Machine Learning

This code clusters log items related to similarity and then
classify whether new test logs fit into those clusters. The clustering
is unsupervised, and currently uses DBSCAN to accomplish this.
The classification currently uses nearest neighbor techniques.

We use distances to tell us whether two items are similar or not.
These distances are currently calculated via normalized compression
distance in ncd.py

## How to gather data

The data that is input is in a jsonl format. Each record in the input
is a separate line. See test-example.jsonl.gz The following fields are
required:

 * "status": String value of `"failure"`, `"success"`, `"error"` or `"skip"`
 * "test": Name of the test
 * "log": The full textual log of the test

The following additional fields are useful, and may be `null` or missing if unknown:

 * "revision": The commit that the given test was run on
 * "merged": Boolean whether the revision was merged or not
 * "context": A string context (operating system, browser, test suite) in which the test was run
 * "tracker": A URL of a known issue already tracking this failure
 * "url": Full URL to the complete test suite log and/or testing system log
 * "date": The ISO 8601 date/time when the test was run

Example record:

    {
        "test": "testTeamActive",
        "pull": "https://api.github.com/repos/cockpit-project/cockpit/pulls/9230",
        "revision": "2e4fd7d309b7f1c591c099e4041f8db20459c5ae",
        "status": "failure",
        "context": "fedora-27",
        "date": "2018-05-24T15:48:53Z",
        "merged": true,
        "url": "http://fedorapeople.org/groups/cockpit/logs/pull-9230-fedora-27/log",
        "tracker": "https://api.github.com/repos/cockpit-project/cockpit/issues/8905",
        "log": "...Error: timeout\nwait_js_cond(ph_in_text(\"#network-interface .panel:contains('tteam')"
    }

Note that the data above is expanded, but each JSON record should be on a single line.
So in reality it'll look more like:

    { "test": "testTeamActive", "pull": "https://api.github.com/repos/cockpit-project/cockpit/pulls/9230", "revision": "2e4fd7d309b7f1c591c099e4041f8db20459c5ae", "status": "failure", "context": "fedora-27", "date": "2018-05-24T15:48:53Z", "merged": true, "url": "http://fedorapeople.org/groups/cockpit/logs/pull-9230-fedora-27/log", "tracker": "https://api.github.com/repos/cockpit-project/cockpit/issues/8905", "log": "...Error: timeout\nwait_js_cond(ph_in_text(\"#network-interface .panel:contains('tteam')\"" }
    { "test": "testTeamActive", "pull": "https://api.github.com/repos/cockpit-project/cockpit/pulls/9230", "revision": "2e4fd7d309b7f1c591c099e4041f8db20459c5ae", "status": "failure", "context": "fedora-28", "date": "2018-05-24T15:52:00Z", "merged": false, "url": "http://fedorapeople.org/groups/cockpit/logs/pull-9230-verify-fedora-28/log", "tracker": null, "log": "...Error: timeout\nwait_js_cond(ph_in_text(\"#network-interface .panel:contains('tteam')\"" }
    ...

## How to train

Run the `train-tests` script with an input jsonl.gz file like this:

    $ train-tests -v test-example.jsonl.gz

This will place some data in the current working directory, unless you use the `--directory`
option or `TEST_DATA` environment variable to locate it elsewhere. Stored in this directory is
the model, and all of the various clusters.

## How to predict

Predict what a test result would do by passing a jsonl file like this:

    $ predict-tests -v test-predict.jsonl

This will output JSONL data on stdout with information about the cluster of similar
tests. Each field has a spread recorded of the values that field has in the cluster
and the number of times it is present. The ```"date"``` field will have the bounds
of start and end. An example cluster might look like this:

    {
        "test": [
            [ "testTeamActive", 2 ],
            [ "testTeamBond", 5 ]
        ],
        "status": [
            [ "failure", 7 ]
        ],
        "context": [
            [ "verify/fedora-27", 3 ],
            [ "verify/fedora-27", 4 ]
        ],
        "date": [
            "2018-05-24T15:48:53Z",
            "2018-05-30T01:01:30Z"
        ],
        "merged": [
            [ true, 5 ],
            [ true, 1 ],
            [ null, 1 ],
        ],
        "tracker": [
            [ "https://api.github.com/repos/cockpit-project/cockpit/issues/8905", 3 ]
            [ null, 4 ]
        ]
    }

Once again, this is an expanded record. The real output will be in JSONL format and
on a single line.

## How to use the Kubernetes Pod

This can be deployed as a Kubernetes service. To deploy use the following command:

    $ kubectl create -f learn/cockpit-learn.yaml

By default the service is only accessible from inside the same namespace. Given that it
has no authentication, this is appropriate. You can then setup an environment to access
by running a pod shell in Kubernetes. We use the same `learn` container image for this
for the example here, so that you can have access to the same data, but really any image
with curl should work:

    $ kubectl run -it test --image=docker.io/cockpit/learn --restart=Never -- sh

One uploads the data to the service by placing it in the `/train/` HTTP path:

    $ curl --progress-bar --fail --upload-file learn/test-example.jsonl.gz \
        http://$COCKPIT_LEARN_SERVICE_HOST:$COCKPIT_LEARN_SERVICE_PORT/train/test-example.jsonl.gz

One can look at the status of the upload by checking this directory for an '/active/' path
to be created and or updated. In addition the `/train/` HTTP path will have data moved from
it when training is complete:

    $ curl http://$COCKPIT_LEARN_SERVICE_HOST:$COCKPIT_LEARN_SERVICE_PORT/ | grep '<td'

Or you can look for the log of the latest training here:

    $ curl http://$COCKPIT_LEARN_SERVICE_HOST:$COCKPIT_LEARN_SERVICE_PORT/log

Now post some data to predict like this:

    $ curl -d '@learn/test-predict.jsonl' \
        http://$COCKPIT_LEARN_SERVICE_HOST:$COCKPIT_LEARN_SERVICE_PORT/predict
