# AEP Implementer Guide

This guide is non-normative. It summarizes how to connect the AEP drafts,
examples, test vectors, schemas, and conformance harness when building an Agent
or Service.

## Source Of Truth

Use the current Internet-Draft set as the protocol authority:

- Core protocol: Inspect, Enroll, Status, Grant, Revoke, HTTP binding,
  `did:web`, client assertions, errors, idempotency, and IANA registrations.
- OAuth Bearer credential draft: `oauth-bearer` Grant and Revoke behavior.
- API-key credential draft: `api-key` Grant and Revoke behavior.
- Basic credential draft: `basic` Grant and Revoke behavior.

Use examples, schemas, vectors, and the offline harness to check
implementation behavior. If guidance conflicts with a draft, follow the draft.

## Command Sequencing

A typical Agent flow is:

1. Fetch Inspect from `/.well-known/aep`.
2. Confirm that `bindings.supported` contains `http`.
3. Confirm that `identity.methods` contains `did:web`.
4. Resolve required claim names from `claims.required`.
5. Enroll with `Authorization: AEP <jwt>` and `op` equal to `enroll`.
6. If Enroll returns `pending`, poll Status with `op` equal to `status`.
7. If session credentials are needed, choose a `grant_type` from
   `commands.grant_types` and call Grant with `op` equal to `grant`.
8. Present the issued session credential only to the issuing Service.
9. Revoke individual credentials or grant-type credentials when no longer
   needed.
10. Use `all_grant_types` Revoke when rotating away from all issued session
    credentials.

A Service can implement only Inspect, Enroll, and Status when it does not issue
session credentials. A Service that advertises Grant and Revoke needs at least
one concrete grant type.

## Endpoint Construction

Agents construct command URLs from `http.endpoint_base` in the Inspect document.
If `endpoint_base` is absent, use `/aep/`.

Append command paths with exactly one `/` separator:

| Command | Relative path |
| ------- | ------------- |
| Enroll  | `enroll`      |
| Status  | `status`      |
| Grant   | `grant`       |
| Revoke  | `revoke`      |

Both `/aep` and `/aep/` therefore produce `/aep/enroll`.

## Client Assertions

Enroll, Status, Grant, and Revoke use `Authorization: AEP <jwt>`. Inspect is
unauthenticated.

For each authenticated command, construct a fresh client assertion:

| Claim | Guidance                                                      |
| ----- | ------------------------------------------------------------- |
| `iss` | Agent DID.                                                    |
| `sub` | Same Agent DID as `iss`.                                      |
| `aud` | Service DID from `service.did` in Inspect.                    |
| `op`  | Command identifier: `enroll`, `status`, `grant`, or `revoke`. |
| `iat` | JWT NumericDate issued-at time.                               |
| `exp` | JWT NumericDate no more than 300 seconds after `iat`.         |
| `jti` | Fresh replay identifier for this assertion.                   |

Services should validate the signature, DID document key reference, audience,
operation, time window, and replay cache before processing command semantics.
Failures in these checks return `not_recognized`.

## Idempotency

POST commands are state-mutating and use the `Idempotency-Key` HTTP header:

| Command | Idempotency behavior                                           |
| ------- | -------------------------------------------------------------- |
| Enroll  | Required for retry; may also appear as body `idempotency_key`. |
| Grant   | Required for retry; header-only in the core draft.             |
| Revoke  | Required for retry; header-only in the core draft.             |

When Enroll includes both the header and body field, the values must match.

Services cache the response associated with the authenticated Agent and
idempotency key. Reusing the same key with the same body returns the cached or
equivalent response. Reusing the same key with a different body returns
`idempotency_conflict`.

## Credential Choice

Agents choose a session credential only from grant types advertised in
`commands.grant_types`.

| Grant type     | Use when                                                                     |
| -------------- | ---------------------------------------------------------------------------- |
| `oauth-bearer` | The Service has Bearer-token middleware or wants OAuth-style token handling. |
| `api-key`      | The Service already accepts opaque header-carried API keys.                  |
| `basic`        | The Service needs compatibility with HTTP Basic authentication middleware.   |

Grant responses are bearer-like secrets. Agents should store them as secrets
and present them only to the issuing Service. Services should issue expiring
credentials and avoid logging raw credential values.

## Revoke Strategy

Agents should use the narrowest Revoke form that matches their intent:

| Intent                             | Request body                                    |
| ---------------------------------- | ----------------------------------------------- |
| Revoke one known credential        | `credential_id` plus `grant_type`.              |
| Revoke all credentials of one type | `grant_type`.                                   |
| Revoke all session credentials     | `all_grant_types` set to string value `"true"`. |

Revoke returns success even when no matching credential existed. This lets
Agents safely retry cleanup without learning extra credential-existence state.

## Error Handling

Implementations should branch on the AEP `code` field in Problem Details.
Authentication-recognition failures use `not_recognized`; Services do not
reveal whether the cause was an unknown Agent, bad signature, wrong audience,
wrong operation, replay, time-window violation, unsupported identity method, or
unknown session credential.

Use `invalid_request` for malformed request structure when returning that error
does not reveal recognition state. Use `idempotency_conflict` for reuse of an
idempotency key with a different request body.

## Local Checks

Run the local checks before publishing changes:

```sh
make -C ietf check
```

The check target validates draft structure, external section references, test
vector metadata, schema mappings, published schema copies, and offline fixture
semantics.
