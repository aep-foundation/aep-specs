---
title: "The did:web Identity Method for the Agent Enrollment Protocol"
abbrev: "AEP did:web"
docname: draft-kavian-aep-did-web-identity-method-00
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
  DID-WEB:
    title: "The did:web Method Specification"
    target: https://w3c-ccg.github.io/did-method-web/
    author:
      - org: W3C Credentials Community Group
  AEP-CORE:
    title: "The Agent Enrollment Protocol"
    target: https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/
    date: 2026-06-27
    seriesinfo:
      Internet-Draft: draft-kavian-agent-enrollment-protocol-01
    author:
      - ins: N. Kavian
        name: N. Kavian

informative:
...

--- abstract

This document defines the `did:web` identity method for the Agent Enrollment Protocol (AEP). The method lets an AEP Service verify Agent client assertion JWTs by resolving an Agent `did:web` identifier to a DID document published over HTTPS.

--- middle

# Introduction

The Agent Enrollment Protocol (AEP) defines an identity-method substrate for authenticated commands {{AEP-CORE}}. AEP Services advertise enabled identity methods in the Inspect document's `identity.methods` array.

This document defines the `did:web` identity method. A Service that enables this identity method accepts Agent identifiers using the `did:web` DID method {{DID-WEB}} and resolves verification material from the corresponding HTTPS origin.

# Requirements Language

{::boilerplate bcp14-tagged}

# Identity Method

The identity method identifier is:

~~~ text
did:web
~~~

A Service that enables this identity method lists `did:web` in the Inspect document:

~~~ json
{
  "identity": {
    "methods": ["did:web"]
  }
}
~~~

Services that do not enable this identity method MUST NOT list `did:web` in `identity.methods`.

# Agent Identifiers

An Agent using this identity method identifies itself with a `did:web` URI.

The Agent DID appears in the client assertion JWT `iss` and `sub` claims. The JOSE `kid` header contains the Agent DID and MAY include a fragment selecting a verification method in the resolved DID document.

~~~ json
{
  "alg": "EdDSA",
  "typ": "JWT",
  "kid": "did:web:agent.example.com:agents:123#key-1"
}
~~~

~~~ json
{
  "iss": "did:web:agent.example.com:agents:123",
  "sub": "did:web:agent.example.com:agents:123"
}
~~~

The DID portion of `kid` MUST equal the Agent DID carried in `iss` and `sub`.

# DID Resolution

The Service resolves the Agent DID according to the `did:web` method specification {{DID-WEB}}:

* `did:web:<host>` resolves to `https://<host>/.well-known/did.json`.
* `did:web:<host>:<path>` resolves to `https://<host>/<path>/did.json`.

Services MUST resolve `did:web` documents over HTTPS. Plaintext HTTP resolution is not allowed.

The resolved DID document MUST be a JSON object {{RFC8259}} and MUST contain a verification method referenced by the JWT `kid` header. The verification method MUST expose a public key in a form the Service can validate against the selected JOSE signing algorithm.

If the Service cannot resolve the DID document, cannot locate the referenced verification method, or cannot use the verification method with the selected JOSE algorithm, client assertion verification fails with the AEP `not_recognized` error defined by the core protocol.

# Caching

Services SHOULD cache resolved DID documents and SHOULD honor upstream HTTP cache metadata {{RFC9110}}. A default cache lifetime of 300 seconds is RECOMMENDED when no shorter upstream lifetime is provided.

Services MUST ensure that cache lifetimes do not prevent timely key replacement after compromise. Services MAY impose a local maximum cache lifetime.

# IANA Considerations

This document requests registration of `did:web` in the AEP Identity Methods registry.

| Field           | Value                                             |
| --------------- | ------------------------------------------------- |
| Identity Method | `did:web`                                         |
| Description     | DID Web identity method for AEP client assertions |
| Reference       | This document                                     |

# Security Considerations

The `did:web` method relies on the HTTPS origin that publishes the DID document. A Service that accepts an Agent's `did:web` identity trusts the corresponding web origin to publish the correct verification method.

Services MUST reject `did:web` client assertions when the resolved DID document does not contain the verification method referenced by `kid`, when the verification method cannot validate the selected JOSE algorithm, or when the JWT signature does not verify.

Services SHOULD cache DID documents for operational stability but MUST ensure that cache lifetimes do not prevent timely key replacement after compromise.

# Privacy Considerations

A `did:web` Agent identity can be correlatable if the same DID is reused across Services. Platforms or Agent operators that require unlinkability SHOULD use a distinct `did:web` URI and signing key per Service enrollment.

The URI path component SHOULD be opaque and SHOULD NOT reveal the Agent's master identity, account identifier, or target Service.
