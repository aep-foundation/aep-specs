---
title: "AEP Platform Hosted Identity"
abbrev: "AEP Platform"
docname: draft-kavian-aep-platform-hosted-identity-00
date: 2026-07-23
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
    email: nas@inflowpay.ai

normative:
  RFC8259:
  RFC9110:
  RFC8615:
  AEP-CORE:
    title: "The Agent Enrollment Protocol"
    target: https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/
    date: 2026-06-27
    seriesinfo:
      Internet-Draft: draft-kavian-agent-enrollment-protocol-02
    author:
      - ins: N. Kavian
        name: N. Kavian
  AEP-DID-WEB:
    title: "did:web Identity Method for the Agent Enrollment Protocol"
    target: https://datatracker.ietf.org/doc/draft-kavian-aep-did-web-identity-method/
    date: 2026-06-27
    seriesinfo:
      Internet-Draft: draft-kavian-aep-did-web-identity-method-00
    author:
      - ins: N. Kavian
        name: N. Kavian

informative:
...

--- abstract

This document defines interoperable hosted identity behavior for Agent
Enrollment Protocol (AEP) Platforms. It lets a Platform provision
Service-scoped Agent `did:web` identities, publish DID documents, custody
signing keys, and produce AEP client assertion JWTs through delegated signing
operations.

--- middle

# Introduction

The Agent Enrollment Protocol defines how an Agent enrolls and authenticates
with a Service. The AEP core also names Platform as a role that can host Agent
identity material, but it does not define an interoperable Platform API.

This document defines AEP Platform Hosted Identity. A conforming Platform
provisions an Agent identity that is scoped to a supplied Service DID, publishes
the Agent DID document, and signs AEP client assertions for the Agent. The
Agent presents those assertions to the Service. The Service verifies the
assertion locally by resolving the Agent DID and applying AEP core verification
rules.

This specification does not make the Platform a Service. Service Inspect,
Enroll, Status, Grant, and Revoke remain Service endpoints defined by AEP core.
The Platform endpoints defined here help an Agent obtain and operate the
Service-scoped Agent identity that it uses with those Service endpoints.

This specification does not define verifier orchestration, attestation
issuance, Owner recovery procedures, private-key import, or private-key export.
Those functions can be implemented by a Platform, but they are separate from
the hosted identity API defined here.

# Requirements Language

{::boilerplate bcp14-tagged}

# Terminology

This document uses the Agent, Service, Platform, Owner, DID, and client
assertion terms from AEP core {{AEP-CORE}}. JSON values are encoded as
described by {{RFC8259}}. `did:web` resolution follows {{AEP-DID-WEB}}.

Service-Scoped Agent DID:
: A `did:web` identifier minted by a Platform for one Agent to use with one
  supplied Service DID. The identifier is opaque outside the Platform and is not
  reused across unrelated Services.

Platform Discovery:
: A well-known JSON document that describes Platform API endpoint locations,
  supported algorithms, DID publication templates, hosted verification support,
  and key custody guarantees.

Delegated Signing:
: A Platform operation that signs an AEP client assertion JWT for a managed
  Service-scoped Agent DID without returning private signing material.

# Hosted Identity Overview

A Platform implementation follows this sequence:

1. Publish Platform Discovery at `/.well-known/aep-platform`.
2. Accept an authenticated provisioning request that names a target
   `service_did`.
3. Mint or return a Service-scoped Agent DID for the authenticated Agent and
   target Service DID.
4. Publish a DID document for that Agent DID.
5. Accept delegated signing requests for that Agent DID and target Service DID.
6. Return signed AEP client assertion JWTs that can be verified by the target
   Service using AEP core and the Agent DID document.

# Role And Trust Boundaries

A Platform is not on the Service-facing AEP command path. An Agent uses the
Platform API to obtain and operate a Service-scoped Agent DID, then uses AEP
core commands directly with the Service. Services verify client assertions by
resolving the Agent DID and applying AEP core verification rules.

