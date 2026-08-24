---
title: "AEP Claim Values"
abbrev: "AEP Claims"
docname: draft-kavian-aep-claims-01
date: 2026-08-24
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
  RFC5321:
  RFC8259:
  RFC3339:
  RFC9110:
  AEP-CORE:
    title: "The Agent Enrollment Protocol"
    target: https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/
    date: 2026-08-24
    seriesinfo:
      Internet-Draft: draft-kavian-agent-enrollment-protocol-03
    author:
      - ins: N. Kavian
        name: N. Kavian

informative:
  RFC8126:
...

--- abstract

This document defines a claim-value catalog for the Agent Enrollment
Protocol (AEP). It specifies stable claim names and forward-compatible JSON
value shapes that Agents can submit during enrollment when requested by a
Service Inspect document.

--- middle

# Introduction

The Agent Enrollment Protocol (AEP) lets a Service advertise claim names in
its Inspect document and lets an Agent submit corresponding claim values in an
Enroll request. AEP core defines the negotiation and HTTP transport mechanics
using HTTP semantics {{RFC9110}}. This document defines interoperable names
and value shapes for common person and contact claims.

The catalog is intentionally small. It gives implementations a common baseline
without making AEP a general identity-proofing, know-your-agent, payments, or
compliance data model. Future documents can define additional claim names and
additional optional members for object-valued claims.

# Requirements Language

{::boilerplate bcp14-tagged}

# Terminology

This document uses the Agent, Service, Owner, Inspect document, and Enroll
terms from AEP core {{AEP-CORE}}. JSON values are encoded as described by
{{RFC8259}}.

Claim Name:
: A dotted lowercase identifier advertised by a Service and used as a member
  name in an Enroll request's `claims` object.

Claim Value:
: The JSON value associated with a Claim Name in an Enroll request.

# Claim Negotiation Model

A Service requests claims by listing Claim Names in `claims.required`,
`claims.preferred`, or `claims.optional` in its Inspect document. An Agent
submits supported Claim Values in the Enroll request `claims` object.

Claim Values submitted during Enroll are assertions made by the Agent or
Owner, unless another AEP document or Service policy requires an attestation,
proof, or asynchronous verification step. The presence of a Claim Value does
not by itself prove that the value is true.

Services MUST NOT require claims absent from their Inspect document for the
same enrollment interaction. Services MAY reject unsupported, malformed, or
policy-disallowed Claim Values with `requirements_unmet` as defined by AEP
core.

# Forward Compatibility

Claim Name registration is additive. A future document MAY define new Claim
Names without changing the meaning of existing Claim Names.

Agents MUST ignore unknown Claim Names in `claims.optional` and
`claims.preferred`. An Agent that does not understand a Claim Name in
`claims.required` cannot satisfy that requirement unless local policy or an
extension supplies support for that Claim Name.

Services MUST ignore unknown submitted Claim Names unless local policy
requires rejection. Services SHOULD reject claim names that are absent from the
Inspect document only when accepting extra values creates a privacy, security,
or compliance risk.

Object-valued claims defined by this document are open to additional members.
Consumers MUST ignore object members they do not understand unless a later
document explicitly changes that rule for a new Claim Name. Adding an optional
member to an existing object-valued claim is non-breaking. Removing a required
member, changing the JSON type of a Claim Value, or changing the meaning of an
existing member is breaking and requires a new Claim Name.

Claim Names defined by this document use unversioned names because the names
identify stable concepts. Versioning belongs in new Claim Names only when the
wire value semantics are incompatible.

# Claim Catalog

This section defines Claim Names for common person and contact information.

## Contact Claims

`contact.email`:
: A string containing an email address for the Owner or Agent operator. The
  value MUST conform to the `Mailbox` rule in Section 4.1.2 of RFC 5321
  {{RFC5321}}, as referenced by the JSON Schema `email` format. The value is
  intended for contact and verification workflows and does not imply that the
  Service has verified control of the mailbox. Syntax validation does not
  establish that the mailbox exists or that the Owner or Agent controls it.

`contact.mobile`:
: A string containing a mobile telephone number in international form. The
  value begins with `+`, followed by 2 to 15 decimal digits, and the first
  digit after `+` is not zero; for example, `+14155550100`. The value is
  intended for contact and verification workflows and does not imply that the
  Service has verified control of the number.

`contact.address.primary`:
: An object containing a primary postal address for the Owner or Agent
  operator. The object fields defined by this document are:

| Member       | Requirement | Description                                                                  |
| ------------ | ----------- | ---------------------------------------------------------------------------- |
| `first_name` | Required    | Non-empty given name of the postal recipient.                                |
| `last_name`  | Required    | Non-empty family name of the postal recipient.                               |
| `line1`      | Required    | Non-empty first address line.                                                |
| `line2`      | Optional    | Second address line.                                                         |
| `line3`      | Optional    | Third address line.                                                          |
| `city`       | Optional    | Non-empty locality or city when present.                                     |
| `region`     | Optional    | State, province, region, or other subdivision.                               |
| `postcode`   | Optional    | Postal or ZIP code.                                                          |
| `country`    | Required    | Two uppercase ASCII letters representing an ISO 3166-1 alpha-2 country code. |

