# AEP Conformance

This directory defines the conformance model for the currently published AEP
Internet-Draft set.

The current conformance scope is limited to:

- `draft-kavian-aep-api-key-session-credential-03`
- `draft-kavian-aep-basic-session-credential-03`
- `draft-kavian-aep-claims-01`
- `draft-kavian-aep-did-web-identity-method-00`
- `draft-kavian-aep-platform-hosted-identity-00`
- `draft-kavian-aep-oauth-session-credential-03`
- `draft-kavian-agent-enrollment-protocol-03`

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
themselves; they provide the inputs and expected outputs that a future harness
can execute against Agent and Service implementations.

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

## Initial Harness Boundary

The first harness should remain black-box and role-oriented:

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
