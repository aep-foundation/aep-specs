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
  conformance/
  specs/
    core/
    grant-types/
    identity-methods/
    transports/
  examples/
  governance/
  guides/
  registry/
  schemas/
  test-vectors/
```

Rendered XML, text, HTML, and PDF outputs are written to the ignored
`../artifacts/` directory.

## Initial Document Set

The first Internet-Draft document set is:

- [`draft-kavian-aep-api-key-session-credential-01`](https://datatracker.ietf.org/doc/draft-kavian-aep-api-key-session-credential/): `ietf/specs/grant-types/draft-kavian-aep-api-key-session-credential-01.md`
- [`draft-kavian-aep-basic-session-credential-01`](https://datatracker.ietf.org/doc/draft-kavian-aep-basic-session-credential/): `ietf/specs/grant-types/draft-kavian-aep-basic-session-credential-01.md`
- [`draft-kavian-aep-did-web-identity-method-00`](https://datatracker.ietf.org/doc/draft-kavian-aep-did-web-identity-method/): `ietf/specs/identity-methods/draft-kavian-aep-did-web-identity-method-00.md`
- [`draft-kavian-aep-oauth-session-credential-01`](https://datatracker.ietf.org/doc/draft-kavian-aep-oauth-session-credential/): `ietf/specs/grant-types/draft-kavian-aep-oauth-session-credential-01.md`
- [`draft-kavian-agent-enrollment-protocol-01`](https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/): `ietf/specs/core/draft-kavian-agent-enrollment-protocol-01.md`

The core document defines the baseline HTTP binding, including:

- Terminology and roles.
- Protocol overview.
- The `AEP` HTTP authentication scheme.
- `/.well-known/aep` discovery.
- Inspect, Enroll, Grant, Revoke, and Status semantics.
- Client assertion JWT requirements.
- Identity method substrate.
- HTTP request and response behavior.
- Error handling.
- Security considerations.
- Privacy considerations.
- IANA considerations.

The three session-credential documents define the initial concrete Grant/Revoke credential formats: OAuth Bearer, API-key, and Basic. The `did:web` identity-method document defines the initial concrete identity method. Follow-on documents may define additional lifecycle commands, additional transports, policy disclosures, privacy preferences, attestation profiles, and other extensions.

The core document is independently implementable. The session-credential documents depend on the core document, but the core document does not depend on any specific session-credential document. A Service that does not issue session credentials can implement Inspect, Enroll, and Status without implementing Grant or Revoke. A Service that supports Grant and Revoke advertises one or more concrete grant types defined by companion session-credential specifications.

The first Internet-Draft set includes `did:web` as the initial AEP-defined identity method feature.

## Governance

Repository-level governance lives in `../GOVERNANCE.md`. IETF-specific support
governance, including extension registration guidance before formal IANA
registries exist, lives in `governance/`. Repository-local machine-readable
registry entries live in `registry/`.

## Conformance And Test Vectors

The `conformance/`, `test-vectors/`, and `schemas/` directories define the
initial implementation-checking surface for the published draft set. They are
scoped to the current core HTTP draft and the three published
session-credential drafts. They do not include later lifecycle commands,
additional identity methods beyond `did:web`, Platform conformance, or deferred extensions.

JSON Schemas validate stable wire objects used by the current test vectors.
They are support artifacts derived from the Internet-Draft prose, not a
replacement for the specifications.

## Implementation Guidance

The `guides/` directory contains non-normative implementation guidance. These
documents help implementers connect the drafts, examples, vectors, schemas, and
conformance harness without adding guidance text to the Internet-Draft sources.

## Rendering

Internet-Draft sources render to XML, text, HTML, and PDF artifacts with:

```sh
bundle config set path vendor/bundle
bundle install
python3 -m venv .venv
.venv/bin/python -m pip install -U pip
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m pip install -U "xml2rfc[pdf]" weasyprint
make -C . render
```

The render target writes artifacts to `../artifacts/` and regenerates
`../docs/index.html` from draft front matter. The repository does not commit
rendered specification artifacts; the deploy workflow publishes them on the
`latest` GitHub Release.

PDF rendering requires WeasyPrint and native font/text libraries. On macOS,
install the Homebrew dependencies before running the full render target:

```sh
brew install glib pango cairo gdk-pixbuf libffi fontconfig weasyprint
```

Use a Python environment that can load Homebrew native libraries. If PDF
rendering reports missing libraries such as `libgobject-2.0-0`, recreate the
virtual environment with Homebrew Python or another system Python instead of a
Conda-managed Python.
