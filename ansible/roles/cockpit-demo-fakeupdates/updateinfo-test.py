#!/usr/bin/python3

import sys
import subprocess

repo_dir = "/var/tmp/repo"
updateInfo = {}

def cmd(command):
    subprocess.check_call(command, shell=True)

# disable all existing repositories
cmd("rm -rf /etc/yum.repos.d/* /var/cache/yum/*")

# have PackageKit start from a clean slate
cmd("systemctl stop packagekit; rm -rf /var/cache/PackageKit")

def createRpm(name, version, release, requires='', post=None, install=False, content=None, **info):
    '''Create a dummy rpm in repo_dir

    If install is True, install the package. Otherwise, update the package
    index in repo_dir.
    '''
    global updateinfo
    if post:
        postcode = '\n%%post\n' + post
    else:
        postcode = ''
    if requires:
        requires = "Requires: %s\n" % requires
    installcmds = "touch $RPM_BUILD_ROOT/stamp-{0}-{1}-{2}\n".format(name, version, release)
    installedfiles = "/stamp-{0}-{1}-{2}\n".format(name, version, release)
    if content is not None:
        for path, data in content.items():
            installcmds += 'mkdir -p $(dirname "$RPM_BUILD_ROOT/{0}")\n'.format(path)
            installcmds += 'cat >"$RPM_BUILD_ROOT/{0}" <<\'EOF\'\n'.format(path) + data + '\nEOF\n'
            installedfiles += "{0}\n".format(path)
    spec = """
Summary: dummy {0}
Name: {0}
Version: {1}
Release: {2}
License: BSD
BuildArch: noarch
{4}

%%install
{5}

%%description
Test package.

%%files
{6}

{3}
""".format(name, version, release, postcode, requires, installcmds, installedfiles)
    with open("/tmp/spec", "w") as f:
        f.write(spec)
    script = """
rpmbuild --quiet -bb /tmp/spec
mkdir -p {0}
cp ~/rpmbuild/RPMS/noarch/*.rpm {0}
rm -rf ~/rpmbuild
"""
    if install:
        script += "rpm -U --force {0}/{1}-{2}-{3}.*.rpm"
    cmd(script.format(repo_dir, name, version, release))
    if info:
        updateInfo[(name, version, release)] = info

def createYumUpdateInfo():
    xml = '<?xml version="1.0" encoding="UTF-8"?>\n<updates>\n'
    for ((pkg, ver, rel), info) in updateInfo.items():
        refs = ""
        for b in info.get("bugs", []):
            refs += '      <reference href="https://bugs.example.com?bug={0}" id="{0}" title="Bug#{0} Description" type="bugzilla"/>\n'.format(b)
        for c in info.get("cves", []):
            refs += '      <reference href="https://cve.mitre.org/cgi-bin/cvename.cgi?name={0}" id="{0}" title="{0}" type="cve"/>\n'.format(c)
        if info.get("securitySeverity"):
            refs += '      <reference href="https://access.redhat.com/security/updates/classification/#{0}" id="" title="" type="other"/>\n'.format(info["securitySeverity"])
        for e in info.get("errata", []):
            refs += '      <reference href="https://access.redhat.com/errata/{0}" id="{0}" title="{0}" type="self"/>\n'.format(e)

        xml += '''  <update from="test@example.com" status="stable" type="{severity}" version="2.0">
    <id>UPDATE-{pkg}-{ver}-{rel}</id>
    <title>{pkg} {ver}-{rel} update</title>
    <issued date="2017-01-01 12:34:56"/>
    <description>{desc}</description>
    <references>
{refs}
    </references>
    <pkglist>
     <collection short="0815">
        <package name="{pkg}" version="{ver}" release="{rel}" epoch="0" arch="noarch">
          <filename>{pkg}-{ver}-{rel}.noarch.rpm</filename>
        </package>
      </collection>
    </pkglist>
  </update>
'''.format(pkg=pkg, ver=ver, rel=rel, refs=refs,
            desc=info.get("changes", ""), severity=info.get("severity", "bugfix"))

    xml += '</updates>\n'
    return xml

def enableRepo():
    cmd('''set -e; printf '[updates]\nname=cockpittest\nbaseurl=file://{0}\nenabled=1\ngpgcheck=0\n' > /etc/yum.repos.d/cockpittest.repo
           echo '{1}' > /tmp/updateinfo.xml
           createrepo_c {0}
           modifyrepo_c /tmp/updateinfo.xml {0}/repodata
           $(which dnf 2>/dev/null|| which yum) clean all'''.format(repo_dir, createYumUpdateInfo()))

# main

# create updates
createRpm("vanilla", "1.0", "1", install=True)
createRpm("vanilla", "1.0", "2", changes="- Fix vanilla flavor", bugs=[123])

createRpm("chocolate", "2.0", "1", install=True)
createRpm("chocolate", "2.0", "2", requires="vanilla", changes="Darker chocolate", bugs=[234, 345])

createRpm("someserver", "3.1", "1", install=True)
createRpm("someserver", "3.2", "1", severity="security", changes="Fix remote DoS", cves=['CVE-2014-123456'])

enableRepo()

# dnf show available updates
print("\n===== dnf update info ===")
sys.stdout.flush()
cmd("dnf updateinfo info")

# PackageKit show available updates
print("\n===== Packagekit update info ===")
sys.stdout.flush()
cmd("pkcon refresh force")
cmd("pkcon get-updates")
cmd("echo 2 | pkcon get-update-detail chocolate")