A Service MUST NOT require use of the hosted verification endpoint defined by
this document as a condition of accepting an otherwise valid AEP client
assertion. Hosted verification is optional and requires a separate
out-of-band trust relationship between the caller and the Platform.

A legal entity that operates both a Service and a Platform MUST keep those roles
logically separate. If both roles publish DIDs, the Service DID and Platform DID
MUST be distinct, and Service-role records MUST remain independent from
Platform-role identity records.

# Platform Discovery

A Platform that implements this specification MUST publish a discovery
document at `/.well-known/aep-platform` on the HTTPS origin used for Platform
APIs. The response media type is `application/aep+json`. HTTP semantics follow
{{RFC9110}}.

The discovery document has this structure:

~~~ json
{
  "aep_version": "1.0",
  "platform": {
    "did": "did:web:p.example",
    "hosted_verification": true,
    "name": "Example Platform"
  },
  "http": {
    "endpoint_base": "/v1/aep"
  },
  "identity": {
    "did_methods": ["did:web"],
    "did_url_template": "https://p.example/a/{agent_did_id}/did.json"
  },
  "signing": {
    "algorithms": ["ES256"],
    "default_lifetime_seconds": "300"
  },
  "endpoints": {
    "hosted_verification": "/v1/aep/verifications",
    "lifecycle": "/v1/aep/agent-identities/{agent_identity_id}",
    "list": "/v1/aep/agent-identities",
    "provision": "/v1/aep/agent-identities",
    "sign": "/v1/aep/agent-identities/{agent_identity_id}/sign"
  }
}
~~~

`platform.did` is OPTIONAL. If present, it MUST be a DID controlled by the
Platform. `identity.did_url_template` MUST describe where the Platform publishes
Service-scoped Agent DID documents. `signing.algorithms` lists the JOSE signing
algorithms the Platform can use for delegated signing. Values MUST be AEP core
signing algorithms or algorithms defined by registered extensions.

`signing.default_lifetime_seconds` is the default lifetime, in seconds, for
delegated client assertions when a signing request does not include
`lifetime_seconds`. This field is an AEP-owned numeric value and is therefore
represented as a JSON string. The Platform MUST enforce the AEP core maximum
assertion validity interval of 300 seconds. A Platform MAY enforce a shorter
local maximum.

Platforms SHOULD send `Cache-Control`, `ETag`, and `Last-Modified` metadata on Discovery responses. Agents MUST honor usable freshness, validators, conditional requests, and `304 Not Modified`. `no-cache` requires revalidation and `no-store` prohibits persistence or reuse beyond the current fetch. When no shorter usable freshness policy is supplied, Agents SHOULD use 300 seconds. Cache keys use the advertised Discovery URL and MUST track the final URL after an accepted safe redirect. Discovery redirects MUST remain HTTPS, MUST NOT contain user information, and MUST satisfy implementation redirect, byte, and completion-time bounds.

# Provisioning

Provisioning creates or retrieves a Service-scoped Agent DID for an
authenticated Platform API caller acting for an Agent or Owner. Platform API
caller authentication is out of scope for this document, but the Platform MUST
authenticate and authorize the caller before processing the request. The
provisioning endpoint is relative to `http.endpoint_base` and is advertised by
`endpoints.provision`.

The request body is:

~~~ json
{
  "service_did": "did:web:api.service.example"
}
~~~

Provisioning uses `POST` and MUST carry a non-empty `Idempotency-Key` header.

The Platform MUST validate that `service_did` is syntactically a DID. For
`did:web`, the Platform MUST resolve the DID before first delegated signing
unless local policy explicitly permits deferred resolution.

The Platform MUST mint a distinct Agent DID for each unrelated `service_did`
used by the same Agent. The DID path component MUST be opaque to external
observers and MUST NOT reveal the Agent, Owner, tenant, account, target
Service, or derivation inputs. A Platform MUST NOT reuse one public Agent DID
across unrelated Services unless explicit Owner policy requires reuse.

