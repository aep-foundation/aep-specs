---
title: "[Core Draft Title]"
abbrev: "[Short Name]"
docname: draft-kavian-[topic]-00
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
  RFC8174:
  RFC8259:
  RFC9110:

informative:
...

--- abstract

This document defines [one-sentence protocol function] for the Agent
Enrollment Protocol (AEP). It specifies [main wire surfaces] for autonomous
Agents and Services that implement AEP.

--- middle

# Introduction

The Agent Enrollment Protocol (AEP) defines machine-first enrollment and
authentication for autonomous Agents. This document defines [scope] and is limited
to behavior needed for interoperable implementation.

This document does not define [explicit exclusions]. Those capabilities are
specified by separate AEP documents when they are needed.

# Requirements Language

{::boilerplate bcp14-tagged}

# Terminology

Agent:
: Software acting autonomously. An Agent holds or controls a cryptographic key
  and initiates AEP requests.

Service:
: The HTTP server that receives AEP requests.

[New Term]:
: [Definition used by this document.]

# Protocol Overview

[Describe the shortest complete protocol flow. Name the actor that sends each
message and the actor that verifies it.]

1. The Agent [first action].
2. The Service [verification or response].
3. The Agent [next action].

# Wire Format

Requests and successful responses that carry AEP JSON payloads use
`application/aep+json` unless this document explicitly defines another media type.

~~~ json
{
  "field_name": "value"
}
~~~

`field_name` [defines the field semantics and validation rules].

# Error Handling

This document uses the AEP error vocabulary defined by the core protocol. When a
failure would reveal whether an Agent identity, credential, or record exists,
the Service returns `not_recognized`.

# IANA Considerations

This document requests [registry creation or registration]. If this document
does not require IANA action, replace this paragraph with:

This document has no IANA actions.

# Security Considerations

Implementations MUST enforce the authentication and authorization checks
defined by this document before processing state-changing requests.

Services SHOULD rate-limit requests that can be used for probing or resource
exhaustion. Error responses MUST NOT reveal internal identity-recognition
details.

# Privacy Considerations

Implementations SHOULD minimize disclosure of Agent and Owner information.
Services MUST NOT log raw credential values in ordinary logs or telemetry.
Services SHOULD avoid logging unnecessary claim values.
