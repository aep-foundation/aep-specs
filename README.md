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

- `draft-kavian-agent-enrollment-protocol-00`
- `draft-kavian-aep-oauth-session-credential-00`
- `draft-kavian-aep-api-key-session-credential-00`
- `draft-kavian-aep-basic-session-credential-00`

Rendered specification artifacts are published under:

```text
docs/artifacts/
```

## Building

Check document structure:

```sh
make -C ietf check
```

Render XML, text, and HTML artifacts:

```sh
make -C ietf render
```

Rendered artifacts are written directly to `docs/artifacts/`.

## Contributing

See `CONTRIBUTING.md` for contribution guidelines and `ietf/STYLE.md` for
Internet-Draft writing conventions.

## License

See `LICENSE.md` for licensing details.
