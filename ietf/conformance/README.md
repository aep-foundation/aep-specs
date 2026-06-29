# AEP Conformance

This directory defines the conformance model for the currently published AEP
Internet-Draft set.

The current conformance scope is limited to:

- `draft-kavian-aep-api-key-session-credential-00`
- `draft-kavian-aep-basic-session-credential-00`
- `draft-kavian-aep-did-web-identity-method-00`
- `draft-kavian-aep-oauth-session-credential-00`
- `draft-kavian-agent-enrollment-protocol-00`

This scope covers the HTTP binding, identity-method substrate, the initial
`did:web` identity method feature, Inspect, Enroll, Status, Grant, Revoke,
baseline `Authorization: AEP <jwt>` authentication, error handling,
idempotency, and the three initial session-credential formats.

## Roles

The initial conformance model defines two implementation roles:

| Role    | Scope                                                                                                                                                                 |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Agent   | Consumes Inspect, constructs client assertions, invokes AEP commands, handles errors, and uses issued session credentials.                                            |
| Service | Publishes Inspect, validates client assertions, processes AEP commands, returns defined errors, enforces idempotency, and issues/revokes advertised credential types. |

Platform conformance is out of scope for the current published draft set. A
future document can define Platform behavior if additional identity-hosting or
attestation drafts require it.

## Profiles

| Profile                 | Requirement                                                                    |
| ----------------------- | ------------------------------------------------------------------------------ |
| Core HTTP               | Implements the core AEP draft over HTTP with an enabled identity method.       |
| API-Key Credential      | Implements the API-key session-credential draft in addition to Core HTTP.      |
| Basic Credential        | Implements the Basic session-credential draft in addition to Core HTTP.        |
| OAuth Bearer Credential | Implements the OAuth Bearer session-credential draft in addition to Core HTTP. |

An implementation may claim one or more credential profiles. A Service that
does not advertise `grant` and `revoke` does not need to claim a credential
profile.

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
and credential-profile consistency. It does not contact a live Agent or
Service.

## Initial Harness Boundary

The first harness should remain black-box and role-oriented:

- Agent tests drive an Agent with synthetic Inspect documents and verify the
  requests it constructs.
- Service tests drive a Service with synthetic requests and verify responses,
  error behavior, and state changes.
- Credential-profile tests run only when the implementation claims the
  corresponding profile.

Timing-sensitive checks, such as anti-enumeration timing behavior, should be
kept in a separate harness profile because they require repeated probes and
statistical thresholds.
