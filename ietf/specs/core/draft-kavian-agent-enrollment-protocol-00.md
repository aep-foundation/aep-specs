---
title: "The Agent Enrollment Protocol"
abbrev: "AEP"
docname: draft-kavian-agent-enrollment-protocol-00
category: std
ipr: trust200902
submissiontype: IETF
stand_alone: true
pi:
  toc: yes
  sortrefs: yes
  symrefs: yes
author:
  -
    ins: N. Kavian
    name: N. Kavian
    organization: Jarwin, Inc. (InFlow)

normative:
  RFC3339:
  RFC6839:
  RFC7515:
  RFC7519:
  RFC8259:
  RFC8032:
  RFC8446:
  RFC8615:
  RFC9110:
  RFC9112:
  RFC9113:
  RFC9114:
  RFC9457:
  W3C-DID:
    title: "Decentralized Identifiers (DIDs) v1.0"
    target: https://www.w3.org/TR/did-core/
    author:
      - org: W3C

informative:
  RFC8126:
  RFC8725:
...

--- abstract

The Agent Enrollment Protocol (AEP) defines an HTTP-based mechanism for autonomous agents to discover service enrollment requirements, enroll an agent identity, obtain optional session credentials, revoke those credentials, and query enrollment status. AEP uses Decentralized Identifiers (DIDs) {{W3C-DID}}, client assertion JWTs {{RFC7519}}, and HTTP Problem Details {{RFC9457}} to provide a narrow machine-first enrollment and authentication substrate for agent-to-service interactions.

--- middle

# Introduction

Autonomous agents increasingly interact with internet services without a human directly completing registration forms, email confirmations, password setup, or dashboard-based API-key provisioning. Existing HTTP authentication mechanisms can authenticate an already-provisioned client, but they do not define a machine-first enrollment flow by which an autonomous agent discovers a service's requirements, presents a cryptographic identity, and becomes recognized by that service.

The Agent Enrollment Protocol (AEP) defines that enrollment substrate. AEP lets an Agent discover what a Service requires, enroll a `did:web` identity, authenticate AEP commands with a per-request client assertion JWT, optionally obtain a session credential, revoke issued session credentials, and query enrollment status.

AEP is deliberately narrow. It does not define payment settlement, checkout semantics, action authorization, KYC execution, or legal policy. Those functions can compose above or beside AEP. This document defines only the minimum HTTP protocol needed for interoperable Agent enrollment and session-credential bootstrapping.

This document's scope is limited to the HTTP binding for Inspect, Enroll, Grant, Revoke, and Status. Update, Rotate, Decommission, non-HTTP transports, concrete session-credential formats, policy disclosures, KYA, ZK proofs, and other extensions are out of scope for this document.

# Requirements Language

{::boilerplate bcp14-tagged}

# Terminology

Agent:
: Software acting autonomously. An Agent holds or controls a cryptographic key and initiates AEP requests.

Service:
: The HTTP server that receives AEP requests and decides whether to enroll or recognize an Agent.

Owner:
: The human or organization that owns or controls an Agent. Owner details are represented as claims when a Service requires them.

Platform:
: An optional operator that hosts Agent identity material or signing infrastructure. A Platform is not required by AEP.

Verifier:
: A party that verifies claims about an Agent or Owner and may issue attestations referenced by the Agent. This document does not define attestation formats.

Inspect document:
: The JSON discovery document published by a Service at `/.well-known/aep`. It advertises AEP version, supported commands, accepted identity methods, requested claims, endpoint configuration, and extension support.

Client assertion:
: A JWT signed by the Agent's private key and presented on authenticated AEP commands. The assertion binds the Agent identity, Service identity, command name, issuance time, expiration time, and replay identifier.

Session credential:
: A stateful credential issued by the Grant command and presented on later requests according to a separate session-credential specification.

Grant type:
: A string identifier for a concrete session-credential format supported by the Service, such as an OAuth Bearer, API-key, or Basic credential specification.

# Protocol Overview

The baseline AEP flow is:

