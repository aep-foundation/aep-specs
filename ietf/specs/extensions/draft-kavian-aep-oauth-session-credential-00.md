---
title: "OAuth Bearer Session Credentials for the Agent Enrollment Protocol"
abbrev: "AEP OAuth"
docname: draft-kavian-aep-oauth-session-credential-00
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
  RFC6750:
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
  RFC7009:
  RFC7662:
...

--- abstract

This document defines an OAuth Bearer session-credential extension for the Agent Enrollment Protocol (AEP).  The extension lets an AEP Service issue an OAuth-style Bearer access token through the AEP Grant command while preserving baseline AEP client assertion authentication as the root of trust.

--- middle

# Introduction

The Agent Enrollment Protocol (AEP) defines Grant and Revoke commands for optional session credentials {{AEP-CORE}}.  Session credentials are an optimization for deployments that want to reuse existing authentication middleware after an Agent has proven possession of its AEP identity key.

This document defines the `oauth-bearer` grant type.  The grant type issues an OAuth Bearer access token {{RFC6750}} through the AEP Grant command.  Extension request and response bodies are JSON objects {{RFC8259}} carried over HTTP semantics {{RFC9110}} as defined by AEP.  This extension does not redefine OAuth authorization grants, refresh tokens, token introspection, or token revocation.  When a Service exposes standard OAuth token introspection {{RFC7662}} or revocation {{RFC7009}} endpoints, it advertises those endpoints as extension configuration.

# Requirements Language

{::boilerplate bcp14-tagged}

# Grant Type

The grant type identifier is:

~~~ text
oauth-bearer
~~~

A Service that supports this extension lists `oauth-bearer` in `commands.grant_types` and lists `grant` and `revoke` in `commands.supported` in its AEP Inspect document.

# Inspect Configuration

A Service MAY publish configuration under `commands.grant_types_config.oauth-bearer`:

~~~ json
{
  "commands": {
    "grant_types": ["oauth-bearer"],
    "grant_types_config": {
      "oauth-bearer": {
        "access_token_formats": ["opaque"],
        "default_lifetime_seconds": "900",
        "introspection_endpoint": "https://api.example.com/i",
        "revocation_endpoint": "https://api.example.com/r",
        "scopes_supported": ["read", "write"],
        "supports_per_credential_revoke": "true"
      }
    },
    "supported": ["enroll", "grant", "inspect", "revoke", "status"]
  }
}
~~~

`access_token_formats` is an array of strings.  This document defines `opaque` and `jwt` as descriptive values.  Agents MUST treat returned access tokens as opaque regardless of the advertised format.

`default_lifetime_seconds` is an AEP-owned numeric value and is therefore represented as a JSON string.

`introspection_endpoint` and `revocation_endpoint`, when present, are HTTPS URLs for standard OAuth operational tooling.  AEP-aware Agents use AEP Revoke for AEP-issued session credentials.

`scopes_supported`, when present, lists Service-defined scope strings an Agent can request.

`supports_per_credential_revoke` is a string boolean.  If absent, the default is `"false"`.  A Service that returns `credential_id` in a Grant response MUST support Revoke with that `credential_id`.  A Service that does not support per-credential Revoke MUST omit `credential_id` from Grant responses.

# Grant Request

The Agent invokes AEP Grant using baseline `Authorization: AEP <jwt>` authentication with `op` equal to `grant`.

~~~ json
{
  "grant_type": "oauth-bearer",
  "requested_scopes": ["read"],
  "token_format": "opaque"
}
~~~

`grant_type` MUST be `oauth-bearer`.

`requested_scopes` is OPTIONAL.  A Service MAY grant fewer scopes than requested.  Unsupported requested scopes MAY be omitted from the response `scopes` array.  If the Service cannot issue a useful credential for the requested scopes, it MUST return `invalid_request`.

`token_format` is OPTIONAL.  The values defined by this document are `opaque` and `jwt`.  A Service MAY ignore this preference.

# Grant Response

A successful Grant response is a JSON object:

~~~ json
{
  "access_token": "ya29.example",
  "credential_id": "tok_01HZY8W7Q2F8J7D3P9G9Z1N6TT",
  "expires_at": "2026-12-01T00:00:00Z",
  "scopes": ["read"],
  "token_format": "opaque",
  "token_type": "Bearer"
}
~~~

`access_token` is REQUIRED and contains the Bearer token value.

`token_type` is REQUIRED and MUST be `Bearer`.

`expires_at` is REQUIRED and is an RFC 3339 {{RFC3339}} timestamp for credential expiry.

`scopes` is REQUIRED and contains the granted scope strings.  The Service MAY return an empty array when the token has no scope-limited authorization.

`token_format`, when present, describes the Service-selected format.

`credential_id`, when present, is a stable identifier for per-token Revoke.  If present, the Service MUST support Revoke with this value.

This document does not define refresh tokens.  Agents renew by invoking AEP Grant again with a fresh baseline client assertion.

# Credential Presentation

On later HTTP requests, the Agent presents the token using the Bearer authentication scheme:

~~~ http-message
Authorization: Bearer ya29.example
~~~

Authenticated AEP command endpoints MUST continue to accept baseline AEP authentication.

# Revoke

The Agent invokes AEP Revoke using baseline `Authorization: AEP <jwt>` authentication with `op` equal to `revoke`.

To revoke all OAuth Bearer session credentials of this type for the authenticated Agent:

~~~ json
{
  "grant_type": "oauth-bearer"
}
~~~

To revoke one credential when the Service returned `credential_id`:

~~~ json
{
  "credential_id": "tok_01HZY8W7Q2F8J7D3P9G9Z1N6TT",
  "grant_type": "oauth-bearer"
}
~~~

Revoke returns an empty JSON object on success.  The Service MUST return success regardless of whether a matching token existed.

To revoke all session credentials of every grant type, Agents use the core `all_grant_types` Revoke request.

# Error Handling

This extension uses the AEP error vocabulary defined by the core protocol.  A token that is expired, malformed, revoked, unknown, or bound to a different Agent fails as `not_recognized`.

# IANA Considerations

This document requests registration of `oauth-bearer` in the AEP Grant Types registry.

| Field | Value |
|---|---|
| Grant Type | `oauth-bearer` |
| Description | OAuth Bearer access token issued through AEP Grant |
| Reference | This document |

# Security Considerations

Bearer tokens are usable by any party that presents them.  Services SHOULD issue short-lived tokens.  Services MUST NOT log raw access token values, and Services MUST support AEP Revoke for every advertised grant type.  Agents that suspect token disclosure SHOULD call AEP Revoke using baseline AEP authentication and then fall back to per-request signed client assertions until a new token is issued.

Services MUST bind issued tokens to the authenticated AEP Agent identity.  JWT access tokens SHOULD include an audience identifying the issuing Service.  Services MUST reject tokens whose audience does not identify the receiving Service.

# Privacy Considerations

Bearer tokens can become correlation handles if reused outside the issuing Service.  Agents MUST NOT present AEP-issued Bearer tokens to other Services.  Services MUST NOT log raw access token values in ordinary logs or telemetry.
