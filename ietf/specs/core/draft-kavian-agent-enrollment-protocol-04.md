---
title: "The Agent Enrollment Protocol"
abbrev: "AEP"
docname: draft-kavian-agent-enrollment-protocol-04
date: 2026-08-27
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
  DID-WEB:
    title: "The did:web Method Specification"
    target: https://w3c-ccg.github.io/did-method-web/
    author:
      - org: W3C Credentials Community Group
  RFC3339:
  RFC5234:
  RFC6839:
  RFC7515:
  RFC7518:
  RFC7519:
  RFC8259:
  RFC8037:
  RFC9846:
  RFC8615:
  RFC9110:
  RFC9112:
  RFC9113:
  RFC9114:
  RFC9457:
informative:
  AEP-CLAIMS:
    title: "AEP Claim Values"
    target: https://datatracker.ietf.org/doc/draft-kavian-aep-claims/
    date: 2026-08-24
    seriesinfo:
      Internet-Draft: draft-kavian-aep-claims-01
    author:
      - ins: N. Kavian
        name: N. Kavian
  RFC8126:
  RFC8725:
...

--- abstract

The Agent Enrollment Protocol (AEP) defines an HTTP-based mechanism for autonomous agents to discover service enrollment requirements, enroll an agent identity, obtain optional session credentials, revoke those credentials, and query enrollment status. AEP uses Decentralized Identifiers, client assertion JWTs, and HTTP Problem Details to provide a narrow machine-first enrollment and authentication substrate for agent-to-service interactions.

--- middle

# Introduction

Autonomous agents increasingly interact with internet services without a human directly completing registration forms, email confirmations, password setup, or dashboard-based API-key provisioning. Existing HTTP authentication mechanisms can authenticate an already-provisioned client, but they do not define a machine-first enrollment flow by which an autonomous agent discovers a service's requirements, presents a cryptographic identity, and becomes recognized by that service.

The Agent Enrollment Protocol (AEP) defines that enrollment substrate. AEP lets an Agent discover what a Service requires, enroll a supported identity method, authenticate AEP commands with a per-request client assertion JWT, optionally obtain a session credential, revoke issued session credentials, and query enrollment status.

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
: A JWT signed by the Agent's private key and presented on an authenticated AEP command or protected Service resource. The assertion binds the Agent identity, Service identity, operation, issuance time, expiration time, replay identifier, and, for protected resources, the resource URI.

Session credential:
: A stateful credential issued by the Grant command and presented on later requests according to a separate session-credential specification.

Grant type:
: A string identifier for a concrete session-credential format supported by the Service, such as an OAuth Bearer, API-key, or Basic credential specification.

Authentication method:
: A wire identifier advertised by a Service for authenticating protected resources. `aep-jwt` identifies an AEP client assertion; registered Grant Type identifiers identify session credentials.

# Protocol Overview

The baseline AEP flow is:

1. The Agent fetches the Service's Inspect document.
2. The Agent evaluates whether it can satisfy the Service's identity-method and claim requirements.
3. The Agent constructs a client assertion JWT with `aud` equal to the Service DID and `op` equal to the command being invoked.
4. The Agent invokes Enroll.
5. The Agent calls Status when enrollment is pending or when it needs current state.
6. The Agent may call Grant for a supported session-credential type.
7. The Agent may call Revoke to invalidate issued session credentials.

Inspect is unauthenticated. Every Service that exposes Enroll, Grant, Revoke, or Status MUST accept the baseline `Authorization: AEP <jwt>` form on that command. Session credentials, once issued, MAY additionally be used on commands that allow the selected credential type; Grant and Revoke themselves always use the baseline client assertion. Support for the baseline client assertion on AEP command endpoints does not advertise or imply support for `aep-jwt` on protected application resources.

# Versioning and Compatibility

The `aep_version` member is a JSON string in `MAJOR.MINOR` form. `MAJOR` and `MINOR` are unsigned decimal integers without leading zeroes except for the value `0`. The protocol version defined by this document is `1.0`.

The major version identifies the compatibility family. An implementation MUST reject an Inspect document whose major version it does not support. Minor versions within one major version are backward compatible. A same-major minor revision MAY add optional fields, optional values, optional capabilities, or clarifications that preserve existing wire behavior. It MUST NOT remove or redefine existing wire behavior or make a new capability mandatory for implementations of an earlier minor version.

An implementation supporting a major version MUST process Inspect documents carrying any minor version in that major-version family according to the unknown-field and extension rules in this document. It MUST NOT infer support for an optional command, identity method, authentication method, grant type, binding, or extension from the minor version. The `aep_version` member is the sole protocol-version authority; HTTP media-type parameters do not select or modify the AEP version.

# HTTP Binding

This document defines an HTTP binding using HTTP semantics {{RFC9110}} over HTTP/1.1 {{RFC9112}}, HTTP/2 {{RFC9113}}, or HTTP/3 {{RFC9114}}. Network use of this binding requires TLS 1.3 or later {{RFC9846}}. Plaintext HTTP is out of scope.

The binding uses only `GET` and `POST`:

| Command | Method | Endpoint                             |
| ------- | ------ | ------------------------------------ |
| Inspect | `GET`  | `/.well-known/aep`                   |
| Enroll  | `POST` | `enroll` relative to `endpoint_base` |
| Status  | `GET`  | `status` relative to `endpoint_base` |
| Grant   | `POST` | `grant` relative to `endpoint_base`  |
| Revoke  | `POST` | `revoke` relative to `endpoint_base` |

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

Claim names use dotted lowercase tokens:

~~~ abnf
claim-name = claim-token *("." claim-token)
claim-token = LCALPHA *(LCALPHA / DIGIT / "_")
LCALPHA = %x61-7A
~~~

The `LCALPHA` rule is defined here. The `DIGIT` rule is defined by RFC 5234 {{RFC5234}}.

The Inspect document shown here contains only the fields required for the HTTP binding, Inspect, Enroll, Grant, Revoke, Status, and an example identity method:

~~~ json
{
  "aep_version": "1.0",
  "authentication": {
    "methods": ["aep-jwt", "oauth-bearer"]
  },
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
    "endpoint_base": "/aep/",
    "openapi": {
      "path_matching": {"trailing_slash": "strict"},
      "url": "/openapi.json"
    }
  },
  "identity": {
    "methods": ["did:web"]
  },
  "service": {
    "did": "did:web:api.example.com"
  }
}
~~~

`commands.supported` lists commands the Service exposes and MUST contain `inspect`. Agents MUST NOT invoke commands absent from this list. An Agent MUST ignore a syntactically valid command identifier it does not recognize.

`bindings.supported` lists protocol bindings implemented by the Service and MUST contain `http` for an implementation of this document. An Agent MUST ignore a syntactically valid binding identifier it does not recognize.

`commands.grant_types` lists concrete session-credential formats the Service can issue and revoke. If this array is empty or absent, the Service MUST NOT list `grant` or `revoke` in `commands.supported`.

`commands.grant_types_config` contains optional configuration for advertised Grant Types. Each member name MUST also appear in `commands.grant_types`. The common `supports_per_credential_revoke` member is a string boolean. If it is absent or `"false"`, an Agent MUST use grant-type or all-grant-types Revoke. If it is `"true"`, the Service MUST accept a Revoke request containing both that `grant_type` and a `credential_id`, and an Agent MAY use that targeted form. Concrete session-credential documents MAY define additional members.

`authentication.methods` lists, in preference order, the authentication methods accepted by protected resources belonging to the Service. `aep-jwt` identifies an AEP client assertion with `op` equal to `authenticate`. Other values MUST be registered Grant Type wire identifiers and use that grant type's credential presentation rules. The field is OPTIONAL; if it is absent, the Service advertises no protected-resource authentication method. When present, it MUST contain between one and sixteen values with no duplicates. An absent or empty `commands.grant_types` array does not imply support for `aep-jwt` or any other method. `authenticate` MUST NOT appear in `commands.supported` because it is an assertion operation, not a Service command endpoint.

The protected-resource methods in `authentication.methods` are distinct from authentication of AEP command endpoints. Advertising or omitting `aep-jwt` in this array does not alter the requirement that every authenticated AEP command accept its operation-bound baseline client assertion.

`identity.methods` lists identity method identifiers the Service accepts for authenticated AEP commands. The values are lower-case identifiers registered in the AEP Identity Methods registry. A Service that advertises Enroll, Grant, Revoke, or Status MUST advertise at least one identity method.

`service.did` identifies the Service. Agents use this value as the `aud` claim in client assertion JWTs.

When `service.did` uses the `did:web` method {{DID-WEB}}, the HTTPS origin encoded by the DID MUST equal the origin of the final Inspect response URL. DID path components do not alter the encoded origin. Agents MUST reject a mismatch before provisioning an Agent identity, requesting a client assertion, or transmitting credentials. Agents SHOULD expose `service_identity_mismatch` as the local failure identifier; this is not an HTTP Problem Details response from the Service. This requirement applies regardless of whether the Service appears in a directory. Other Service DID methods MUST define an equivalent origin-control binding before Agents rely on them. An Agent that does not implement that binding MUST reject the Inspect document.

Services SHOULD send HTTP cache metadata, including `Cache-Control` and `ETag`, on Inspect responses. A default freshness lifetime of 300 seconds is RECOMMENDED when the Service does not need a shorter policy window.

Agents MUST honor usable HTTP caching metadata on Inspect, including `Cache-Control`, `ETag`, and `Last-Modified`, and MUST process successful conditional revalidation through `304 Not Modified`. `no-cache` requires revalidation before reuse. `no-store` prohibits persistent or transient reuse beyond the current fetch. When no shorter usable freshness policy is supplied, Agents SHOULD use 300 seconds. The cache key is the requested advertised URL and MUST be updated to the final URL after an accepted redirect so revalidation targets the representation that produced the cached document.

Agents MUST require the media-type essence of a successful Inspect response to be `application/aep+json`. Comparison is case-insensitive and ignores valid media-type parameters. A missing, malformed, or different media type MUST be rejected.

An Agent following an Inspect redirect MUST require each redirect target to have the same scheme, host, and effective port as the preceding request URL. Cross-origin redirects and scheme downgrades MUST be rejected. This restriction applies to the unauthenticated Inspect command and does not prevent a future extension from defining a signed Inspect response.

Agents MAY enforce documented bounds on the decoded response size and total completion time. An Agent that enforces such bounds MUST fail closed when a bound is exceeded and MUST NOT process a partial Inspect document.

## OpenAPI Advertisement

`http.openapi`, when present, advertises an OpenAPI 3.1 document for protected Service resources. It contains required `url` and `path_matching.trailing_slash` fields. `url` is a URI-reference. A relative reference resolves against the final Inspect response URL. An absolute HTTPS URL MAY be cross-origin. Plaintext HTTP is prohibited except when the URL host is syntactically exactly `localhost`, `127.0.0.1`, or `[::1]` for development; resolving another name to a loopback address does not qualify. User-information components and HTTPS-to-HTTP downgrade are prohibited.

`path_matching.trailing_slash` is `strict` or `equivalent`. Under `strict`, paths that differ by a terminal slash are distinct. Under `equivalent`, exactly one terminal slash is ignored except for `/`. The canonical behavior when processing older compatible cached data that lacks this member is `strict`; new documents using `http.openapi` MUST include it.

OpenAPI retrieval is anonymous. An Agent MUST NOT send resource credentials, AEP assertions, Platform credentials, cookies, caller authorization headers, or other headers copied from the triggering request. Agents MUST enforce documented redirect-count, decoded-byte, and total-completion-time bounds. Redirects MUST NOT downgrade transport or introduce user information. A cross-origin HTTPS redirect remains anonymous and is permitted within the bound.

Agents MUST accept OpenAPI 3.1 JSON represented as `application/vnd.oai.openapi+json` with a `version=3.1` parameter or as `application/json`. Media-type comparison is case-insensitive and permits unrelated valid parameters. Agents MUST reject missing, malformed, or other media types, non-JSON bodies, documents whose `openapi` version is not `3.1.x`, and partial or over-bound documents.

## OpenAPI Security Mapping