1. The Agent fetches the Service's Inspect document.
2. The Agent evaluates whether it can satisfy the Service's `did:web` and claim requirements.
3. The Agent constructs a client assertion JWT with `aud` equal to the Service DID and `op` equal to the command being invoked.
4. The Agent invokes Enroll.
5. The Agent calls Status when enrollment is pending or when it needs current state.
6. The Agent may call Grant for a supported session-credential type.
7. The Agent may call Revoke to invalidate issued session credentials.

Inspect is unauthenticated. Enroll, Grant, Revoke, and Status are authenticated with the baseline `Authorization: AEP <jwt>` form. Session credentials, once issued, MAY be used on commands that allow the selected credential type; Grant and Revoke themselves always use the baseline client assertion.

# HTTP Binding

This document defines an HTTP binding using HTTP semantics {{RFC9110}} over HTTP/1.1 {{RFC9112}}, HTTP/2 {{RFC9113}}, or HTTP/3 {{RFC9114}}. Network use of this binding requires TLS 1.3 or later {{RFC8446}}. Plaintext HTTP is out of scope.

The binding uses only `GET` and `POST`:

| Command | Method | Endpoint |
|---|---|---|
| Inspect | `GET` | `/.well-known/aep` |
| Enroll | `POST` | `enroll` relative to `endpoint_base` |
| Status | `GET` | `status` relative to `endpoint_base` |
| Grant | `POST` | `grant` relative to `endpoint_base` |
| Revoke | `POST` | `revoke` relative to `endpoint_base` |

The `endpoint_base` value is published in the Inspect document under `http.endpoint_base`. If omitted, Agents MUST use `/aep/`. Agents construct command URLs by appending the command's relative path to `endpoint_base` with exactly one `/` separator, regardless of whether `endpoint_base` includes a trailing slash. For example, both `/aep` and `/aep/` produce `/aep/enroll` for Enroll.

Requests and successful responses that carry AEP JSON payloads use `application/aep+json`, which uses the `+json` structured syntax suffix {{RFC6839}}. Error responses use `application/problem+json`.

Authenticated commands carry a baseline client assertion as:

~~~ http-message
Authorization: AEP <jwt>
~~~

When a session credential is used on a command that allows it, the credential presentation form is defined by the concrete session-credential document.

# Discovery and Inspect

The Inspect document is available at the well-known URI path defined for AEP {{RFC8615}}:

~~~ http-message
GET /.well-known/aep HTTP/1.1
Host: example.com
Accept: application/aep+json
~~~

The response body is a JSON object {{RFC8259}}. AEP-owned numeric protocol values are represented as JSON strings. Field names use `lower_snake_case`.

The Inspect document shown here contains only the fields required for the HTTP binding, `did:web`, Inspect, Enroll, Grant, Revoke, and Status:

~~~ json
{
  "aep_version": "1.0",
  "bindings": {
    "supported": ["http"]
  },
  "claims": {
    "optional": [],
    "preferred": [],
    "required": ["contact.email"]
  },
  "commands": {
    "grant_types": ["oauth-bearer"],
    "supported": ["enroll", "grant", "inspect", "revoke", "status"]
  },
  "core": {
    "signing_algorithms": ["EdDSA", "ES256"]
  },
  "extensions": {
    "supported": []
  },
  "http": {
    "endpoint_base": "/aep/"
  },
  "identity": {
    "methods": ["did:web"]
  },
  "service": {
    "did": "did:web:api.example.com"
  }
}
~~~

`commands.supported` lists commands the Service exposes. Agents MUST NOT invoke commands absent from this list.

`commands.grant_types` lists concrete session-credential formats the Service can issue and revoke. If this array is empty or absent, the Service MUST NOT list `grant` or `revoke` in `commands.supported`.

`identity.methods` MUST contain `did:web` when the Service accepts this document's identity method. Other DID methods are out of scope for this document.

`service.did` identifies the Service. Agents use this value as the `aud` claim in client assertion JWTs.

Services SHOULD send HTTP cache metadata, including `Cache-Control` and `ETag`, on Inspect responses. A default freshness lifetime of 300 seconds is RECOMMENDED when the Service does not need a shorter policy window.

# DID Method: did:web

This document defines `did:web` as the only required identity method. A Service that supports this document advertises:

~~~ json
{
  "identity": {
    "methods": ["did:web"]
  }
}
~~~

An Agent using this document identifies itself with a `did:web` URI. The Service resolves the DID to obtain the Agent's public verification key:

