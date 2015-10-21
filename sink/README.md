# Logging and Status Sink

This is a logging and status sink for Cockpit continous integration and delivery.

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