Agents use standard OpenAPI root and operation `security` inheritance and `components.securitySchemes`. An operation-level `security` replaces the root value. An empty security array makes the operation public. An empty requirement object permits anonymous access as one alternative. Multiple requirement objects are alternatives; multiple schemes within one requirement are a compound requirement and all must be satisfied.

The `x-aep-authentication-method` Security Scheme Object extension binds an arbitrary OpenAPI security-scheme name to `aep-jwt` or a registered AEP Grant Type wire identifier. Its value is one registered authentication method identifier. A referenced scheme without this extension is not an AEP method. An Agent MUST treat a compound requirement as unsupported when it cannot satisfy every member and MAY select another complete alternative. It MUST NOT silently reduce a compound requirement to one scheme.

To select an operation, Agents uppercase the concrete HTTP method and match the request path using OpenAPI path-template rules. Literal path segments take precedence over templated segments. Query parameters never select an operation. Under `strict`, terminal slash variants differ. Under `equivalent`, one terminal slash is ignored except for `/`. Multiple equally applicable templates, structurally equivalent templates with different variable names, or another ambiguous match are contradictions.

A fresh, definitive operation match MAY be used to plan authentication without first probing the protected resource. An undocumented operation, unsupported or ambiguous mapping, stale document, or contradiction between OpenAPI and a live response requires fallback to anonymous live challenge discovery and document revalidation. OpenAPI never authorizes a request and never permits credentials to bypass the redirect-safety rules.

# Identity Methods

Authenticated AEP commands require an Agent identity method that can bind a stable Agent identifier to verification material for the client assertion signature.

This document defines the identity-method substrate but does not define a concrete identity method. Concrete identity method documents define:

1. The identity method identifier used in `identity.methods`.
2. The Agent identifier syntax.
3. How a Service resolves or otherwise obtains verification material for the Agent identifier.
4. How the JWT `kid` header identifies the verification method.
5. Any caching, rotation, revocation, or trust-anchor requirements.
6. Security and privacy considerations specific to that identity method.

A Service enables the identity methods it accepts and advertises only those identifiers in `identity.methods`. A Service that advertises no identity methods MUST NOT advertise authenticated commands.

For example, a Service that enables the separately specified `did:web` identity method advertises:

~~~ json
{
  "identity": {
    "methods": ["did:web"]
  }
}
~~~

If the Agent presents an identity method not listed in the Service's `identity.methods` array, the Service MUST reject the request as `not_recognized`.

# AEP HTTP Authentication Scheme

The AEP HTTP authentication scheme uses the `AEP` auth-scheme value. The rules `ALPHA`, `DIGIT`, `DQUOTE`, and `SP` are defined by RFC 5234 {{RFC5234}}. The rules `auth-param`, `BWS`, and `OWS` are defined by HTTP semantics {{RFC9110}}.

~~~ abnf
AEP-credentials = "AEP" 1*SP compact-jws
compact-jws     = base64url "." base64url "." base64url
base64url       = 1*( ALPHA / DIGIT / "-" / "_" )

AEP-challenge        = "AEP" [ 1*SP AEP-challenge-param
                       *( OWS "," OWS AEP-challenge-param ) ]
AEP-challenge-param  = reason-param / service-param /
                       inspect-param / auth-param
reason-param         = "reason" BWS "=" BWS DQUOTE error-code DQUOTE
service-param        = "service_did" BWS "=" BWS
                       DQUOTE did-value DQUOTE
inspect-param        = "inspect" BWS "=" BWS
                       DQUOTE absolute-uri DQUOTE
did-value            = 1*(%x21 / %x23-5B / %x5D-7E)
absolute-uri         = 1*(%x21 / %x23-5B / %x5D-7E)
error-code           = lc-token *( "_" lc-token )
lc-token             = LCALPHA *( LCALPHA / DIGIT )
~~~

The `AEP-credentials` form is used in the `Authorization` field on command endpoints and in either `Authorization` or `AEP-Authorization` on protected resources. The `AEP-challenge` form is used in the `WWW-Authenticate` field. Parameter and field names are case-insensitive and each parameter MUST occur at most once. The `reason` parameter carries an AEP error code. A protected resource advertising AEP support MUST include `service_did` and `inspect`; `service_did` identifies the Service and `inspect` is the absolute HTTPS URI of that Service's Inspect document. Agents MUST require the challenged Service DID to match the fetched Inspect document. Challenges without the `AEP` scheme, or without both discovery parameters, do not initiate AEP discovery.

# Client Assertion JWT

Enroll, Grant, Revoke, and Status use a signed client assertion JWT. Inspect is unauthenticated and does not use a client assertion. Protected resources use only the methods advertised in `authentication.methods`; `aep-jwt` selects the client assertion defined in this section with `op` equal to `authenticate`.

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

`alg` identifies the signing algorithm. Services supporting this document MUST support `EdDSA` {{RFC8037}} and `ES256` {{RFC7518}} and advertise accepted algorithms in `core.signing_algorithms`. Agents MUST select an algorithm advertised by the Service. The `none` algorithm and symmetric JOSE algorithms MUST NOT be used for Agent identity assertions.

`typ` MUST be `JWT`.

`kid` identifies the Agent's DID and MAY include a fragment selecting a verification method in the resolved DID document. The DID portion of `kid` MUST equal the Agent DID carried in `iss` and `sub`.

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

`op` MUST equal the operation being invoked. The values defined by this document are `enroll`, `grant`, `revoke`, `status`, and `authenticate`. The four command operations are valid only at their corresponding AEP command endpoint. `authenticate` is valid only at a protected resource and is never valid at an AEP command endpoint.

An assertion with `op` equal to `authenticate` MUST also contain `resource`, an absolute HTTPS URI identifying the protected resource target. The value MUST equal the request target URI after URI normalization that does not change resource identity; fragments are prohibited. A protected resource MUST reject an assertion whose `resource` does not identify that target. Redirect targets require a newly issued assertion when the normalized resource URI changes.

`iat` and `exp` are NumericDate values as defined by JWT {{RFC7519}}: seconds since the Unix epoch represented as JSON numbers. These claims are an exception to AEP-owned JSON payload numeric-string encoding. Services MUST reject assertions where `exp - iat` is greater than 300 seconds. Services SHOULD allow no more than 30 seconds of local clock skew.