* `did:web:<host>` resolves to `https://<host>/.well-known/did.json`.
* `did:web:<host>:<path>` resolves to `https://<host>/<path>/did.json`.

The resolved DID document MUST contain a verification method referenced by the JWT `kid` header. The verification method MUST expose a public key in a form the Service can validate against the selected JOSE signing algorithm.

Services MUST resolve `did:web` documents over HTTPS. Services SHOULD cache resolved DID documents and SHOULD honor upstream cache metadata. A default cache lifetime of 300 seconds is RECOMMENDED when no shorter upstream lifetime is provided.

If the Agent presents an identity method not listed in the Service's `identity.methods` array, the Service MUST reject the request as `not_recognized`.

# Client Assertion JWT

Enroll, Grant, Revoke, and Status use a signed client assertion JWT for Agent authentication. Inspect is unauthenticated and does not use a client assertion.

The client assertion JWT is carried as:

~~~ http-message
Authorization: AEP <jwt>
~~~

The JWT is a JWS compact serialization {{RFC7515}} consisting of a JOSE header, JWT claims set {{RFC7519}}, and signature.

The JOSE header MUST contain:

~~~ json
{
  "alg": "EdDSA",
  "typ": "JWT",
  "kid": "did:web:agent.example.com:agents:123#key-1"
}
~~~

`alg` identifies the signing algorithm. Services supporting this document MUST support `EdDSA` {{RFC8032}} and `ES256` and advertise accepted algorithms in `core.signing_algorithms`. Agents MUST select an algorithm advertised by the Service. The `none` algorithm and symmetric JOSE algorithms MUST NOT be used for Agent identity assertions.

`typ` MUST be `JWT`.

`kid` identifies the Agent's DID and MAY include a fragment selecting a verification method in the resolved DID document.

The JWT claims set MUST contain:

~~~ json
{
  "iss": "did:web:agent.example.com:agents:123",
  "sub": "did:web:agent.example.com:agents:123",
  "aud": "did:web:api.example.com",
  "op": "enroll",
  "iat": 1748428800,
  "exp": 1748428860,
  "jti": "9f8a4d2e-1c3b-4f5e-8b7a-000000000000"
}
~~~

`iss` and `sub` MUST both equal the Agent DID.

`aud` MUST equal the Service DID advertised as `service.did` in the Inspect document.

`op` MUST equal the command being invoked. The values defined by this document are `enroll`, `grant`, `revoke`, and `status`.

`iat` and `exp` are NumericDate values as defined by JWT {{RFC7519}}: seconds since the Unix epoch represented as JSON numbers. These claims are an exception to AEP-owned JSON payload numeric-string encoding. Services MUST reject assertions where `exp - iat` is greater than 300 seconds. Services SHOULD allow no more than 30 seconds of local clock skew.

`jti` MUST be freshly generated for each assertion. Services MUST maintain a replay cache keyed by at least `(sub, jti)` for the assertion lifetime plus the accepted clock-skew window.

To verify a client assertion, the Service MUST:

1. Parse the JWT header, claims set, and signature.
2. Reject the assertion if `alg` is not advertised by the Service or is prohibited by this document.
3. Resolve the DID identified by `kid`.
4. Select the referenced verification method.
5. Verify the JWS signature.
6. Verify `iss`, `sub`, `aud`, `op`, `iat`, `exp`, and `jti` according to this section.

Any verification failure MUST use the common `not_recognized` error defined in this document's error handling section.

# The Inspect Command

Inspect is the unauthenticated discovery command. An Agent invokes Inspect by fetching the Service's well-known AEP document:

~~~ http-message
GET /.well-known/aep HTTP/1.1
Host: example.com
Accept: application/aep+json
~~~

The Service returns `200 OK` with an `application/aep+json` body containing the Inspect document described in this document. Inspect has no request body and no client assertion.

Agents SHOULD cache Inspect documents according to the Service's HTTP cache metadata. Agents MUST re-fetch the Inspect document before invoking a command if the cached document has expired.

# The Enroll Command

Enroll registers an Agent DID with a Service. The request uses the baseline client assertion with `op` equal to `enroll`.

Endpoint:

~~~ http-message
POST /aep/enroll HTTP/1.1
Host: example.com
Content-Type: application/aep+json
Authorization: AEP <jwt>
Idempotency-Key: <opaque>
~~~

Request body:

~~~ json
{
  "agent_did": "did:web:agent.example.com:agents:123",
  "claims": {
    "contact.email": "ops@example.com"
  },
  "idempotency_key": "9f8a4d2e-1c3b-4f5e-8b7a-000000000000"
}
~~~

`agent_did` MUST equal the Agent DID in the client assertion `iss`, `sub`, and `kid` values, ignoring any `kid` fragment. The DID method MUST be accepted by the Service's `identity.methods` advertisement.

`claims` carries claim values requested by the Service's Inspect document. This document does not define a complete claim catalog. Claim names are strings and claim values are JSON values. Services MUST ignore unknown claims unless local policy requires rejection.

`idempotency_key` is an opaque retry key. When both the HTTP `Idempotency-Key` header and body field are present, they MUST contain the same value.

Successful Enroll responses use `200 OK`. A synchronous enrollment returns:

~~~ json
{
  "status": "active"
}
~~~

If enrollment requires asynchronous verification, the Service returns:

~~~ json
{
  "owner_action_required": "false",
  "status": "pending",
  "verification_pending": ["contact.email"]
}
~~~

The Agent polls Status to learn whether a pending enrollment has become `active` or `rejected`.

# The Status Command

Status returns the Service's current state for the authenticated Agent identity. The request uses the baseline client assertion with `op` equal to `status`, or a session credential when a concrete session-credential document allows it.

Endpoint:

~~~ http-message
GET /aep/status HTTP/1.1
Host: example.com
Authorization: AEP <jwt>
~~~

Status has no request body.

Successful Status responses use `200 OK`:

~~~ json
{
  "owner_action_required": "false",
  "requirements_pending": [],
  "since": "2026-05-28T12:00:00Z",
  "status": "active"
}
~~~

`status` describes the Agent identity's state at the Service:

| Value | Meaning |
|---|---|
| `active` | The identity is enrolled and operational. |
| `pending` | Enrollment is awaiting asynchronous verification. |
| `unavailable` | The identity is temporarily unavailable for Service-defined non-punitive reasons. |
| `suspended` | The identity is temporarily disabled by Service action. |
| `terminated` | The identity is permanently de-registered. |
| `rejected` | Asynchronous verification failed. |

`since` is the RFC 3339 {{RFC3339}} timestamp of the last state transition.

`requirements_pending` lists claim names the Agent should provide to satisfy current Service requirements.

`owner_action_required` is a JSON string boolean. A value of `"true"` indicates that the Agent's Owner must complete an out-of-band action before the identity can become or remain active.

# The Grant Command

Grant exchanges a baseline client assertion for a session credential. The request uses the baseline client assertion with `op` equal to `grant`. A session credential MUST NOT be used to authenticate Grant.

Endpoint:

~~~ http-message
POST /aep/grant HTTP/1.1
Host: example.com
Content-Type: application/aep+json
Authorization: AEP <jwt>
Idempotency-Key: <opaque>
~~~

Request body:

~~~ json
{
  "grant_type": "oauth-bearer"
}
~~~

`grant_type` MUST be one of the values advertised in `commands.grant_types`. Concrete session-credential documents MAY define additional request fields.

The successful response body is defined by the concrete session-credential document. This core document requires only that the response be a JSON object and that the selected document define credential presentation, expiry semantics, and revocation behavior.

# The Revoke Command

Revoke invalidates session credentials previously issued by Grant. The request uses the baseline client assertion with `op` equal to `revoke`. A session credential MUST NOT be used to authenticate Revoke.

Endpoint:

~~~ http-message
POST /aep/revoke HTTP/1.1
Host: example.com
Content-Type: application/aep+json
Authorization: AEP <jwt>
Idempotency-Key: <opaque>
~~~

Request body:

~~~ json
{
  "grant_type": "oauth-bearer"
}
~~~

`grant_type` MUST be one of the values advertised in `commands.grant_types`. By default, Revoke targets all credentials of that grant type issued to the authenticated Agent. Concrete session-credential documents MAY define additional fields for narrower credential targeting.

To revoke all session credentials of every grant type issued to the authenticated Agent, the request body is:

