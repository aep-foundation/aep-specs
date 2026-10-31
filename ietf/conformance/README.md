# AEP Conformance

This directory defines the conformance model for the AEP
Internet-Draft set.

The current conformance scope is limited to:

- `draft-kavian-aep-api-key-session-credential-04`
- `draft-kavian-aep-basic-session-credential-04`
- `draft-kavian-aep-claims-01`
- `draft-kavian-aep-did-web-identity-method-00`
- `draft-kavian-aep-platform-hosted-identity-01`
- `draft-kavian-aep-oauth-session-credential-04`
- `draft-kavian-aep-service-documents-00`
- `draft-kavian-agent-enrollment-protocol-05`

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

| Profile                  | Requirement                                                                                             |
| ------------------------ | ------------------------------------------------------------------------------------------------------- |
| Core HTTP                | Implements the core AEP draft over HTTP with an enabled identity method.                                |
| Claims                   | Implements the Claims catalog and negotiation rules in addition to Core HTTP.                           |
| Service Documents        | Implements document discovery, reading, acknowledgements, and requirement updates for the claimed role. |
| API-Key Credential       | Implements the API-key session-credential draft in addition to Core HTTP.                               |
| Basic Credential         | Implements the Basic session-credential draft in addition to Core HTTP.                                 |
| OAuth Bearer Credential  | Implements the OAuth Bearer session-credential draft in addition to Core HTTP.                          |
| Platform Hosted Identity | Implements the Platform Hosted Identity draft as an optional Platform role profile.                     |

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
`claims`, `api-key`, `basic`, `oauth-bearer`, `service-documents`, and
`platform-hosted-identity`. A Platform claim contains
`platform-hosted-identity` and may additionally contain `service-documents`.
Each role occurs at most once.

## Service Documents Profile

`service-documents` is optional and activates only its explicitly classified
vectors. Agent and Service implementations retain their `core-http` claim;
a Platform retains `platform-hosted-identity`. Existing implementations must
not advertise this profile until their adapters exercise the real behavior.

- `wire-shapes`: feed each `value` through the named public parser or validator
  and compare its acceptance to the corresponding named result. Unsupported
  portable structure requires HTML fallback at the reading layer.
- `structural-limits`: construct boundary inputs from the fixture templates.
  `catalog` clones descriptors with distinct `doc0` through `docN` IDs;
  `duplicate-ids` changes only a cloned descriptor's title; `duplicate-media`
  adds two JSON representations with different URLs. `title`, `text`, and
  `url` produce values of the specified length. `blocks` creates the specified
  paragraph counts in summary and content; `sections` wraps the document to
  the specified depth; `list` creates the specified number of string items.
  Exercise actual parser limits, including both sides of each boundary.
- `enrollment-lifecycle`: configure a Service policy to accept valid updates,
  stage the supplied record, run operations in order, then run the two distinct
  concurrent updates. Compare stored identity, claims, acknowledgements and
  credentials. Independently repeat against each listed lifecycle state and
  verify it is preserved. Stored ID order is not significant; wire IDs retain case.
- `approval-snapshot`: begin with the captured IDs and then present each current
  catalog scenario independently. A Platform must block missing/unavailable IDs
  and wrong-Service binding while allowing HTML fallback and ignoring added IDs.
- `grant-guidance`: Service adapters exercise Grant rejection and the supplied
  Enroll requests with document requirements enabled. Agent adapters surface
  the supplied error and verify that no Enroll or Grant retry is invoked.
- `portable-presentation`: Agent adapters exercise their document renderer;
  compare wording, structure, summary labeling, safe fencing, and web fallback.
- `retrieval-safety`: drive the real fetch boundary with controlled HTTP/DNS
  transports and inspect every outgoing request. Do not contact public services
  or real private addresses. Feed oversized bodies and failures without exposing
  partial content. Platform applicability covers document approval fetches.

Repository checks validate schemas, fixture consistency, and profile dispatch.
The fixture adapter tests the harness process contract only; it does not prove
that any SDK implements document approval, retrieval, or lifecycle behavior.

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
selection, the runner evaluates each vector's explicit classification for the
selected role. Required and optional cases are dispatched when their profile is
claimed in the manifest; unsupported cases are not dispatched. The adapter
command and each of its arguments are passed directly to the operating system
without shell parsing.

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