`jti` MUST be freshly generated for each assertion. Services MUST maintain a replay cache keyed by at least `(sub, jti)` for the assertion lifetime plus the accepted clock-skew window.

To verify a client assertion, the Service MUST:

1. Parse the JWT header, claims set, and signature.
2. Reject the assertion if `alg` is not advertised by the Service or is prohibited by this document.
3. Resolve the DID identified by `kid`.
4. Select the referenced verification method.
5. Verify the JWS signature.
6. Verify `iss`, `sub`, `aud`, `op`, `resource` when required, `iat`, `exp`, and `jti` according to this section.

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

`claims` carries claim values requested by the Service's Inspect document. Claim names are strings and claim values are JSON values. Interoperable names and value shapes for common person and contact claims are defined by {{AEP-CLAIMS}}. Services MUST ignore unknown claims unless local policy requires rejection.

`idempotency_key` is an opaque retry key. When both the HTTP `Idempotency-Key` header and body field are present, they MUST contain the same value.

When the authenticated Agent DID already has an enrollment record, the Service
MUST return the current enrollment lifecycle representation. It MUST NOT treat
the request as renewal or replacement, rerun enrollment policy, reset lifecycle
timestamps, or replace the existing record. This requirement applies when the
request uses a new idempotency key and is distinct from replaying a request with
the same idempotency key.

Successful Enroll responses use `200 OK`. A synchronous enrollment returns:

~~~ json
{
  "status": "active"
}
~~~

If enrollment requires asynchronous verification, the Service returns:

~~~ json
{
  "owner_action_required": "true",
  "status": "pending",
  "verification_pending": ["contact.email"]
}
~~~

The Agent polls Status to learn whether a pending enrollment has become `active` or `rejected`.

Enroll and Status lifecycle responses have two distinct optional dimensions. `verification_pending` lists submitted claim names whose asynchronous verification has not completed. `requirements_pending` lists requirement names the Agent still needs to satisfy. Either field can appear on either response, and the fields MUST NOT be treated as aliases. Empty arrays MUST be omitted; absence means that the corresponding set is empty. Claim values MUST NOT appear in either array.

`owner_action_required` is independent of both pending dimensions and can accompany either, both, or neither. Canonical serialization MUST omit `owner_action_required` unless its value is `"true"`. Consumers MUST accept an explicit `"false"` for compatibility.

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
  "since": "2026-05-28T12:00:00Z",
  "status": "active"
}
~~~

`status` describes the Agent identity's state at the Service:

| Value         | Meaning                                                                           |
| ------------- | --------------------------------------------------------------------------------- |
| `active`      | The identity is enrolled and operational.                                         |
| `pending`     | Enrollment is awaiting asynchronous verification.                                 |
| `unavailable` | The identity is temporarily unavailable for Service-defined non-punitive reasons. |
| `suspended`   | The identity is temporarily disabled by Service action.                           |
| `terminated`  | The identity is permanently de-registered.                                        |
| `rejected`    | Asynchronous verification failed.                                                 |

`since` is the RFC 3339 {{RFC3339}} timestamp of the last state transition.

The lifecycle fields defined for Enroll apply identically to Status. `owner_action_required` equal to `"true"` indicates that the Agent's Owner must complete an out-of-band action before the identity can become or remain active.

# The Grant Command

Grant exchanges a baseline client assertion for a session credential. The request uses the baseline client assertion with `op` equal to `grant`. A session credential MUST NOT be used to authenticate Grant.

Grant requires an existing enrollment recognized by the Service. When current enrollment is not already authoritative, an Agent SHOULD call Status before beginning an approval, signing, or credential-issuance workflow. The Service remains authoritative and MUST reject Grant for an unrecognized Agent with `not_recognized`; it MUST NOT implicitly enroll the Agent.

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

The successful response body is defined by the concrete session-credential document. This core document requires only that the response be a JSON object and that the selected document define credential presentation, expiry semantics, and revocation behavior. A successful response MUST contain the usable credential material required by that document and a stable Service-issued `credential_id`. The identifier identifies the issued credential for management and storage; it is not credential material and is not presented to a protected resource unless the concrete document explicitly defines that behavior.

A `credential_id` MUST be unique among all credentials issued by the Service, across Agents and Grant Types, and the Service MUST NOT reassign it. Its logical identity is the pair of the Service DID and `credential_id`. The identifier is opaque to Agents; this document does not require a particular identifier format.

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

`grant_type` MUST be one of the values advertised in `commands.grant_types`. By default, Revoke targets all credentials of that grant type issued to the authenticated Agent. A request containing both `grant_type` and `credential_id` targets the single issued credential identified by `credential_id`. An Agent MUST send that form only when the Service configuration for the selected grant type advertises per-credential Revoke. A Service advertising per-credential Revoke MUST support that form. Concrete session-credential documents define any additional requirements for narrower credential targeting.

To revoke all session credentials of every grant type issued to the authenticated Agent, the request body is:

~~~ json
{
  "all_grant_types": "true"
}
~~~

`all_grant_types` is a string boolean. When `all_grant_types` is `"true"`, the request MUST NOT contain `grant_type` or `credential_id`. A Service that supports Revoke MUST support `all_grant_types` so an Agent can invalidate all issued session credentials without discovering or iterating over every concrete grant type. A malformed Revoke request, including a request with mutually exclusive fields, fails with `invalid_request`.

Successful Revoke responses use `200 OK` and an empty JSON object:

~~~ json
{}
~~~

The Service MUST return success regardless of whether any matching credentials existed.

# Protected-Resource Authentication

`authenticate` authenticates an Agent to an arbitrary protected Service resource; it does not identify a Service command and defines no new command endpoint. An Agent using `aep-jwt` sends an `AEP <jwt>` field value with `op` equal to `authenticate`, `aud` equal to the Service DID, and `resource` equal to the protected request target. A protected resource MUST reject assertions carrying `enroll`, `grant`, `revoke`, or `status`. Each AEP command endpoint likewise MUST reject `authenticate` and every non-matching command operation.

