# Logging and Status Sink

This is a logging and status sink for Cockpit continous integration and delivery.

It is a standalone python script. No other dependencies are required. Copy it
to the home directory (or default login directory) of the public location where
you wish to store the logs.

The script will be invoked over SSH by tools such as the cockpit tests. It will
be run something like this:

$ log-data | ssh fedorapeople.org -- python sink log-identifier

The source of data is piped in, see the format below. The log-identifier is
a unique logging identifier, such as a release name or git sha. The script
is pre-configured to be uploaded to your personal fedorapeople.org account.

You may need to configure your fedorapeople.org user name in ~/.ssh/config
on the source machine.

In order for the script to talk to github, you need to place a token on
the target sink system in a ~/.config/github-token file.

# Input format

The basic input format of the sink is text. This text will be placed in a
file called `log`

If the first line of the text is a JSON object, it will be treated as status
information. In this case the last line of the output should also be a JSON object,
which will be written to a file called `status` in the output directory.

These JSON status lines are not written to `log`. If a JSON status is present
at the top of the output, then another must be present at the end, or the
log is considered incomplete.

If the text input is followed by a zero 'nul' character, then the sink expects
a tarball to follow. This tarball will be extracted into the log directory.

# Status format

When a status JSON object is present, then the sink will send updates to
services like IRC or GitHub. The following fields are present:

 * `"notify"`: message to send to IRC
 * `"github"`: object containing GitHub status info

### Github Status format

The `"github"` object above has the following fields:

 * `"resource"`: The full resource url of the Github Status
 * `"status"`: The GitHub status data


