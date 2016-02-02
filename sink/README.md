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
services like IRC or GitHub. The following fields might be present:

 * `"onaborted"`: the status to process upon abortion
 * `"notify"`: message to send to IRC
 * `"github"`: object containing GitHub status info
 * `"badge"`: for updating badges
 * `"link"`: the link to the status message
 * `"extras"`: for putting extra files into the log directory

### Aborted runs

When the log ends without a final status line and the initial status
contained a `"onaborted"` field, its value is used as the final
status.

Typically, the 'onaborted' value contains instructions to set a status
on GitHub to "error", or to post a final message to IRC.

If `"onaborted"` is not present, the sink will tweak to initial status
and use that as the final status.  For example, it will modify the
GitHub status to say "Aborted without status".

### Github Status format

The `"github"` field of a status line can be used to make (almost)
arbitrary REST requests against the GitHub API.  It can be used to
update the status of commits and add comments to issues, for example.

The following fields are defined:

 * `"token"`: The OAuth token to use
 * `"requests"`: A list of requests to perform

Each request can have the following fields:

 * `"method"`: The HTTP method to use, such as GET or POST
 * `"resource"`: The resource to use, such as "/user"
 * `"data"`: The data to send in the request
 * `"result"`: A name for the result, to be used with string expansion

The `"token"`, `"requests"`, and `"resource"` fields are mandatory.

The `"resource"` and `"data"` values will be expanded.  Any occurance
of ":path" is replaced with a value from a previous request.  The
'path' is a sequence of names, separated by "." characters.  The first
name is looked up among all the named results of previous requests,
and the remaining names are then used to walk into that result.

To get a single ":" character, use "::".

Here is an example:

  { "github":
    { "token": "......",
      "requests": [
        { "method": "GET",
          "resource": "/user",
          "result": "user"
        },
        { "method": "POST",
          "resource": "repos/:user.login/cockpit/issues",
          "data": { "title": "New issue" }
          "result": "issue"
        },
        { "method": "POST",
          "resource": ":issue.comments_url",
          "data": { "body": "Very urgent" }
        }
      ]
    }
  }

This will create a new issue in the "cockpit" repo of the
authenticated user and add a comment to it.

As a special case, the result named "link" expands to the URL of the
current log.

You can use results from the initial status in the final status.

### Badge format

The `"badge"` part of a status object has the following fields:

 * `"name"`: The base filename of the badge file.
 * `"description"`: A short description of the thing that the badge is for.
 * `"status"`: A symbolic status of the thing, see below.
 * `"status-text"`: A short description of the status.

The full name of the badge is `<dir>/<name>.svg` where <dir> comes
from the `[Badges] Location` configuration item of the sink, and
<name> comes from the status object.  By default, badges are placed
into `~/public_html/status/`

The badge itself is a small image that includes `description` and
`status-text`, with a color determined by `status`.  `status` can be
one of "passed", "failed", or "error".  If `status-text` is omitted,
`status` is used instead.

### Link field

The `"link"` field will be automitically filled in by the sink. If it
is specified in the status JSON object, that the specified link will
take precedence. If a relative link is specified, it will be relative
to the URL that the sink would have used.

### Extras format

The `"extra"` part of a status object should be an array of strings.
Each string is a URL and is downloaded into the log directory.  The
last component of the URL will be the name of the file in the log
directory.
