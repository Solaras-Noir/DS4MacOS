# Cloud environment for this repo

Claude Code cloud sessions run on Ubuntu 24.04 x86_64 VMs with no Swift toolchain. This environment
adds one, plus the Windows cross-compiler for the XInput stub. Set it up once at claude.ai/code:
open the environment selector (the cloud icon above the message box), choose **Add cloud
environment**, and fill in the fields below.

## Name

`DS4MacOS`

## Network access

**Custom**, with **Also include default list of common package managers** checked, and this list:

```
download.swift.org
registry-1.docker.io
auth.docker.io
index.docker.io
production.cloudflare.docker.com
```

`swift.org` is on the default allowlist but the toolchain tarballs come from `download.swift.org`.
If that host turns out to be blocked anyway, the setup script falls back to the official Swift
Docker image from Docker Hub. The Docker Hub hosts are on the default list already; listing them
again costs nothing and guards against the default list changing.

## Environment variables

```
BASH_DEFAULT_TIMEOUT_MS=600000
BASH_MAX_TIMEOUT_MS=1200000
SWIFT_VERSION=6.2
```

## Setup script

Paste the contents of `scripts/cloud-setup.sh` from this repo. It installs the Swift toolchain,
`mingw-w64`, and pulls the Swift Docker image as a fallback. The first session in the environment
runs it; later sessions start from the cached snapshot if it finished within about five minutes.

## Checking it worked

In the first session, ask the lead to run `scripts/swift --version` and `x86_64-w64-mingw32-gcc
--version`. The M0 spec makes this the first task, so you do not need to do it by hand.

## Changing it later

Editing the setup script or the allowed domains rebuilds the cache on the next new session.
Existing sessions keep what they have.
