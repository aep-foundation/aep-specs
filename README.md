# Agent Enrollment Protocol Specifications

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
  docs/artifacts/    # Rendered XML, text, and HTML specifications
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

Rendered specification artifacts are published under:

```text
docs/artifacts/
```

Official Internet-Draft records are published by the IETF Datatracker.

## Building

Check document structure:

```sh
make -C ietf check
```

Format Markdown tables in the Internet-Draft sources and supporting Markdown
files:

```sh
make -C ietf format
```

Render XML, text, and HTML artifacts:

```sh
make -C ietf render
```

Rendered artifacts are written directly to `docs/artifacts/`.

Run `idnits` against the rendered text artifacts:

```sh
make -C ietf idnits
```

## Contributing

See `CONTRIBUTING.md` for contribution guidelines and `ietf/STYLE.md` for
Internet-Draft writing conventions.

## License

See `LICENSE.md` for licensing details.
