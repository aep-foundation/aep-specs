---
title: "[Extension Name] for the Agent Enrollment Protocol"
abbrev: "AEP [Extension]"
docname: draft-kavian-aep-[extension-name]-00
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
    organization: InFlow
    email: nas@inflowpay.ai

normative:
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

This document defines [extension capability] for the Agent Enrollment Protocol
(AEP). The extension adds [wire-visible behavior] while preserving baseline AEP
authentication and discovery semantics.

--- middle

# Introduction

AEP extensions add optional protocol capabilities on top of the AEP core. This
document defines [extension name], which lets a Service advertise [capability]
and lets an Agent invoke [behavior] when the Service supports it.

This extension does not replace baseline AEP authentication. Services that
implement this extension MUST continue to accept baseline AEP authentication on
authenticated AEP commands unless the core protocol says otherwise.

# Requirements Language

{::boilerplate bcp14-tagged}

# Relationship to AEP Core

This extension depends on the AEP core document for:

- Inspect discovery.
- Baseline client assertion authentication.
- Error handling.
- Extension advertisement.

Services advertise this extension in the Inspect document. Agents that do not
understand this extension ignore the advertisement unless local policy requires
the capability.

# Inspect Advertisement

A Service that supports this extension advertises the extension identifier in
`extensions.supported` and publishes extension-specific configuration under the
field defined by this document.

~~~ json
{
  "extensions": {
    "supported": ["urn:aep:ext:aep-foundation:[name]#v=1.0.0"]
  }
}
~~~

# Request Behavior

[Define the command, endpoint, request fields, and authentication requirements.]

~~~ json
{
  "field_name": "value"
}
~~~

# Response Behavior

[Define the success response shape and validation rules.]

~~~ json
{
  "status": "accepted"
}
~~~

# Error Handling

This extension uses the AEP error vocabulary defined by the core protocol. If
this extension defines additional errors, register them in the AEP Error Codes
registry and describe how they avoid identity-enumeration leaks.

# IANA Considerations

This document requests registration of
`urn:aep:ext:aep-foundation:[name]#v=1.0.0` in the AEP Extension Registry.

| Field                | Value                                       |
|----------------------|---------------------------------------------|
| Extension Identifier | `urn:aep:ext:aep-foundation:[name]#v=1.0.0` |
| Description          | [Short description]                         |
| Reference            | This document                               |

# Security Considerations

Implementations MUST validate that the authenticated Agent is authorized to use
this extension before processing state-changing behavior.

Services SHOULD rate-limit extension endpoints or command paths that can be
used for probing or resource exhaustion. Extension errors MUST NOT disclose
whether an Agent identity, credential, or private record exists unless the core
protocol already permits that disclosure.

# Privacy Considerations

Extensions SHOULD minimize disclosure of Agent and Owner information. Services
MUST NOT log raw credential values in ordinary logs or telemetry. Services
SHOULD avoid logging unnecessary claim values.