~~~ json
{
  "all_grant_types": "true"
}
~~~

`all_grant_types` is a string boolean. When `all_grant_types` is `"true"`, the request MUST NOT contain `grant_type` or `credential_id`. A Service that supports Revoke MUST support `all_grant_types` so an Agent can invalidate all issued session credentials without discovering or iterating over every concrete grant type.

Successful Revoke responses use `200 OK` and an empty JSON object:

~~~ json
{}
~~~

The Service MUST return success regardless of whether any matching credentials existed.

# Idempotency

POST commands are state-mutating and MUST support safe retry with the `Idempotency-Key` HTTP header. This requirement applies to Enroll, Grant, and Revoke in this document.

Services MUST cache the response associated with `(agent_did, Idempotency-Key)` for at least 1 hour. If a request repeats the same key with the same authenticated Agent and the same request body, the Service MUST return the cached response or an equivalent successful response.

If the same authenticated Agent reuses an idempotency key with a different request body, the Service MUST return `409 Conflict` with `code` equal to `idempotency_conflict`.

The Enroll request body MAY also contain `idempotency_key` for bindings or application frameworks that persist idempotency metadata with the body. When both forms are present, they MUST match.

# Error Handling

The HTTP binding uses RFC 9457 Problem Details {{RFC9457}} with an AEP `code` field.

~~~ http-message
HTTP/1.1 401 Unauthorized
Content-Type: application/problem+json
WWW-Authenticate: AEP reason="not_recognized"
~~~

~~~ json
{
  "code": "not_recognized",
  "status": 401,
  "type": "https://aep.example/errors/not_recognized"
}
~~~

The `code` field is the canonical machine-readable AEP error code. `type` SHOULD identify stable documentation for the error class. `title` MAY be omitted from production responses.

This document defines the following HTTP error codes:

| AEP code | HTTP status | Meaning |
|---|---:|---|
| `enrollment_failed` | 400 | Generic enrollment failure where the Service suppresses precise detail. |
| `not_recognized` | 401 | Umbrella anti-enumeration error for failed identity, signature, audience, operation, replay, time-window, archived-identity, or unsupported-method checks. |
| `identity_suspended` | 403 | The recognized identity is temporarily disabled by Service action. |
| `identity_terminated` | 403 | The recognized identity is permanently de-registered. |
| `identity_unavailable` | 403 | The recognized identity is temporarily unavailable for Service-defined reasons. |
| `requirements_unmet` | 422 | Required claims are missing or invalid. |
| `verification_pending` | 403 | Enrollment or required verification has not completed. |
| `verification_timeout` | 422 | Required asynchronous verification did not complete in the Service's policy window. |
| `rate_limited` | 429 | The Agent exceeded a Service rate limit. |
| `unsupported_grant_type` | 400 | Grant or Revoke requested a `grant_type` not advertised by the Service. |
| `idempotency_conflict` | 409 | An idempotency key was reused with a different request body. |

Services MUST use `not_recognized` for bad signatures, unknown Agent identities, wrong `aud`, wrong `op`, replayed `jti`, time-window violations, archived identities, unsupported identity methods during authenticated contact, and unknown or revoked session credentials. Services MUST NOT reveal which of these checks failed.

Services MUST implement constant-time-shaped response behavior for `not_recognized` paths so that observable latency does not distinguish a known Agent from an unknown Agent or a validly formatted assertion from a bad signature.

When a request fails for multiple reasons, the Service MUST choose the least revealing error. For example, a request with both a bad signature and missing claims returns `not_recognized`, not `requirements_unmet`.

# Extensibility

This document defines the extension points needed by the core protocol:

* `extensions.supported` advertises extension identifiers implemented by the Service.
* `commands.grant_types` advertises concrete session-credential formats available through Grant and Revoke.
* `commands.grant_types_config` MAY carry per-grant-type configuration defined by a concrete session-credential document.
* `claims.required`, `claims.preferred`, and `claims.optional` MAY contain claim names defined by other documents.
* Additional top-level Inspect fields MAY be added by future documents.

Agents MUST ignore extension identifiers and additive fields they do not understand, unless local policy requires the Agent to refuse enrollment when a required capability is absent.

