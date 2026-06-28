# Agent Enrollment Protocol Specifications

[![CI](https://github.com/aep-foundation/aep-specs/actions/workflows/ci.yml/badge.svg)](https://github.com/aep-foundation/aep-specs/actions/workflows/ci.yml)
[![Deploy](https://github.com/aep-foundation/aep-specs/actions/workflows/deploy.yml/badge.svg)](https://github.com/aep-foundation/aep-specs/actions/workflows/deploy.yml)
[![IETF Draft](https://img.shields.io/badge/IETF-draft--kavian--agent--enrollment--protocol-blue)](https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/)
[![License](https://img.shields.io/badge/license-CC0%20%2B%20Apache--2.0%2FMIT-blue)](LICENSE.md)

This repository contains Internet-Draft sources and rendered specifications for
the Agent Enrollment Protocol (AEP).

AEP defines a machine-first enrollment and authentication protocol for
autonomous Agents. It lets an Agent discover Service requirements, enroll a
cryptographic identity, authenticate with per-request client assertions, obtain
optional session credentials, revoke those credentials, and query enrollment
status.

- Website: https://www.aep.foundation/
- Repository: https://github.com/aep-foundation/aep-specs

## Repository Layout

```text
aep-specs/
  docs/              # GitHub Pages site
  docs/schemas/      # Published JSON Schemas
  artifacts/         # Local generated spec artifacts, ignored by git
  ietf/              # Internet-Draft sources and rendering tooling
```

The `ietf/` directory contains the formal Internet-Draft sources. The `docs/` directory
is the GitHub Pages publishing root.

## Current Draft Set

The current draft set is organized as one core protocol document and three
companion session-credential documents:

- [`draft-kavian-agent-enrollment-protocol-00`](https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/):
  the baseline AEP protocol, including Inspect, Enroll, Grant, Revoke, Status,
  HTTP transport, discovery, `did:web` identity, client assertion
  authentication, errors, security, privacy, and IANA registrations.
- [`draft-kavian-aep-oauth-session-credential-00`](https://datatracker.ietf.org/doc/draft-kavian-aep-oauth-session-credential/):
  OAuth Bearer credentials issued and revoked through AEP Grant and Revoke.
- [`draft-kavian-aep-api-key-session-credential-00`](https://datatracker.ietf.org/doc/draft-kavian-aep-api-key-session-credential/):
  API-key credentials issued and revoked through AEP Grant and Revoke.
- [`draft-kavian-aep-basic-session-credential-00`](https://datatracker.ietf.org/doc/draft-kavian-aep-basic-session-credential/):
  HTTP Basic credentials issued and revoked through AEP Grant and Revoke.

The core document is independently implementable. Services that support Grant
and Revoke advertise one or more concrete grant types from companion
session-credential specifications.

Rendered specification artifacts are published as release assets:

```text
https://github.com/aep-foundation/aep-specs/releases/latest
```

Conformance support files are maintained under:

```text
ietf/conformance/
ietf/governance/
ietf/guides/
ietf/schemas/
ietf/test-vectors/
```

JSON Schemas are also published at stable `www.aep.foundation` URLs:

```text
https://www.aep.foundation/schemas/
```

Official Internet-Draft records are published by the IETF Datatracker.

## Building

Check document structure:

```sh
make -C ietf check
```

Validate JSON Schemas against mapped test vectors:

```sh
make -C ietf check-schemas
```

Verify published schema copies match `ietf/schemas/`:

```sh
make -C ietf check-published-schemas
```

Format Markdown tables in the Internet-Draft sources and supporting Markdown
files:

```sh
make -C ietf format
```

Render XML, text, HTML, and PDF artifacts:

```sh
make -C ietf render
```

Rendered artifacts are written to the ignored root-level `artifacts/`
directory. The `latest` GitHub Release publishes the rendered specification
artifacts for stable linking without committing generated binaries. The render
target also updates `docs/index.html` from draft front matter and refreshes
published JSON Schemas under `docs/schemas/`.

Run `idnits` against the rendered text artifacts:

```sh
make -C ietf idnits
```

## Contributing

See `CONTRIBUTING.md` for contribution guidelines, `GOVERNANCE.md` for
project governance, and `ietf/STYLE.md` for Internet-Draft writing
conventions.

## License

See `LICENSE.md` for licensing details.
