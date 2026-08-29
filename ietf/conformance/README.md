# AEP Conformance

This directory defines the conformance model for the currently published AEP
Internet-Draft set.

The current conformance scope is limited to:

- `draft-kavian-aep-api-key-session-credential-03`
- `draft-kavian-aep-basic-session-credential-03`
- `draft-kavian-aep-claims-01`
- `draft-kavian-aep-did-web-identity-method-00`
- `draft-kavian-aep-platform-hosted-identity-01`
- `draft-kavian-aep-oauth-session-credential-03`
- `draft-kavian-agent-enrollment-protocol-04`

This scope covers the HTTP binding, identity-method substrate, the initial
`did:web` identity method feature, Inspect, Enroll, Status, Grant, Revoke,
baseline `Authorization: AEP <jwt>` authentication, error handling,
idempotency, the three initial session-credential formats, and the optional
Platform Hosted Identity API. It also covers the optional Claims catalog and
its Agent and Service negotiation behavior.

## Roles

The conformance model defines these implementation roles:

| Role     | Scope                                                                                                                                                                                    |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Agent    | Consumes Inspect, constructs client assertions, invokes AEP commands, handles errors, and uses issued session credentials.                                                               |
| Platform | Publishes Platform discovery, provisions Service-scoped Agent DIDs, hosts DID documents, performs delegated signing, exposes lifecycle state, and optionally verifies hosted assertions. |
| Service  | Publishes Inspect, validates client assertions, processes AEP commands, returns defined errors, enforces idempotency, and issues/revokes advertised credential types.                    |

## Profiles

| Profile                  | Requirement                                                                         |
| ------------------------ | ----------------------------------------------------------------------------------- |
| Core HTTP                | Implements the core AEP draft over HTTP with an enabled identity method.            |
| Claims                   | Implements the Claims catalog and negotiation rules in addition to Core HTTP.       |
| API-Key Credential       | Implements the API-key session-credential draft in addition to Core HTTP.           |
| Basic Credential         | Implements the Basic session-credential draft in addition to Core HTTP.             |
| OAuth Bearer Credential  | Implements the OAuth Bearer session-credential draft in addition to Core HTTP.      |
| Platform Hosted Identity | Implements the Platform Hosted Identity draft as an optional Platform role profile. |

An implementation may claim one or more credential profiles. A Service that
does not advertise `grant` and `revoke` does not need to claim a credential
profile. A Platform Hosted Identity claim is independent of Agent and Service
claims.

An Agent or Service claims the Claims profile only when it implements the
registered Claim Value shapes it uses and the Claims draft's handling of
unknown required, preferred, optional, submitted, and object-member values.
The profile is optional and claim-dependent: supporting one locally defined
claim does not imply support for the AEP Claims catalog.

## Test Vector Relationship

Conformance requirements are exercised by test vectors in `../test-vectors/`.
Vectors are deterministic fixtures. They do not certify an implementation by
themselves; they provide the inputs and expected outputs that a harness can
execute against Agent, Service, and Platform implementations.

Run the offline fixture harness with:

```sh
make -C ietf check-harness
```

The harness validates semantic relationships encoded in the fixtures, including
endpoint construction from Inspect, media types, authentication scheme
selection, client assertion operation binding, idempotency conflict behavior,
credential-profile consistency, Platform discovery shape, Platform assertion
lifetime limits, Service-scoped Agent DID uniqueness, hosted verification
non-disclosure behavior, the absence of Platform key-rotation endpoints, Claims
catalog shapes, and Claims forward-compatibility relationships. It does not
contact a live Agent, Platform, or Service.

## Adapter Boundary

The cross-language harness is black-box and role-oriented:

- Agent tests drive an Agent with synthetic Inspect documents and verify the
  requests it constructs.
- Platform tests drive a Platform with synthetic provisioning, signing,
  lifecycle, and verification fixtures.
- Service tests drive a Service with synthetic requests and verify responses,
  error behavior, and state changes.
- Credential-profile tests run only when the implementation claims the
  corresponding profile.

Timing-sensitive checks, such as anti-enumeration timing behavior, should be
kept in a separate harness profile because they require repeated probes and
statistical thresholds.

## Capability Manifest

An implementation declares its tested roles and profiles in a development-time
capability manifest conforming to
[`capability-manifest.schema.json`](./capability-manifest.schema.json). The
manifest is conformance metadata. It is not an AEP wire document, is not
published through Inspect or Platform discovery, and is not required by a
production runtime.

Agent and Service claims include `core-http`. They can additionally claim
`claims`, `api-key`, `basic`, `oauth-bearer`, and
`platform-hosted-identity`. A Platform claim contains only
`platform-hosted-identity`. Each role occurs at most once.

See the validated
[`capability-manifest.json`](./examples/capability-manifest.json) example.

## Process Contract

An implementation adapter reads one JSON object per line from standard input
and writes one JSON object per line to standard output. Each request conforms
to [`adapter-request.schema.json`](./adapter-request.schema.json), and each
response conforms to
[`adapter-response.schema.json`](./adapter-response.schema.json). Responses
carry the request sequence number and can be returned in any order. Every
request receives exactly one response. Diagnostics belong on standard error.

Requests contain the selected role, profile, applicability expectation, vector
metadata, input, and expected outcome. The adapter executes the real public
implementation behavior represented by the case; it does not merely compare
or echo fixture fields.

Required cases cannot be skipped. Optional cases can pass, fail, or be skipped.
Cases classified as unsupported for a role are not dispatched. A malformed
response, duplicate or missing sequence, required-case skip, or nonzero adapter
exit is a harness failure.

The validated
[`adapter-request.json`](./examples/adapter-request.json) and
[`adapter-response.json`](./examples/adapter-response.json) files show one
complete exchange.

Run an implementation adapter with:

```sh
cd ietf
bundle exec ruby scripts/run_conformance.rb \
  --manifest path/to/capability-manifest.json \
  --role agent \
  --output conformance-report.json \
  -- path/to/adapter
```

Repeat `--suite CATEGORY` to select specific vector categories. With no suite
selection, the runner dispatches every vector applicable to the selected role
and the profiles claimed in the manifest. The adapter command and each of its
arguments are passed directly to the operating system without shell parsing.

The runner validates the manifest, vector index, requests, responses, and final
report. It accepts responses in any order, while rejecting missing, duplicate,
or unexpected sequence numbers. A failed case produces a valid report and exit
status 1. An adapter contract violation or nonzero adapter exit prevents report
generation.

## Vector Index and Reports

The sorted vector index conforms to
[`vector-index.schema.json`](./vector-index.schema.json). A report conforms to
[`report.schema.json`](./report.schema.json) and records:

- the implementation name and version;
- the tested role and claimed profiles;
- the AEP version;
- cryptographic revisions of the capability manifest and vector set; and
- passed, failed, and skipped totals by category and profile.

`manifest_revision` is the SHA-256 digest of the exact capability-manifest
file bytes. `vector_revision` is the SHA-256 digest of the parsed vector index
version followed by each indexed path and parsed vector in sorted index order.
Both values use the `sha256:` prefix and lowercase hexadecimal encoding.

Reports are release evidence, not runtime capability advertisements. The
validated [`vector-index.json`](./examples/vector-index.json) and
[`report.json`](./examples/report.json) files show the contract shapes.
