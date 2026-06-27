---
title: "API-Key Session Credentials for the Agent Enrollment Protocol"
abbrev: "AEP API Key"
docname: draft-kavian-aep-api-key-session-credential-00
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
  RFC5234:
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

This document defines an API-key session-credential extension for the Agent Enrollment Protocol (AEP).  The extension lets an AEP Service issue an opaque API key through the AEP Grant command for deployments that already operate header-based API-key authentication.

--- middle

# Introduction

AEP session credentials allow a Service to issue a stateful credential after an Agent authenticates with a baseline AEP client assertion {{AEP-CORE}}.  This document defines the `api-key` grant type for Services that want to reuse existing API-key middleware while preserving AEP key possession as the issuance root.  Extension request and response bodies are JSON objects {{RFC8259}} carried over HTTP semantics {{RFC9110}} as defined by AEP.

This extension does not replace baseline AEP authentication.  Services that implement this extension MUST continue to accept baseline AEP authentication on authenticated AEP commands.

# Requirements Language

{::boilerplate bcp14-tagged}

# Grant Type

The grant type identifier is:

~~~ text
api-key
~~~

A Service that supports this extension lists `api-key` in `commands.grant_types` and lists `grant` and `revoke` in `commands.supported` in its AEP Inspect document.

# Inspect Configuration

A Service MAY publish configuration under `commands.grant_types_config.api-key`:

~~~ json
{
  "commands": {
    "grant_types": ["api-key"],
    "grant_types_config": {
      "api-key": {
        "default_lifetime_seconds": "2592000",
        "header_names": ["x-api-key"],
        "scopes_supported": ["read", "write"],
        "supports_per_credential_revoke": "true"
      }
    },
    "supported": ["enroll", "grant", "inspect", "revoke", "status"]
  }
}
~~~

`default_lifetime_seconds` is an AEP-owned numeric value and is therefore represented as a JSON string.

`header_names`, when present, lists HTTP header names the Service can accept for API-key presentation.  Header names are case-insensitive on the wire, but Services SHOULD publish lowercase names.  If absent, the default header name is `x-api-key`.

`scopes_supported`, when present, lists Service-defined scope strings an Agent can request.

`supports_per_credential_revoke` is a string boolean.  If absent, the default is `"false"`.  A Service that returns `credential_id` in a Grant response MUST support Revoke with that `credential_id`.  A Service that does not support per-credential Revoke MUST omit `credential_id` from Grant responses.

# Grant Request

The Agent invokes AEP Grant using baseline `Authorization: AEP <jwt>` authentication with `op` equal to `grant`.

~~~ json
{
  "grant_type": "api-key",
  "label": "agent-prod-read",
  "requested_scopes": ["read"]
}
~~~

`grant_type` MUST be `api-key`.

`label` is OPTIONAL and is an Agent-provided display label.  Services MAY ignore it.

`requested_scopes` is OPTIONAL.  A Service MAY grant fewer scopes than requested.  Unsupported requested scopes MAY be omitted from the response `scopes` array.  If the Service cannot issue a useful credential for the requested scopes, it MUST return `invalid_request`.

# Grant Response

A successful Grant response is a JSON object:

~~~ json
{
  "api_key": "aep_live_7Jm5Example",
  "credential_id": "key_01HZY8W7Q2F8J7D3P9G9Z1N6TT",
  "expires_at": "2026-12-01T00:00:00Z",
  "header": "x-api-key",
  "scopes": ["read"]
}
~~~

`api_key` is REQUIRED and contains the opaque API key value. Services MUST generate API key values with at least 128 bits of entropy. Agents MUST treat the value as an opaque bearer secret.

API key values MUST match the following syntax. Numeric character values and repetition operators are defined by RFC 5234 {{RFC5234}}.

~~~ abnf
api-key-value = 1*(%x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E)
~~~

This syntax permits visible ASCII characters while excluding whitespace, control characters, double quote, comma, semicolon, and backslash. The restricted character set avoids header parsing ambiguity when API keys are presented in HTTP field values.

`header` is REQUIRED and identifies the HTTP header used for presentation.  When `header_names` is advertised, the value MUST be one of the advertised names.

`expires_at` is REQUIRED and is an RFC 3339 {{RFC3339}} timestamp for credential expiry.

`scopes` is REQUIRED and contains the granted scope strings.  The Service MAY return an empty array when the API key has no scope-limited authorization.

`credential_id`, when present, is a stable identifier for per-key Revoke.  If present, the Service MUST support Revoke with this value.

Services MUST issue expiring API keys.

# Credential Presentation

On later HTTP requests, the Agent presents the API key in the response-selected header:

~~~ http-message
x-api-key: aep_live_7Jm5Example
~~~

Authenticated AEP command endpoints MUST continue to accept baseline AEP authentication.

# Revoke

The Agent invokes AEP Revoke using baseline `Authorization: AEP <jwt>` authentication with `op` equal to `revoke`.

To revoke all API keys of this type for the authenticated Agent:

~~~ json
{
  "grant_type": "api-key"
}
~~~

To revoke one API key when the Service returned `credential_id`:

~~~ json
{
  "credential_id": "key_01HZY8W7Q2F8J7D3P9G9Z1N6TT",
  "grant_type": "api-key"
}
~~~

Revoke returns an empty JSON object on success.  The Service MUST return success regardless of whether a matching key existed.

To revoke all session credentials of every grant type, Agents use the core `all_grant_types` Revoke request.

# Error Handling

This extension uses the AEP error vocabulary defined by the core protocol.  An API key that is expired, malformed, revoked, unknown, or bound to a different Agent fails as `not_recognized`.

# IANA Considerations

This document requests registration of `api-key` in the AEP Grant Types registry.

| Field | Value |
|---|---|
| Grant Type | `api-key` |
| Description | Opaque API key issued through AEP Grant |
| Reference | This document |

# Security Considerations

API keys are bearer secrets.  Services MUST store only salted hashes or equivalent one-way verifiers.  Services MUST NOT log raw API-key values, and Services MUST support AEP Revoke for every advertised grant type.  Agents that suspect key disclosure SHOULD call AEP Revoke using baseline AEP authentication and then fall back to per-request signed client assertions until a new key is issued.

Services MUST validate only the configured API-key header for this extension.  Services SHOULD reject ambiguous requests that present multiple API-key headers or multiple non-baseline bearer credentials when that ambiguity would affect authorization semantics.

# Privacy Considerations

API keys can become correlation handles if reused outside the issuing Service.  Agents MUST NOT present AEP-issued API keys to other Services.  Services MUST NOT log raw API-key values in ordinary logs or telemetry.
