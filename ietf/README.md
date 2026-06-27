# Agent Enrollment Protocol Internet-Drafts

This directory contains the Internet-Draft source set for the Agent Enrollment Protocol (AEP).

AEP defines a machine-first enrollment and authentication protocol for autonomous agents. The initial Internet-Draft work is scoped to the smallest interoperable HTTP command set with TLS protection:

- **Inspect**: discover service requirements and supported protocol capabilities.
- **Enroll**: register an Agent identity with a Service.
- **Grant**: exchange Agent proof-of-possession for an optional session credential.
- **Revoke**: invalidate issued session credentials.
- **Status**: query an enrolled Agent identity's current state.

The existing repository-level `specs/` directory contains the broader design corpus. This `ietf/` directory contains the formal Internet-Draft document set intended for public standards review and publication through the `aep-foundation/aep-specs` repository.

## Draft Layout

```text
ietf/
  README.md
  specs/
    core/
    extensions/
    transports/
  examples/
```

Rendered XML, text, and HTML outputs are published from `../docs/artifacts/`.

## Initial Document Set

The first Internet-Draft document set is:

- [`draft-kavian-agent-enrollment-protocol-00`](https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/): `ietf/specs/core/draft-kavian-agent-enrollment-protocol-00.md`
- [`draft-kavian-aep-oauth-session-credential-00`](https://datatracker.ietf.org/doc/draft-kavian-aep-oauth-session-credential/): `ietf/specs/extensions/draft-kavian-aep-oauth-session-credential-00.md`
- [`draft-kavian-aep-api-key-session-credential-00`](https://datatracker.ietf.org/doc/draft-kavian-aep-api-key-session-credential/): `ietf/specs/extensions/draft-kavian-aep-api-key-session-credential-00.md`
- [`draft-kavian-aep-basic-session-credential-00`](https://datatracker.ietf.org/doc/draft-kavian-aep-basic-session-credential/): `ietf/specs/extensions/draft-kavian-aep-basic-session-credential-00.md`

The core document defines the baseline HTTP binding, including:

- Terminology and roles.
- Protocol overview.
- The `AEP` HTTP authentication scheme.
- `/.well-known/aep` discovery.
- Inspect, Enroll, Grant, Revoke, and Status semantics.
- Client assertion JWT requirements.
- Baseline `did:web` requirements.
- HTTP request and response behavior.
- Error handling.
- Security considerations.
- Privacy considerations.
- IANA considerations.

The three session-credential documents define the initial concrete Grant/Revoke credential formats: OAuth Bearer, API-key, and Basic. Follow-on documents may define additional lifecycle commands, additional transports, policy disclosures, privacy preferences, attestation profiles, and other extensions.

The core document is independently implementable. The session-credential documents depend on the core document, but the core document does not depend on any specific session-credential document. A Service that does not issue session credentials can implement Inspect, Enroll, and Status without implementing Grant or Revoke. A Service that supports Grant and Revoke advertises one or more concrete grant types defined by companion session-credential specifications.

The first Internet-Draft set intentionally limits the baseline identity method to `did:web`.

## Rendering

Internet-Draft sources render to XML, text, and HTML artifacts with:

```sh
bundle config set path vendor/bundle
bundle install
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
make -C . render
```

The render target writes artifacts directly to `docs/artifacts/` for GitHub
Pages publication.