Services MAY validate that `country` is an assigned ISO 3166-1 alpha-2 code
under local policy. The wire-shape requirement is two uppercase ASCII letters.
The legacy `postal_code` member is invalid; implementations MUST use
`postcode`.

The address `first_name` and `last_name` members identify the postal recipient
at that address. They are independent of the `person.first_name` and
`person.last_name` Claims. Implementations MUST NOT substitute those person
Claims when either address member is absent.

# Person Claims

`person.birthdate`:
: A string containing a full-calendar birth date in the RFC 3339 `full-date`
  form, for example `1990-04-12` {{RFC3339}}. The value is a date, not a
  date-time.

`person.first_name`:
: A non-empty string containing the person's given name.

`person.last_name`:
: A non-empty string containing the person's family name.

`person.username`:
: A non-empty string containing a user-selected or system-assigned username
  for the person.

# Example

The following Enroll request fragment shows the Claim Values defined by this
document:

~~~ json
{
  "claims": {
    "contact.address.primary": {
      "city": "San Francisco",
      "country": "US",
      "first_name": "Grace",
      "last_name": "Hopper",
      "line1": "123 Market Street",
      "line3": "Attention: Receiving",
      "postcode": "94105",
      "region": "CA"
    },
    "contact.email": "owner@example.com",
    "contact.mobile": "+14155550100",
    "person.birthdate": "1990-04-12",
    "person.first_name": "Ada",
    "person.last_name": "Lovelace",
    "person.username": "ada"
  }
}
~~~

# IANA Considerations

This document requests creation of the "AEP Claim Names" registry. The
registration policy is Specification Required as defined by RFC 8126
{{RFC8126}}. Designated experts are requested to verify that new registrations
define a stable Claim Name, JSON value type, compatibility behavior, privacy
considerations, and security considerations.

Each entry contains:

| Field       | Description                            |
| ----------- | -------------------------------------- |
| Claim Name  | Dotted lowercase Claim Name.           |
| Value Type  | JSON value type or named object shape. |
| Description | Short claim description.               |
| Reference   | Stable specification reference.        |

The registry contains the following entries:

| Claim Name                | Value Type | Description               | Reference     |
| ------------------------- | ---------- | ------------------------- | ------------- |
| `contact.address.primary` | object     | Primary postal address.   | This document |
| `contact.email`           | string     | Email address.            | This document |
| `contact.mobile`          | string     | Mobile telephone number.  | This document |
| `person.birthdate`        | string     | Full-calendar birth date. | This document |
| `person.first_name`       | string     | Given name.               | This document |
| `person.last_name`        | string     | Family name.              | This document |
| `person.username`         | string     | Username.                 | This document |

# Security Considerations

Claim Values can influence enrollment, protected-resource authorization,
fraud controls, compliance review, and account recovery.
Services MUST NOT treat an unverified Claim Value as independently verified.
When a Service requires proof, it needs an attestation, proof, out-of-band
verification workflow, or local verification procedure appropriate to the risk.

Services SHOULD validate Claim Value syntax before storing or acting on a
value. Services MUST treat claim parsing failures as `requirements_unmet`,
`invalid_request`, or another AEP core error that does not reveal unrelated
identity-recognition state.

Claim Values are submitted through the authenticated and idempotent Enroll
operation defined by AEP core. Implementations MUST apply the authentication,
replay, idempotency, and anti-enumeration requirements from AEP core before
acting on Claim Values. Receiving the same Claim Value through another
unauthenticated interface does not make it an authenticated AEP assertion.

Claim Values can contain attacker-controlled strings. Services and Agents need
ordinary input-handling protections when displaying, storing, logging, or
forwarding values.

Services MUST bound the encoded size, string length, object depth, and member
count they accept under local policy. Audit records SHOULD identify the policy
decision and verification method without copying raw Claim Values.

# Privacy Considerations

Claim Values can contain personal data and contact information. Services
SHOULD request the minimum claims required for the interaction and SHOULD place
non-essential claims in `claims.preferred` or `claims.optional` rather than
`claims.required`.

Agents SHOULD send the minimum Claim Values needed to satisfy the Service's
Inspect document and the Owner's intended interaction. Agents SHOULD avoid
sending birth dates or postal addresses unless those values are requested and
necessary.

Stable contact details, usernames, birth dates, and addresses can correlate an
Owner or Agent across Services. Services SHOULD avoid using Claim Values as
cross-Service identifiers. Agents SHOULD prefer Service-specific values when
the interaction permits them.

Services SHOULD avoid logging raw Claim Values in ordinary logs or telemetry.
When retention is required, Services SHOULD minimize stored values, separate
sensitive data from operational records, and apply access controls appropriate
to personal data.