Services MUST NOT redefine the semantics of commands, fields, status values, or error codes defined by this document. Extensions are additive.

Concrete session-credential documents MUST define:

1. The `grant_type` string.
2. Grant request fields beyond `grant_type`, if any.
3. Grant response shape.
4. Credential presentation on HTTP requests.
5. Expiry semantics.
6. Revoke request fields beyond `grant_type` and `all_grant_types`, if any.
7. Error behavior beyond the core errors, if any.

# IANA Considerations

This section requests registrations and registry creation following RFC 8126 {{RFC8126}}.

## HTTP Authentication Scheme

IANA is requested to register the following HTTP authentication scheme in the "HTTP Authentication Schemes" registry:

| Field | Value |
|---|---|
| Authentication Scheme Name | `AEP` |
| Reference | This document |
| Notes | Agent Enrollment Protocol client assertion authentication |

## Well-Known URI

IANA is requested to register the following URI suffix in the "Well-Known URIs" registry:

| Field | Value |
|---|---|
| URI Suffix | `aep` |
| Change Controller | IETF |
| Reference | This document |
| Related Information | Agent Enrollment Protocol Inspect document |

## Media Type

IANA is requested to register the following media type in the "Media Types" registry:

| Field | Value |
|---|---|
| Type name | `application` |
| Subtype name | `aep+json` |
| Required parameters | None |
| Optional parameters | None |
| Encoding considerations | Same as JSON {{RFC8259}} |
| Security considerations | See the Security Considerations section of this document |
| Interoperability considerations | None |
| Published specification | This document |
| Applications that use this media type | Services and Agents implementing AEP |
| Fragment identifier considerations | Same as JSON {{RFC8259}} |
| Additional information | None |
| Person and email address to contact for further information | IETF <iesg@ietf.org> |
| Intended usage | COMMON |
| Restrictions on usage | None |
| Author | IETF |
| Change controller | IETF |

## AEP Command Registry

IANA is requested to create an "AEP Commands" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new command registrations define command semantics, authentication requirements, request and response shapes, idempotency behavior for state-mutating commands, and error behavior.

Each entry contains:

| Field | Description |
|---|---|
| Command | Lowercase wire identifier. |
| Description | Short command description. |
| Reference | Stable specification reference. |

Initial entries are:

| Command | Description | Reference |
|---|---|---|
| `inspect` | Discover Service AEP capabilities. | This document |
| `enroll` | Register an Agent identity with a Service. | This document |
| `status` | Query the Agent identity's current state. | This document |
| `grant` | Issue a session credential. | This document |
| `revoke` | Revoke session credentials. | This document |

## AEP Error Code Registry

IANA is requested to create an "AEP Error Codes" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new error codes are binding-independent, use `lower_snake_case`, avoid exposing identity-enumeration detail, and define default HTTP status mapping and remediation behavior.

Each entry contains:

| Field | Description |
|---|---|
| Code | Lowercase `lower_snake_case` error code. |
| HTTP Status | Default HTTP status code. |
| Description | Short error description. |
| Reference | Stable specification reference. |

Initial entries are:

| Code | HTTP Status | Description | Reference |
|---|---:|---|---|
| `enrollment_failed` | 400 | Generic enrollment failure. | This document |
| `not_recognized` | 401 | Anti-enumeration recognition failure. | This document |
| `identity_suspended` | 403 | Recognized identity is suspended. | This document |
| `identity_terminated` | 403 | Recognized identity is terminated. | This document |
| `identity_unavailable` | 403 | Recognized identity is temporarily unavailable. | This document |
| `requirements_unmet` | 422 | Required claims are missing or invalid. | This document |
| `verification_pending` | 403 | Verification has not completed. | This document |
| `verification_timeout` | 422 | Verification did not complete in time. | This document |
| `rate_limited` | 429 | Rate limit exceeded. | This document |
| `unsupported_grant_type` | 400 | Unsupported Grant or Revoke grant type. | This document |
| `idempotency_conflict` | 409 | Idempotency key reused with a different request body. | This document |

## AEP Grant Type Registry

IANA is requested to create an "AEP Grant Types" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new grant type registrations define the Grant request fields, Grant response shape, credential presentation syntax, expiry semantics, Revoke behavior, and security considerations for credential storage and leakage.