Protected resources accept AEP credentials in either the standard `Authorization` field or the dedicated `AEP-Authorization` field. Generic Agents default to `Authorization` for compatibility. A caller MAY explicitly select `AEP-Authorization`; Agents composing AEP with MPP or x402 SHOULD select it before the first authenticated retry and preserve that selection for the operation, including newly issued assertions after safe redirects.

The dedicated field preserves the complete normal field value, including its authentication scheme:

~~~ http-message
AEP-Authorization: AEP <client-assertion>
AEP-Authorization: Bearer <token>
AEP-Authorization: Basic <credentials>
~~~

Services MUST accept both carriers for `aep-jwt` and every registered Grant Type whose normal presentation uses `Authorization`. Registered Grant Type specifications define that mapping. API-key credentials continue to use exactly the Service-selected `header` returned in the Grant response and have no second generic representation.

An Agent MUST use at most one AEP carrier per request. A Service inspects `AEP-Authorization` first and falls back to `Authorization` only when the dedicated field is absent. If both fields contain an AEP-recognized credential, the Service MUST reject the request as `not_recognized`; it MUST NOT choose one. An invalid dedicated credential fails closed without fallback to a second AEP credential in `Authorization`.

`AEP-Authorization` together with `Authorization: Payment <credentials>` or `PAYMENT-SIGNATURE` is valid and non-ambiguous. After dedicated AEP authentication succeeds, the AEP layer MUST NOT consume, rewrite, log, or forward an unrelated `Authorization` credential. Payment processing occurs only after AEP authentication succeeds; the anonymous response remains the `401` AEP challenge.

Field-name comparison is case-insensitive. A request MUST NOT contain multiple `AEP-Authorization` field lines or a combined value encoding more than one AEP credential. Services MUST treat such ambiguity as credential smuggling and return the non-disclosing `not_recognized` Problem Details error.

Both authorization fields are sensitive. Agents, Services, intermediaries, caches, and telemetry MUST redact them and MUST NOT log raw values. Neither field participates in cache keys or idempotency fingerprints. `AEP-Authorization` MUST NOT be copied into assertion claims or signatures, Platform context, Inspect, OpenAPI, or another protocol document.

A protected resource that requires authentication returns `401 Unauthorized` with an AEP challenge:

~~~ http-message
WWW-Authenticate: AEP service_did="did:web:x",inspect="https://x/a"
~~~

An Agent MAY first send the exact requested method, URL, headers, and body without AEP credentials. It begins AEP discovery only when a `401` response contains a valid `AEP` challenge with `service_did` and `inspect`. Unrelated `401` responses MUST NOT trigger AEP authentication.

Before beginning discovery, approval, Grant, or authenticated retry, an Agent MUST determine whether the request body can be replayed. If it cannot reproduce the identical body, it MUST fail without starting an authentication flow. Implementations MAY apply documented cancellation, total-time, and response-size bounds and MUST fail closed rather than process partial authentication metadata.

An Agent MUST NOT forward an AEP assertion or session credential across an origin change. It MAY follow a same-origin redirect with the credential only when the redirected request remains authorized by the credential and, for `aep-jwt`, uses a newly issued assertion bound to the redirect target's `resource` in the same selected AEP carrier. For a cross-origin redirect, the Agent MUST remove `Authorization`, `AEP-Authorization`, `PAYMENT-SIGNATURE`, every AEP assertion, every AEP-issued session credential, and every payment credential, then restart at the target with an anonymous request. It MUST require a new valid AEP challenge before authenticating to the new origin. Redirect handling MUST NOT copy a Service-selected API-key header to another origin.

Successful authentication establishes an Agent principal and credential metadata, including the authentication method and granted scopes when applicable. It does not authorize the requested application action. The protected application separately evaluates resource policy and scopes. A valid credential with inadequate permission fails with `insufficient_scope` and `403 Forbidden`, without being treated as an authentication failure.

Missing credentials use `authentication_required`. A method not listed in `authentication.methods` uses `unsupported_authentication_method`. Malformed or expired credentials, wrong operation, wrong audience, wrong resource, and replayed assertions use the non-disclosing `not_recognized` error. Protected resources MUST consume `jti` atomically before accepting an `authenticate` assertion so concurrent replays cannot both succeed.

# Idempotency

POST commands are state-mutating and MUST support safe retry with a non-empty `Idempotency-Key` HTTP header. Agents MUST send this header and Services MUST reject Enroll, Grant, or Revoke requests that omit it or carry an empty value with `400 Bad Request` and `code` equal to `invalid_request`.

Services MUST cache the response associated with `(agent_did, Idempotency-Key)` for at least 1 hour. Each record MUST bind the command and a cryptographic hash of a canonical representation of the request body. If a request repeats the same key with the same authenticated Agent, command, and request body, the Service MUST return the cached response or an equivalent successful response.

If the same authenticated Agent reuses an idempotency key for a different command or request body, the Service MUST return `409 Conflict` with `code` equal to `idempotency_conflict`.

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
  "title": "Not recognized",
  "type": "urn:aep:error:not_recognized"
}
~~~

The `code` field is the canonical machine-readable AEP error code. `type` identifies the AEP error class using the form `urn:aep:error:<code>`. `title` MAY be omitted from production responses.

After an identity has been recognized, a `verification_pending` Problem Details response MAY include a non-empty `verification_pending` array, and a `requirements_unmet` response MAY include a non-empty `requirements_pending` array. Either response MAY include `owner_action_required` only when its value is `"true"`. These fields contain names only and MUST NOT contain claim values. They describe why the attempted operation is blocked; pending Enroll and Status state continues to use successful lifecycle responses. A `not_recognized` response MUST NOT include any of these fields.

This document defines the following HTTP error codes:

| AEP code                            | HTTP status | Meaning                                                                                                                                                    |
| ----------------------------------- | ----------: | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enrollment_failed`                 | 400         | Generic enrollment failure where the Service suppresses precise detail.                                                                                    |
| `invalid_request`                   | 400         | The request body, parameters, or field combination is malformed or invalid.                                                                                |
| `not_recognized`                    | 401         | Umbrella anti-enumeration error for failed identity, signature, audience, operation, replay, time-window, archived-identity, or unsupported-method checks. |
| `identity_suspended`                | 403         | The recognized identity is temporarily disabled by Service action.                                                                                         |
| `identity_terminated`               | 403         | The recognized identity is permanently de-registered.                                                                                                      |
| `identity_unavailable`              | 403         | The recognized identity is temporarily unavailable for Service-defined reasons.                                                                            |
| `requirements_unmet`                | 422         | Required claims are missing or invalid.                                                                                                                    |
| `verification_pending`              | 403         | Enrollment or required verification has not completed.                                                                                                     |
| `verification_timeout`              | 422         | Required asynchronous verification did not complete in the Service's policy window.                                                                        |
| `rate_limited`                      | 429         | The Agent exceeded a Service rate limit.                                                                                                                   |
| `unsupported_grant_type`            | 400         | Grant or Revoke requested a `grant_type` not advertised by the Service.                                                                                    |
| `idempotency_conflict`              | 409         | An idempotency key was reused with a different request body.                                                                                               |
| `authentication_required`           | 401         | The protected resource requires an advertised authentication method.                                                                                       |
| `unsupported_authentication_method` | 401         | The presented authentication method is not accepted by the protected resource.                                                                             |
| `insufficient_scope`                | 403         | Authentication succeeded but the principal lacks required authorization scope.                                                                             |

Services MUST use `not_recognized` for bad signatures, unknown Agent identities, wrong `aud`, wrong `op`, replayed `jti`, time-window violations, archived identities, unsupported identity methods during authenticated contact, and unknown or revoked session credentials. Services MUST NOT reveal which of these checks failed.

Services MUST use `invalid_request` for malformed JSON, missing required fields, invalid field types, unsupported field combinations, and syntactically invalid requests when returning the error would not reveal identity-recognition state.

Services SHOULD avoid readily observable timing differences among `not_recognized` paths. Implementations can perform comparable validation work or apply response-time bucketing, but this specification does not require constant-time responses or prescribe an artificial delay.

When a request fails for multiple reasons, the Service MUST choose the least revealing error. For example, a request with both a bad signature and missing claims returns `not_recognized`, not `requirements_unmet`.

# Extensibility

This document defines the extension points needed by the core protocol:

* `extensions.supported` advertises extension identifiers implemented by the Service.
* `identity.methods` advertises concrete identity methods accepted for authenticated AEP commands.
* `commands.grant_types` advertises concrete session-credential formats available through Grant and Revoke.
* `commands.grant_types_config` carries common and concrete per-grant-type configuration.
* `claims.required`, `claims.preferred`, and `claims.optional` MAY contain claim names from the AEP Claim Names registry or claim names defined by other documents.
* Additional top-level Inspect fields MAY be added by future documents.

Agents MUST ignore extension identifiers, additive fields, and syntactically valid advertised list values they do not understand, unless local policy requires the Agent to refuse enrollment when a required capability is absent. Ignoring an unknown command means that the Agent does not invoke it. Ignoring another advertised capability does not imply support for that capability.

Services MUST NOT redefine the semantics of commands, fields, status values, or error codes defined by this document. Extensions are additive.

Concrete session-credential documents MUST define:

1. The `grant_type` string.
2. Grant request fields beyond `grant_type`, if any.
3. Grant response shape.
4. Credential presentation on HTTP requests.
5. Expiry semantics.
6. Revoke request fields beyond `grant_type` and `all_grant_types`, if any.
7. Error behavior beyond the core errors, if any.

# Wire Identifier Syntax

Command identifiers, binding identifiers, and grant type identifiers use lowercase hyphenated tokens:

~~~ abnf
wire-identifier = lc-token *( "-" lc-token )
~~~

Error codes use lowercase underscore-separated tokens:

~~~ abnf
error-code = lc-token *( "_" lc-token )
~~~

Identity method identifiers use either an existing DID method identifier, such as `did:web`, or a lowercase hyphenated token registered for AEP-specific non-DID identity methods.

Extension identifiers MUST be absolute URIs. AEP-owned extension identifiers SHOULD use the URN form `urn:aep:ext:<authority>:<name>#v=<version>`.

# IANA Considerations

This section requests registrations and registry creation following RFC 8126 {{RFC8126}}.

## HTTP Authentication Scheme

IANA is requested to register the following HTTP authentication scheme in the "HTTP Authentication Schemes" registry:

| Field                      | Value                                                     |
| -------------------------- | --------------------------------------------------------- |
| Authentication Scheme Name | `AEP`                                                     |
| Reference                  | This document                                             |
| Notes                      | Agent Enrollment Protocol client assertion authentication |

## HTTP Field Name

IANA is requested to register the following permanent field name in the "Hypertext Transfer Protocol (HTTP) Field Name Registry":

| Field Name          | Status    | Structured Type | Reference     |
| ------------------- | --------- | --------------- | ------------- |
| `AEP-Authorization` | permanent | N/A             | This document |

`AEP-Authorization` carries one AEP-recognized protected-resource credential while preserving its registered authentication scheme and credential syntax. It is a request field and is unsafe for logging, forwarding across disallowed redirects, or cache-key construction.

## Well-Known URI

IANA is requested to register the following URI suffix in the "Well-Known URIs" registry:

| Field               | Value                                      |
| ------------------- | ------------------------------------------ |
| URI Suffix          | `aep`                                      |
| Change Controller   | IETF                                       |
| Reference           | This document                              |
| Related Information | Agent Enrollment Protocol Inspect document |

## Media Type

IANA is requested to register the following media type in the "Media Types" registry:

| Field                                                       | Value                                                                                                                                                                                                                                                                                                                                                   |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Type name                                                   | `application`                                                                                                                                                                                                                                                                                                                                           |
| Subtype name                                                | `aep+json`                                                                                                                                                                                                                                                                                                                                              |
| Required parameters                                         | None                                                                                                                                                                                                                                                                                                                                                    |
| Optional parameters                                         | None                                                                                                                                                                                                                                                                                                                                                    |
| Encoding considerations                                     | Same as JSON {{RFC8259}}                                                                                                                                                                                                                                                                                                                                |
| Security considerations                                     | AEP payloads can contain Agent identifiers, claims, session credentials, and other security-sensitive protocol data. Implementations need to apply the authentication, confidentiality, anti-replay, anti-enumeration, logging, and privacy requirements described in the Security Considerations and Privacy Considerations sections of this document. |
| Interoperability considerations                             | None                                                                                                                                                                                                                                                                                                                                                    |
| Published specification                                     | This document                                                                                                                                                                                                                                                                                                                                           |
| Applications that use this media type                       | Services and Agents implementing AEP                                                                                                                                                                                                                                                                                                                    |
| Fragment identifier considerations                          | Same as JSON {{RFC8259}}                                                                                                                                                                                                                                                                                                                                |
| Additional information                                      | None                                                                                                                                                                                                                                                                                                                                                    |
| Person and email address to contact for further information | IETF <iesg@ietf.org>                                                                                                                                                                                                                                                                                                                                    |
| Intended usage                                              | COMMON                                                                                                                                                                                                                                                                                                                                                  |
| Restrictions on usage                                       | None                                                                                                                                                                                                                                                                                                                                                    |
| Author                                                      | IETF                                                                                                                                                                                                                                                                                                                                                    |
| Change controller                                           | IETF                                                                                                                                                                                                                                                                                                                                                    |

## AEP Command Registry

IANA is requested to create an "AEP Commands" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new command registrations define command semantics, authentication requirements, request and response shapes, idempotency behavior for state-mutating commands, and error behavior.

Each entry contains:

| Field       | Description                     |
| ----------- | ------------------------------- |
| Command     | Lowercase wire identifier.      |
| Description | Short command description.      |
| Reference   | Stable specification reference. |

Initial entries are:

| Command   | Description                                | Reference     |
| --------- | ------------------------------------------ | ------------- |
| `inspect` | Discover Service AEP capabilities.         | This document |
| `enroll`  | Register an Agent identity with a Service. | This document |
| `status`  | Query the Agent identity's current state.  | This document |
| `grant`   | Issue a session credential.                | This document |
| `revoke`  | Revoke session credentials.                | This document |

`authenticate` is not registered as a command because it does not identify a command endpoint.

## AEP Operation Registry

IANA is requested to create an "AEP Operations" registry. The registration policy is Specification Required. Each registration MUST define its valid target class, assertion binding, and replay behavior.

| Operation      | Valid target                                | Reference     |
| -------------- | ------------------------------------------- | ------------- |
| `enroll`       | Enroll command endpoint                     | This document |
| `grant`        | Grant command endpoint                      | This document |
| `revoke`       | Revoke command endpoint                     | This document |
| `status`       | Status command endpoint                     | This document |
| `authenticate` | Protected Service resource, not AEP command | This document |

## AEP Authentication Method Registry

IANA is requested to create an "AEP Authentication Methods" registry. The registration policy is Specification Required. Each registration MUST define credential presentation, expiry and replay behavior, redirect handling, and authentication failure behavior. Registered AEP Grant Type identifiers are also valid authentication method identifiers when the corresponding grant specification defines protected-resource presentation.

| Authentication Method | Description                              | Reference     |
| --------------------- | ---------------------------------------- | ------------- |
| `aep-jwt`             | Resource-bound AEP client assertion JWT. | This document |

The initial registered Grant Type method identifiers are `oauth-bearer`, `api-key`, and `basic`, as defined by their respective documents.

## AEP Binding Identifier Registry

IANA is requested to create an "AEP Binding Identifiers" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new binding registrations define transport semantics, endpoint discovery, authentication carriage, payload encoding, error mapping, and security considerations.

Each entry contains:

| Field              | Description                     |
| ------------------ | ------------------------------- |
| Binding Identifier | Lowercase wire identifier.      |
| Description        | Short binding description.      |
| Reference          | Stable specification reference. |

Initial entries are:

| Binding Identifier | Description                    | Reference     |
| ------------------ | ------------------------------ | ------------- |
| `http`             | HTTP binding for AEP commands. | This document |

## AEP Extension Identifier Registry

IANA is requested to create an "AEP Extension Identifiers" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new extension registrations define the extension identifier, discovery behavior, protocol fields or commands added by the extension, error behavior, and security and privacy considerations.

Each entry contains:

| Field                | Description                             |
| -------------------- | --------------------------------------- |
| Extension Identifier | Absolute URI identifying the extension. |
| Description          | Short extension description.            |
| Reference            | Stable specification reference.         |

This document creates the registry but does not register concrete extensions.

## OpenAPI Specification Extension

This document registers the following OpenAPI Specification Extension for Security Scheme Objects:

| Field       | Value                                           |
| ----------- | ----------------------------------------------- |
| Name        | `x-aep-authentication-method`                   |
| Type        | String                                          |
| Description | Registered AEP authentication method identifier |
| Reference   | This document                                   |

## AEP Error Code Registry

IANA is requested to create an "AEP Error Codes" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new error codes are binding-independent, use `lower_snake_case`, avoid exposing identity-enumeration detail, and define default HTTP status mapping and remediation behavior.

Each entry contains:

| Field       | Description                              |
| ----------- | ---------------------------------------- |
| Code        | Lowercase `lower_snake_case` error code. |
| HTTP Status | Default HTTP status code.                |
| Description | Short error description.                 |
| Reference   | Stable specification reference.          |

Initial entries are:

| Code                                | HTTP Status | Description                                           | Reference     |
| ----------------------------------- | ----------: | ----------------------------------------------------- | ------------- |
| `enrollment_failed`                 | 400         | Generic enrollment failure.                           | This document |
| `invalid_request`                   | 400         | Malformed or invalid request.                         | This document |
| `not_recognized`                    | 401         | Anti-enumeration recognition failure.                 | This document |
| `identity_suspended`                | 403         | Recognized identity is suspended.                     | This document |
| `identity_terminated`               | 403         | Recognized identity is terminated.                    | This document |
| `identity_unavailable`              | 403         | Recognized identity is temporarily unavailable.       | This document |
| `requirements_unmet`                | 422         | Required claims are missing or invalid.               | This document |
| `verification_pending`              | 403         | Verification has not completed.                       | This document |
| `verification_timeout`              | 422         | Verification did not complete in time.                | This document |
| `rate_limited`                      | 429         | Rate limit exceeded.                                  | This document |
| `unsupported_grant_type`            | 400         | Unsupported Grant or Revoke grant type.               | This document |
| `idempotency_conflict`              | 409         | Idempotency key reused with a different request body. | This document |
| `authentication_required`           | 401         | Protected-resource authentication is required.        | This document |
| `unsupported_authentication_method` | 401         | Authentication method is not accepted.                | This document |
| `insufficient_scope`                | 403         | Authenticated principal lacks sufficient scope.       | This document |