An observer comparing two Service-scoped Agent DIDs for the same Agent at
different Services MUST see no common structure beyond the Platform-controlled
origin or DID method prefix. A Platform MAY derive Service-scoped Agent DID
identifiers using a Platform-secret keyed derivation over internal Agent and
Service identifiers, but the derivation inputs and key material MUST NOT be
disclosed.

A successful response is:

~~~ json
{
  "agent_identity_id": "pai_01J0AEPPLATFORM000000000001",
  "agent_did": "did:web:p.example:a:4Yf7p2xQd9",
  "created_at": "2026-07-06T12:00:00Z",
  "did_document_url": "https://p.example/a/4Yf7p2xQd9/did.json",
  "key_id": "did:web:p.example:a:4Yf7p2xQd9",
  "service_did": "did:web:api.service.example",
  "signing_algorithms": ["ES256"],
  "status": "active",
  "updated_at": "2026-07-06T12:00:00Z"
}
~~~

The Platform MUST return the same response for an exact replay as defined in
the Platform Idempotency section.

# Listing Agent Identities

The Platform MUST expose a listing endpoint for the authenticated caller's
Service-scoped Agent identities. The listing endpoint is relative to
`http.endpoint_base` and is advertised by `endpoints.list`.

The listing endpoint uses `GET` and MUST support these optional query
parameters:

| Query parameter | Meaning                                                                                      |
| --------------- | -------------------------------------------------------------------------------------------- |
| `descending`    | Return records in descending creation order when `true`; otherwise ascending creation order. |
| `limit`         | Maximum number of records to return.                                                         |
| `offset`        | Number of matching records to skip before returning data.                                    |
| `service_did`   | Return only identities scoped to this Service DID.                                           |
| `status`        | Return only identities in this lifecycle state.                                              |

The Platform MUST apply deterministic ordering before applying `offset` and
`limit`. Unless a Platform publishes a stronger ordering contract, ordering is
by creation time and then by a stable Platform-local identifier. The Platform
SHOULD bound `limit` to protect service availability.

A successful response is:

~~~ json
{
  "count": "1",
  "data": [
    {
      "agent_identity_id": "pai_01J0AEPPLATFORM000000000001",
      "agent_did": "did:web:p.example:a:4Yf7p2xQd9",
      "created_at": "2026-07-06T12:00:00Z",
      "did_document_url": "https://p.example/a/4Yf7p2xQd9/did.json",
      "key_id": "did:web:p.example:a:4Yf7p2xQd9",
      "service_did": "did:web:api.service.example",
      "signing_algorithms": ["ES256"],
      "status": "active",
      "updated_at": "2026-07-06T12:00:00Z"
    }
  ],
  "total": "1"
}
~~~

The Platform MUST only return Agent identities the authenticated caller is
authorized to inspect. `count` is the number of records in `data`. `total` is
the total number of records matching the query before `offset` and `limit` are
applied. Both fields are AEP-owned numeric values and are therefore represented
as JSON strings containing non-negative integers.

An Agent MAY use the listing endpoint with `service_did` to recover a missing
local reference to a Platform-hosted Agent identity. The presence of an identity
in the Platform proves that the identity was provisioned; it does not prove that
the Service currently recognizes the identity. The Agent uses the Service Status
command to determine the Service enrollment lifecycle state.

# DID Document Publication

The Platform MUST publish a DID document for each active Service-scoped Agent
DID. The DID document MUST contain public verification material suitable for
AEP client assertion verification by the target Service.

The Platform SHOULD use an opaque path component that does not reveal the
Agent, Owner, tenant, account, or target Service DID.

The Platform MUST maintain an internal mapping from the authenticated Agent or
Owner account and target Service DID to the Service-scoped Agent DID. A Service
does not need to know that the DID is Service-scoped and MUST be able to verify
the DID as an ordinary `did:web` Agent DID.

