---
title: "Basic Session Credentials for the Agent Enrollment Protocol"
abbrev: "AEP Basic"
docname: draft-kavian-aep-basic-session-credential-00
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
  RFC3339:
  RFC7617:
  RFC8259:
  RFC9110:
  AEP-CORE:
    title: "The Agent Enrollment Protocol"
    target: https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/
    date: 2026-06-27
    seriesinfo:
      Internet-Draft: draft-kavian-agent-enrollment-protocol-00
    author:
      - ins: N. Kavian
        name: N. Kavian

informative:
...

--- abstract

This document defines a Basic session-credential extension for the Agent Enrollment Protocol (AEP).  The extension lets an AEP Service issue an HTTP Basic credential through the AEP Grant command for deployments that already integrate with Basic authentication middleware.

--- middle

# Introduction

AEP session credentials allow a Service to issue a stateful credential after an Agent authenticates with a baseline AEP client assertion {{AEP-CORE}}.  This document defines the `basic` grant type for Services that want to reuse HTTP Basic authentication {{RFC7617}} while preserving AEP key possession as the issuance root.  Extension request and response bodies are JSON objects {{RFC8259}} carried over HTTP semantics {{RFC9110}} as defined by AEP.

This extension does not replace baseline AEP authentication.  Services that implement this extension MUST continue to accept baseline AEP authentication on authenticated AEP commands.

# Requirements Language

{::boilerplate bcp14-tagged}

# Grant Type

The grant type identifier is:

~~~ text
basic
~~~

A Service that supports this extension lists `basic` in `commands.grant_types` and lists `grant` and `revoke` in `commands.supported` in its AEP Inspect document.

# Inspect Configuration

A Service MAY publish configuration under `commands.grant_types_config.basic`:

~~~ json
{
  "commands": {
    "grant_types": ["basic"],
    "grant_types_config": {
      "basic": {
        "default_lifetime_seconds": "86400",
        "realm": "api.example.com",
        "scopes_supported": ["read", "write"],
        "supports_per_credential_revoke": "true"
      }
    },
    "supported": ["enroll", "grant", "inspect", "revoke", "status"]
  }
}
~~~

`default_lifetime_seconds` is an AEP-owned numeric value and is therefore represented as a JSON string.

`realm`, when present, identifies the HTTP Basic realm associated with credentials issued by this extension.

`scopes_supported`, when present, lists Service-defined scope strings an Agent can request.

`supports_per_credential_revoke` is a string boolean.  If absent, the default is `"false"`.  A Service that returns `credential_id` in a Grant response MUST support Revoke with that `credential_id`.  A Service that does not support per-credential Revoke MUST omit `credential_id` from Grant responses.

# Grant Request

The Agent invokes AEP Grant using baseline `Authorization: AEP <jwt>` authentication with `op` equal to `grant`.

~~~ json
{
  "grant_type": "basic",
  "label": "legacy-basic-prod",
  "requested_scopes": ["read"]
}
~~~

`grant_type` MUST be `basic`.

`label` is OPTIONAL and is an Agent-provided display label.  Services MAY ignore it.

`requested_scopes` is OPTIONAL.  A Service MAY grant fewer scopes than requested.  Unsupported requested scopes MAY be omitted from the response `scopes` array.  If the Service cannot issue a useful credential for the requested scopes, it MUST return `invalid_request`.

The Agent does not submit a password.  The Service generates the username and password, or generates the password for a Service-owned username, and returns the credential in the Grant response.

# Grant Response

A successful Grant response is a JSON object:

~~~ json
{
  "credential_id": "bas_01HZY8W7Q2F8J7D3P9G9Z1N6TT",
  "expires_at": "2026-12-01T00:00:00Z",
  "password": "s3cr3tExample",
  "realm": "api.example.com",
  "scopes": ["read"],
  "username": "aep_agent_abc123"
}
~~~

`username` and `password` are REQUIRED.  Agents MUST treat `password` as an opaque secret. Services MUST generate values that can be encoded according to RFC 7617 without lossy transformation. Generated passwords MUST contain at least 128 bits of entropy. Generated usernames and passwords MUST NOT contain control characters.

`expires_at` is REQUIRED and is an RFC 3339 {{RFC3339}} timestamp for credential expiry.

`realm`, when present, identifies the associated HTTP Basic realm.

`scopes` is REQUIRED and contains the granted scope strings.  The Service MAY return an empty array when the Basic credential has no scope-limited authorization.

`credential_id`, when present, is a stable identifier for per-credential Revoke.  If present, the Service MUST support Revoke with this value.

The response does not include the base64-encoded `Authorization` value.  Agents construct that value locally from `username ":" password` according to RFC 7617.

# Credential Presentation

On later HTTP requests, the Agent presents the credential using HTTP Basic authentication:

~~~ http-message
Authorization: Basic YWVwX2FnZW50X2FiYzEyMzpzM2NyM3RFeGFtcGxl
~~~

The encoded value is standard base64 of `username ":" password` as defined by RFC 7617.  This encoding is not AEP's base64url binary convention.

Authenticated AEP command endpoints MUST continue to accept baseline AEP authentication.

# Revoke

The Agent invokes AEP Revoke using baseline `Authorization: AEP <jwt>` authentication with `op` equal to `revoke`.

To revoke all Basic credentials of this type for the authenticated Agent:

~~~ json
{
  "grant_type": "basic"
}
~~~

To revoke one Basic credential when the Service returned `credential_id`:

~~~ json
{
  "credential_id": "bas_01HZY8W7Q2F8J7D3P9G9Z1N6TT",
  "grant_type": "basic"
}
~~~

Revoke returns an empty JSON object on success.  The Service MUST return success regardless of whether a matching credential existed.

To revoke all session credentials of every grant type, Agents use the core `all_grant_types` Revoke request.

# Error Handling

This extension uses the AEP error vocabulary defined by the core protocol.  A Basic credential that is expired, malformed, revoked, unknown, or bound to a different Agent fails as `not_recognized`.

# IANA Considerations

This document requests registration of `basic` in the AEP Grant Types registry.

| Field | Value |
|---|---|
| Grant Type | `basic` |
| Description | HTTP Basic credential issued through AEP Grant |
| Reference | This document |

# Security Considerations

Basic credentials are bearer secrets once encoded into the Authorization header.  Services MUST store passwords using strong password-storage controls.  Services MUST NOT log raw passwords or Authorization header values, and Services MUST support AEP Revoke for every advertised grant type.  Agents that suspect credential disclosure SHOULD call AEP Revoke using baseline AEP authentication and then fall back to per-request signed client assertions until a new credential is issued.

Services SHOULD use a distinct realm or credential store for AEP-issued Basic credentials when the Service also supports human-facing Basic credentials.

# Privacy Considerations

Basic credentials can become correlation handles if reused outside the issuing Service.  Agents MUST NOT present AEP-issued Basic credentials to other Services.  Services MUST NOT log raw passwords or Authorization header values in ordinary logs or telemetry.