Each entry contains:

| Field | Description |
|---|---|
| Grant Type | Lowercase wire identifier. |
| Description | Short credential description. |
| Reference | Stable specification reference. |

This document creates the registry but does not register concrete grant types. OAuth Bearer, API-key, and Basic session credentials are defined by separate documents.

# Security Considerations

Network use of the HTTP binding defined by this document requires TLS 1.3 or later. Plaintext HTTP is out of scope.

Client assertions are replay resistant only when Services validate the full chain: `aud`, `op`, `jti`, `iat`, and `exp`. `aud` binds the assertion to the Service DID. `op` binds the assertion to a command. `jti` prevents in-window duplicate use. `iat` and `exp` bound the usable time window. Services that skip any of these checks weaken the authentication model.

Services SHOULD keep assertion lifetimes short. This document sets a maximum validity interval of 300 seconds. Services MAY enforce a shorter maximum.

The `did:web` method relies on the HTTPS origin that publishes the DID document. A Service that accepts an Agent's `did:web` identity trusts the corresponding web origin to publish the correct verification method. Services SHOULD cache DID documents for operational stability but MUST ensure that cache lifetimes do not prevent timely key replacement after compromise.

The `core.signing_algorithms` advertisement is security relevant. Services MUST NOT advertise algorithms they do not intend to accept, and MUST NOT accept algorithms that were not advertised. Agents MUST NOT use `none` or symmetric JOSE algorithms for Agent identity assertions. Implementations SHOULD follow JWT best current practices {{RFC8725}}.

Authentication failures are an enumeration risk. Services MUST collapse recognition failures to `not_recognized` and MUST shape timing so attackers cannot distinguish an unknown Agent, a bad signature, a wrong audience, a wrong operation, a replay, an expired assertion, or an archived identity.

Grant issues session credentials that may be bearer credentials depending on the concrete session-credential document. Services and Agents MUST treat returned credentials as secrets. Concrete session-credential documents MUST define credential lifetime, presentation, storage guidance, and revocation semantics. Revoke MUST be available for every advertised grant type.

If a session credential is stolen, an attacker may impersonate the Agent until the credential expires or is revoked. Agents that suspect compromise can authenticate with the baseline client assertion and invoke Revoke for the affected grant type.

Services SHOULD rate-limit Inspect, Enroll, Grant, Revoke, and Status to reduce probing and credential-issuance abuse. Rate limits MUST NOT create distinguishable recognition errors that defeat the anti-enumeration rules above.

# Privacy Considerations

AEP exposes Agent identity and claims to Services. Agents and Services should minimize disclosure by using the Inspect document as the negotiation surface: Services list required, preferred, and optional claims; Agents provide the minimum set needed for the intended interaction.

Services SHOULD keep `claims.required` limited to data required for enrollment or legal operation. Over-declaring required claims increases privacy risk and reduces interoperability.

Agents SHOULD avoid sending claims absent from `claims.required`, `claims.preferred`, or `claims.optional`. Services MUST ignore unknown claims unless local policy requires rejection.

A `did:web` Agent identity can be correlatable if the same DID is reused across Services. Platforms or Agent operators that require unlinkability SHOULD use a distinct `did:web` URI and signing key per Service enrollment. The URI path component SHOULD be opaque and SHOULD NOT reveal the Agent's master identity, account identifier, or target Service.

Services SHOULD maintain a Service-local pairwise identifier for enrolled Agents rather than using the Agent DID as the primary internal record key across all contexts. Such identifiers SHOULD be opaque and MUST NOT be disclosed as cross-Service correlators.

Platform-hosted Agent identities introduce Platform-level visibility: the Platform can observe or reconstruct which Services an Agent enrolls with. This document does not prevent that visibility. Agents with stronger privacy requirements should account for the Platform trust relationship before using a Platform-hosted `did:web` identity.

Session credentials can become correlation handles when reused outside the issuing Service or logged by intermediaries. Concrete session-credential documents MUST define presentation rules that avoid unnecessary disclosure and MUST prohibit logging raw credential values.

Inspect documents may disclose Service policy and capability information to unauthenticated readers. Services SHOULD avoid publishing sensitive operational details in Inspect beyond what Agents need for interoperability.