# Delegated Signing

Delegated signing produces an AEP client assertion JWT for an Agent identity
managed by the Platform. The signing endpoint is relative to `http.endpoint_base`
and is advertised by `endpoints.sign`.

The request body is:

~~~ json
{
  "jti": "01J0AEPASSERTION0000000001",
  "lifetime_seconds": "300",
  "op": "enroll",
  "platform_context": {"authorization_handle": "opaque-value"},
  "service_did": "did:web:api.service.example"
}
~~~

Delegated signing uses `POST` and MUST carry a non-empty `Idempotency-Key`
header. `platform_context` is an optional, free-form JSON object whose members
are defined by Platform policy or a Platform profile. It is Platform-local
authorization or custody input. It MUST NOT be copied into client-assertion
claims, included in assertion signature inputs, or otherwise alter the
assertion semantics defined by AEP core. When returned, it remains opaque to
the Agent and SHOULD be transported unchanged.

The Platform MUST authenticate the caller and verify that the caller is
authorized to sign for the requested Agent identity and `service_did`. The
Platform MUST reject signing requests for inactive, suspended, terminated, or
revoked Agent identities.

If `lifetime_seconds` is present, it MUST be a string-encoded positive integer
and MUST NOT exceed 300 seconds. If `lifetime_seconds` is omitted, the Platform
uses `signing.default_lifetime_seconds`. The effective lifetime MUST NOT exceed
300 seconds. A Platform MAY reject values above a shorter local maximum.

When `op` is `authenticate`, the request MUST include `resource` with the absolute HTTPS protected-resource URI and the Platform MUST include that value in the assertion. For every other operation, `resource` MUST be absent.

A completed response uses `200 OK`:

~~~ json
{
  "agent_did": "did:web:p.example:a:4Yf7p2xQd9",
  "client_assertion": "eyJhbGciOiJFUzI1NiIsImtpZCI6Ii4uLiJ9...",
  "expires_at": "2026-07-06T12:05:00Z",
  "issued_at": "2026-07-06T12:00:00Z",
  "jti": "01J0AEPASSERTION0000000001",
  "platform_context": {"authorization_handle": "opaque-value"},
  "service_did": "did:web:api.service.example",
  "status": "completed"
}
~~~

When signing has not completed, the Platform returns `202 Accepted`:

~~~ json
{
  "platform_context": {"authorization_handle": "opaque-value"},
  "retry_after_seconds": "5",
  "status": "pending"
}
~~~

`retry_after_seconds` is required on a pending response and is a decimal string
from `"1"` through `"300"`. It controls polling cadence, not the total operation
deadline. The Platform MUST NOT send `Retry-After` for this contract. A pending
or completed response MAY contain `platform_context`; it SHOULD be omitted when
there is no context to return.

The JWT claims MUST satisfy AEP core client assertion requirements. The `iss`
and `sub` claims MUST be the Service-scoped Agent DID. The `aud` claim MUST be
the target Service DID. The `op` claim MUST be the AEP operation for which the
assertion is intended. For Platform-hosted `did:web` identities, the JOSE `kid`
header MUST identify the Service-scoped Agent DID carried in `key_id`. Platform
Hosted Identity does not use DID verification-method fragments such as
`#key-1`.

The Platform MUST apply an explicitly registered signing policy to every `op`.
The operations defined by AEP core are `enroll`, `grant`, `revoke`, `status`,
and `authenticate`; Inspect is unauthenticated and does not use delegated signing. An
unrecognized operation, or an operation for which the Platform has no policy,
MUST fail closed and MUST NOT produce an assertion. Extensions MAY register
additional operation policies without redefining Inspect as permanently
unsigned.

# Lifecycle

The Platform MUST expose lifecycle state for each managed Agent identity. This
specification defines these states:

| State        | Meaning                                                  |
| ------------ | -------------------------------------------------------- |
| `active`     | The identity can publish DID documents and sign.         |
| `revoked`    | The identity is permanently revoked and cannot sign.     |
| `suspended`  | The identity is temporarily blocked from signing.        |
| `terminated` | The identity is permanently terminated by Platform rule. |

State names are lowercase ASCII strings. A Platform MUST NOT sign for
`revoked`, `suspended`, or `terminated` identities.

Key rotation changes verification material or key references; it is not a
Platform lifecycle state. This document does not define Platform key rotation
behavior or a key-rotation endpoint. Rotation of Agent-controlled key material
is performed by Agent-side tooling or a separate identity-management surface,
not by the Platform API defined here. Services continue to verify the resulting
DID document according to AEP core and the `did:web` identity method.

The lifecycle endpoint is relative to `http.endpoint_base` and is advertised by
`endpoints.lifecycle`. The endpoint identifies one Platform-local Agent identity
with an `{agent_identity_id}` path parameter. The Platform MUST authenticate the
caller and verify that the caller is authorized to inspect or modify that Agent
identity before returning state or changing state.

The Platform MUST support `GET` on the lifecycle endpoint to return the Agent
identity object described in the Provisioning section.

The Platform MUST support `PATCH` on the lifecycle endpoint to update the
identity lifecycle state. The request body is:

~~~ json
{
  "status": "suspended"
}
~~~

A successful `PATCH` response is the updated Agent identity object:

~~~ json
{
  "agent_identity_id": "pai_01J0AEPPLATFORM000000000001",
  "agent_did": "did:web:p.example:a:4Yf7p2xQd9",
  "created_at": "2026-07-06T12:00:00Z",
  "did_document_url": "https://p.example/a/4Yf7p2xQd9/did.json",
  "key_id": "did:web:p.example:a:4Yf7p2xQd9",
  "service_did": "did:web:api.service.example",
  "signing_algorithms": ["ES256"],
  "status": "suspended",
  "updated_at": "2026-07-06T12:10:00Z"
}
~~~

This specification defines the state values that are carried on the wire. It
does not define a universal state-transition graph. A Platform defines its own
permitted transitions according to policy, custody model, and compliance
requirements.

# Hosted Verification

Hosted verification is OPTIONAL. If supported, the Platform advertises the
endpoint in `endpoints.hosted_verification` and sets
`platform.hosted_verification` to `true`.

Hosted verification does not replace local Service verification. A Service can
verify a client assertion locally by resolving the Agent DID and applying AEP
core verification rules. A Service MUST NOT require hosted verification as a
condition of accepting otherwise valid AEP client assertions. Hosted
verification is an optional convenience API for deployments that have an
out-of-band trust relationship with the Platform.

The hosted verification endpoint uses `POST` and MUST carry a non-empty
`Idempotency-Key` header. The request body is:

~~~ json
{
  "client_assertion": "eyJhbGciOiJFUzI1NiIsImtpZCI6Ii4uLiJ9...",
  "op": "enroll",
  "service_did": "did:web:api.service.example"
}
~~~

The Platform MUST verify the assertion signature, time bounds, `jti` replay
status, `op`, `aud`, `iss`, `sub`, and the current lifecycle state of the
managed Agent identity. The Platform MUST reject assertion replay according to
the same replay policy it applies to local delegated-signing audit records.

For `authenticate`, the hosted verification request MUST include `resource`, and the Platform MUST verify that it equals the assertion claim and intended protected-resource target. For other operations, `resource` MUST be absent.

A successful response for a recognized assertion is:

~~~ json
{
  "agent_did": "did:web:p.example:a:4Yf7p2xQd9",
  "agent_identity_id": "pai_01J0AEPPLATFORM000000000001",
  "op": "enroll",
  "reason": "verified",
  "service_did": "did:web:api.service.example",
  "status": "active",
  "verified": true
}
~~~