## AEP Grant Type Registry

IANA is requested to create an "AEP Grant Types" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new grant type registrations define the Grant request fields, Grant response shape, credential presentation syntax, expiry semantics, Revoke behavior, and security considerations for credential storage and leakage.

Each entry contains:

| Field       | Description                     |
| ----------- | ------------------------------- |
| Grant Type  | Lowercase wire identifier.      |
| Description | Short credential description.   |
| Reference   | Stable specification reference. |

This document creates the registry but does not register concrete grant types. OAuth Bearer, API-key, and Basic session credentials are defined by separate documents.

## AEP Identity Method Registry

IANA is requested to create an "AEP Identity Methods" registry. The registration policy is Specification Required as defined by RFC 8126. Designated experts are requested to verify that new identity method registrations define identifier syntax, verification-material resolution, JWT `kid` handling, trust anchors, caching behavior, key rotation behavior, and security and privacy considerations.

Each entry contains:

| Field           | Description                     |
| --------------- | ------------------------------- |
| Identity Method | Lowercase identity method name. |
| Description     | Short method description.       |
| Reference       | Stable specification reference. |

This document creates the registry but does not register concrete identity methods. The `did:web` identity method is defined by a separate document.

# Security Considerations

Network use of the HTTP binding defined by this document requires TLS 1.3 or later. Plaintext HTTP is out of scope.

Client assertions are replay resistant only when Services validate the full chain: `aud`, `op`, `resource` when required, `jti`, `iat`, and `exp`. `aud` binds the assertion to the Service DID. `op` binds the assertion to one registered operation. `resource` binds `authenticate` to a protected request target. `jti` prevents in-window duplicate use. `iat` and `exp` bound the usable time window. Services that skip any of these checks weaken the authentication model.

Services SHOULD keep assertion lifetimes short. This document sets a maximum validity interval of 300 seconds. Services MAY enforce a shorter maximum.

Identity methods define how Services obtain verification material for Agent identities. Services MUST apply the resolution, trust-anchor, caching, and key-rotation requirements of each enabled identity method. A Service MUST NOT accept an Agent identity method that was not advertised in `identity.methods`.

Resolving a Service DID proves that the DID document exists; it does not prove that the origin serving an Inspect document controls that DID. An attacker that publishes another Service's DID could otherwise induce an Agent to create or disclose an assertion whose audience names the victim Service. Agents MUST enforce the Service-origin binding defined for the Service DID method before provisioning identity material, requesting an assertion, or transmitting credentials. Directory membership and directory ownership metadata MUST NOT substitute for this check.

The `core.signing_algorithms` advertisement is security relevant. Services MUST NOT advertise algorithms they do not intend to accept, and MUST NOT accept algorithms that were not advertised. Agents MUST NOT use `none` or symmetric JOSE algorithms for Agent identity assertions. Implementations SHOULD follow JWT best current practices {{RFC8725}}.

Authentication failures are an enumeration risk. Services MUST collapse recognition failures to `not_recognized` and SHOULD avoid readily observable timing differences among failures involving an unknown Agent, a bad signature, a wrong audience, a wrong operation, a replay, an expired assertion, or an archived identity. Implementations need not add an artificial delay when their normal verification and storage paths already have comparable observable timing.

Grant issues session credentials that may be bearer credentials depending on the concrete session-credential document. Services and Agents MUST treat returned credentials as secrets. Concrete session-credential documents MUST define credential lifetime, presentation, storage guidance, and revocation semantics. Revoke MUST be available for every advertised grant type.

If a session credential is stolen, an attacker may impersonate the Agent until the credential expires or is revoked. Agents that suspect compromise can authenticate with the baseline client assertion and invoke Revoke for the affected grant type.

Services SHOULD rate-limit Inspect, Enroll, Grant, Revoke, and Status to reduce probing and credential-issuance abuse. Rate limits MUST NOT create distinguishable recognition errors that defeat the anti-enumeration rules above.

# Privacy Considerations

AEP exposes Agent identity and claims to Services. Agents and Services should minimize disclosure by using the Inspect document as the negotiation surface: Services list required, preferred, and optional claims; Agents provide the minimum set needed for the intended interaction.

Services SHOULD keep `claims.required` limited to data required for enrollment or legal operation. Over-declaring required claims increases privacy risk and reduces interoperability.

Agents SHOULD avoid sending claims absent from `claims.required`, `claims.preferred`, or `claims.optional`. Services MUST ignore unknown claims unless local policy requires rejection.

Agent identities can become correlatable if the same identifier is reused across Services. Platforms or Agent operators that require unlinkability SHOULD use a distinct Agent identifier and signing key per Service enrollment when the selected identity method allows it.

Services SHOULD maintain a Service-local pairwise identifier for enrolled Agents rather than using the Agent DID as the primary internal record key across all contexts. Such identifiers SHOULD be opaque and MUST NOT be disclosed as cross-Service correlators.

Platform-hosted Agent identities introduce Platform-level visibility: the Platform can observe or reconstruct which Services an Agent enrolls with. This document does not prevent that visibility. Agents with stronger privacy requirements should account for the Platform trust relationship before using a Platform-hosted identity.

Session credentials can become correlation handles when reused outside the issuing Service or logged by intermediaries. Concrete session-credential documents MUST define presentation rules that avoid unnecessary disclosure and MUST prohibit logging raw credential values.

Inspect documents may disclose Service policy and capability information to unauthenticated readers. Services SHOULD avoid publishing sensitive operational details in Inspect beyond what Agents need for interoperability.
