# Security Policy

## Supported Versions

Keel is pre-1.0. Security fixes target the default branch until release branches
exist.

## Reporting A Vulnerability

Do not open a public issue for a vulnerability. Use GitHub private vulnerability
reporting for `AysajanE/keel` when available:

```text
https://github.com/AysajanE/keel/security/advisories/new
```

If private vulnerability reporting is unavailable, contact the maintainer
through a private channel and include no sensitive details in any public issue.

Before a stable public release, this file should be updated with a
maintainer-controlled security email address.

Include:

- affected commit or release
- reproduction steps
- expected and actual behavior
- impact assessment
- any suggested mitigation

## Scope Notes

Keel installs and invokes other tools. Vulnerabilities in first-party or
third-party tools should be reported to the owning repository unless the issue
is caused by Keel's installer, wrappers, manifest, or documentation.