A response for an assertion the Platform cannot recognize or validate is:

~~~ json
{
  "reason": "not_recognized",
  "service_did": "did:web:api.service.example",
  "verified": false
}
~~~

Hosted verification responses MUST NOT disclose whether a private Agent,
Owner, tenant, Service-scoped identity, or signing record exists unless the
request is authorized to learn that fact. A Platform MAY return a generic
unrecognized response instead of identity-specific failure detail when revealing
the distinction would create an enumeration risk.

# Platform Idempotency

Provisioning, delegated signing, and hosted verification MUST support safe
retry through the `Idempotency-Key` HTTP header. Listing and lifecycle `GET`
requests do not use this header. Lifecycle `PATCH` remains naturally idempotent
while it only requests a target state.

The Platform MUST scope idempotency lookup by a stable authenticated principal,
including tenant scope where necessary, plus the key. It MUST retain the
complete replayable HTTP result for at least one hour. Exact retries MUST return
the stored result, including pending results. Durable operation invariants MUST
continue to prevent duplicate identities or other unsafe effects after the
retention period expires.

Each record MUST bind the normalized operation and a cryptographic hash of a
canonical representation of material path parameters and request content.
Authentication credentials, transport-only values, the `Idempotency-Key`
itself, and server-generated timestamps MUST be excluded. Reuse by the same
principal for another operation or changed material input MUST return `409
Conflict` with code `idempotency_conflict`.

An initial Sign request and a later completion request have different material
input and therefore MUST use distinct idempotency keys. Retries within either
stage reuse that stage's key.

# Error Handling

Platform endpoints use `application/problem+json` for errors. Implementations
SHOULD reuse AEP core Problem Details shape and error codes where the semantics
match. Problem `type` values SHOULD use the `urn:aep:error:<code>` form defined
by AEP core. Errors MUST NOT disclose whether a private Agent, Owner, tenant,
or Service-scoped identity exists unless the authenticated caller is authorized
to know that fact.

# IANA Considerations

This document requests registration of `aep-platform` in the Well-Known URI
Registry established by {{RFC8615}}.

| Field                  | Value                                        |
| ---------------------- | -------------------------------------------- |
| URI suffix             | `aep-platform`                               |
| Change controller      | AEP Foundation                               |
| Specification document | This document                                |
| Related information    | Agent Enrollment Protocol Platform discovery |

This document does not request creation of an AEP Platform endpoint registry or
an AEP Platform lifecycle-state registry. The endpoint names and lifecycle
state values defined here are closed over this document.

# Security Considerations

The Platform is a high-value key custody system. Platforms MUST
authenticate callers, authorize every provisioning and signing operation, audit
signing operations, rate-limit state-changing endpoints, and protect replay
inputs such as `jti` and `Idempotency-Key`.

Platforms SHOULD use hardware-backed keys for production custody. If an
implementation uses software-encrypted keys, it MUST separate key encryption
keys from encrypted signing-key records and MUST fail closed when production
custody configuration is incomplete.

Platforms MUST NOT return private signing material through the endpoints
defined by this document. Platforms SHOULD expose audit records for delegated
signing operations to the authorized Agent or Owner through an authenticated
management surface.

Platforms MUST NOT import or export private signing material through the
endpoints defined by this document. Recovery of a Platform account, Owner
credential, or Agent management credential is out of scope for this document.

# Privacy Considerations

Service-scoped Agent DIDs reduce cross-Service correlation. Platforms MUST NOT
reuse the same public Agent DID across unrelated Service DIDs unless explicit
Owner policy requires reuse. DID URLs and opaque identifiers SHOULD avoid
embedding account names, tenant names, Service hostnames, or other correlatable
business identifiers.

The Platform itself can correlate all Services for which it has provisioned
Service-scoped Agent DIDs. Agents or Owners that require unlinkability from the
Platform need a self-custody identity model rather than hosted identity.
