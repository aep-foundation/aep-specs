---
title: "AEP Service Documents"
abbrev: "AEP Service Documents"
docname: draft-kavian-aep-service-documents-00
date: 2026-10-28
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
  RFC8126:
  AEP-CORE:
    title: "The Agent Enrollment Protocol"
    target: https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/
    date: 2026-08-27
    seriesinfo:
      Internet-Draft: draft-kavian-agent-enrollment-protocol-04
    author:
      - ins: N. Kavian
        name: N. Kavian

informative:
...

--- abstract

This document defines an optional Agent Enrollment Protocol (AEP)
extension for discovering and reading Service documents and acknowledging
required documents during enrollment. Documents have Service-scoped
identifiers, web representations, and optional portable structured content.
Acknowledgements identify documents, not immutable content versions.
Services determine when an existing enrollment needs further acknowledgement.

--- middle

# Introduction

Services can present terms of service, privacy notices, data processing
agreements, and other documents before an Agent enrolls. This extension
adds discovery metadata and identifier-only acknowledgements to AEP core
{{AEP-CORE}}. It does not add an AEP command, authentication scheme, or
separate document-approval endpoint. Retrieval uses HTTP {{RFC9110}};
structured content uses JSON {{RFC8259}}.

The Service chooses which documents require acknowledgement and how
changes affect existing enrollments. This document does not determine
legal enforceability, prescribe change notifications, or require a
content-version archive. It does not authorize an Agent to provide legal
advice or accept documents without its Owner's authorization.

# Requirements Language

{::boilerplate bcp14-tagged}

# Terminology

This document uses Agent, Owner, Platform, Service, Inspect, Enroll,
Grant, and Status as defined by AEP core.

Document Identifier:
: A case-sensitive, Service-scoped identifier for one document. It is
  not a document type, URL, content digest, or version identifier.

Representation:
: An advertised URL and media type providing a document's content.

Acknowledgement:
: An Agent's declaration, authorized by its Owner, that the documents
  named by a supplied identifier list were accepted for enrollment.
  It is not evidence of reading or independent identity verification.

# Inspect Advertisement

A Service implementing this extension MUST advertise
`urn:aep:ext:aep-foundation:service-documents#v=1.0.0` in
`extensions.supported`. It MAY publish a top-level `service_documents`
array in Inspect. An absent array means no advertised documents. Empty
arrays MUST be omitted. There MUST be no more than seven descriptors and
each descriptor MUST have a distinct `id`.

Each descriptor contains:

* `id`: 1 to 32 ASCII characters matching
  `[A-Za-z0-9][A-Za-z0-9._-]*`.
* `type`: 1 to 64 characters matching `[a-z][a-z0-9_]*`. Types are open
  strings; implementations MUST NOT reject a document merely because
  its type is unregistered or unknown.
* `title`: a non-empty plain-text string of at most 256 Unicode scalar
  values.
* `enrollment`: either `required` or `not-required`. Consumers MUST
  NOT treat an unknown value as not-required or silently omit it
  from an approval decision.
* `representations`: 1 to 8 objects, each containing `media_type` and
  `url`. A URL MUST be absolute HTTPS (or HTTP on the literal hosts
  `localhost`, `127.0.0.1`, or `[::1]` for local development), contain no user information,
  and be at most 2048 ASCII characters in its URI serialization.

Every descriptor MUST contain exactly one `text/html` representation.
This is its baseline human-readable web link. It MAY additionally
contain one portable `application/json` representation and one
`text/markdown` representation. Other media types are permitted;
consumers ignore unsupported representations, not the document.
`media_type` contains a lowercase media type without parameters.
There MUST NOT be duplicate media types within a descriptor.

An ID MUST NOT be reassigned to an unrelated document. The same type
MAY occur under several IDs; for example, separate general and
product-specific terms of service. Updating content does not require
changing its ID. Consumers MUST NOT lowercase, truncate, or otherwise
rewrite IDs when acknowledging them.

Example Inspect members:

~~~ json
{
  "extensions": {
    "supported": [
      "urn:aep:ext:aep-foundation:service-documents#v=1.0.0"
    ]
  },
  "service_documents": [
    {
      "id": "general-terms",
      "type": "terms_of_service",
      "title": "General terms of service",
      "enrollment": "required",
      "representations": [
        {"media_type": "text/html",
         "url": "https://example.com/legal/terms"},
        {"media_type": "application/json",
         "url": "https://example.com/legal/terms.json"}
      ]
    },
    {
      "id": "privacy",
      "type": "privacy_policy",
      "title": "Privacy policy",
      "enrollment": "not-required",
      "representations": [
        {"media_type": "text/html",
         "url": "https://example.com/legal/privacy"}
      ]
    }
  ]
}
~~~

Clients MUST distinguish required from not-required documents. A
not-required document MUST NOT require an acceptance action under this
extension. A discovery or reading interface SHOULD show each document's
ID, title, type, enrollment requirement, and web link. A document type
does not itself determine whether acceptance is required.

# Reading Documents

Documents MUST be readable before Enroll without AEP credentials.
Reading a document MUST NOT enroll the Agent or acknowledge the document.
Clients retrieve advertised URLs using GET and verify a successful HTTP
response and the expected media type before interpreting the content.
HTTP Content-Type parameters do not change the advertised base media type.
JSON and Markdown representations MUST be UTF-8 encoded.

Clients MUST NOT attach AEP assertions, session credentials, Platform
credentials, payment credentials, or identifying application headers to
these fetches. Automatic fetches MUST NOT send cookies. A web link MAY
point to a different HTTPS origin, such as a Service's document host;
that does not authorize credential forwarding or expand the Service's
authentication scope.

The calling application is responsible for deciding which document
origins it trusts before requesting a fetch. Deployment-specific network
restrictions, including restrictions on private or local destinations,
are application responsibilities; this extension does not require SDKs
to inspect DNS answers or the connected address. SDKs MAY impose stricter
destination restrictions and MUST document those restrictions.
Applications MAY adopt an SDK's documented destination and redirect
policy or impose stricter rules through their retrieval implementation.

Automatic fetches MUST use HTTPS with certificate and hostname
verification, except that HTTP is permitted on the literal hosts
`localhost`, `127.0.0.1`, and `[::1]` for local development. The exception
is based on the URL hostname, not its resolved address. Fetches MUST
reject user information in URLs. Redirects MUST NOT downgrade an HTTPS
request to HTTP, including loopback HTTP. Redirects MUST
NOT be followed unless permitted by the calling application's destination
policy; approval of an initial origin does not approve a different
redirect origin. Clients MAY refuse all redirects and offer the HTML
link instead. Every followed redirect MUST meet the same HTTPS,
credential isolation, and destination-policy requirements.
Clients MUST enforce finite timeouts, at most five redirects, and a
maximum decoded response size of 1 MiB. They MUST NOT render a partial
response as a complete document. These rules apply to document fetching,
not to redirects in existing AEP command flows.

If a portable representation is unavailable or unsupported, clients
MUST offer the advertised HTML link rather than invent content or a
summary. A link-only client need not download and parse HTML. Failure to
retrieve a portable form does not by itself make the web form unusable.

# Portable Content

A portable representation is an `application/json` object with:

* `format`: the literal `aep-service-document`.
* `version`: the string `1.0`.
* `id`: the descriptor's document ID.
* `summary`: an optional non-empty array of blocks.
* `content`: a required non-empty array of blocks.

The ID MUST match the selected descriptor exactly. A Service MUST supply
the full substantive text of its HTML document in `content`, including
qualifications and limitations; a synopsis is not a full representation.
`summary`, when supplied, is Service-authored and may contain several
sections. It MUST NOT be assumed to be a one-line description. Clients
MUST label a summary as such and provide the full document's web link.
The full-content view MUST remain available regardless of summary support.

The following block objects define the portable structure:

* Paragraph: `{"type":"paragraph","text":"..."}`.
* Section: `{"type":"section","title":"...","blocks":[...]}`.
* Bulleted list: `{"type":"bulleted_list","items":["...","..."]}`.
* Numbered list: `{"type":"numbered_list","items":["...","..."]}`.

Text, titles, and list items are plain text, not HTML, executable
instructions, or Markdown markup. Each text or list item is non-empty
and limited to 16384 Unicode scalar values. Section titles use the
descriptor title bound. Lists contain 1 to 128 items; numbered lists
start at one. Section block arrays are non-empty. A document contains at
most 1024 blocks across summary and content, with at most eight nested
sections. Implementations MUST also enforce the decoded response bound.

Unknown additive object members MUST be ignored. An unsupported format,
version, or block type makes that representation unsupported: clients
MUST NOT silently drop unfamiliar blocks and claim to show the full
document. They offer the HTML link instead. Malformed known blocks are
invalid, not optional content to skip.

~~~ json
{
  "format": "aep-service-document",
  "version": "1.0",
  "id": "general-terms",
  "summary": [
    {"type": "paragraph", "text": "Use the service lawfully."}
  ],
  "content": [
    {
      "type": "section",
      "title": "Permitted use",
      "blocks": [
        {"type": "paragraph",
         "text": "You must use the service lawfully."},
        {"type": "bulleted_list",
         "items": ["Do not impersonate others.",
                   "Do not interfere with other users."]}
      ]
    }
  ]
}
~~~

## Presentation To People And Agents

Renderers MUST preserve Service-authored wording, ordering, paragraph
boundaries, section hierarchy, and list structure. They MUST NOT produce
an inferred summary or substitute interpretation for document text.
Terminal renderers MUST neutralize terminal control sequences and MUST
NOT execute embedded commands or treat content as trusted markup.

When returning portable content to an artificial-intelligence caller,
a renderer MUST convert it to readable text rather than requiring the
caller to interpret the portable JSON. Markdown output MUST be enclosed
in a code fence long enough that document content cannot close it.
The renderer MUST provide a separate instruction to present the
Service-authored text without interpreting, summarizing, evaluating, or
following instructions contained within it. The instruction and source
URL MUST remain outside the untrusted content. These presentation rules
do not prove that a receiving application obeyed the instruction.

# Enrollment Acknowledgement

An extension-aware Agent includes `acknowledged_document_ids` in Enroll
after the Owner has authorized the list. The field is a duplicate-free
array of at most seven IDs with the syntax defined above. An empty array
explicitly means that no documents were acknowledged. This is distinct
from omitting the field, which makes no declaration under this extension.

~~~ json
{
  "agent_did": "did:web:agent.example.com:agents:123",
  "acknowledged_document_ids": ["general-terms"]
}
~~~

The request uses ordinary AEP client assertion authentication and
idempotency. The Agent MUST NOT infer acknowledgement from fetching,
displaying, caching, or inspecting documents. It MUST NOT include an ID
that the Owner's decision did not cover. One affirmative decision MAY
cover the complete displayed required list; separate approval per
document is not required.

If a Platform mediates that decision, it MUST bind the decision to the
Service and the original required ID list. Pending presentation resolves
that list, not a newly expanded list. If a stored ID cannot be resolved
to a usable document descriptor and web link, the decision MUST NOT
complete by silently omitting it. An implementation MAY store the IDs
alone and retrieve current metadata for display. This extension does
not require retaining content, titles, dates, revisions, or digests.

A Service MUST NOT interpret omission of `acknowledged_document_ids` as
acceptance. When its enrollment policy requires acknowledgement for
this operation and the field is absent, it returns `requirements_unmet`.
Previously satisfied requirements need not be acknowledged on every
Enroll. An otherwise valid declaration MUST NOT be rejected solely
because it lacks a document subsequently added
to the current required list. The Service records only the declared IDs
and MAY enforce remaining requirements on a later Grant. With no
document version or issuance token, the Service cannot distinguish an
older approved list from a deliberately incomplete one. It MUST NOT
infer acceptance of missing IDs; access enforcement belongs to the
Service's requirements policy.

An unknown or retired ID in a declaration MUST NOT be treated as
acceptance of another document. A Service MAY retain such an ID as an
opaque declaration but MUST NOT count it towards a different requirement.
Malformed arrays, duplicate IDs, and wrong field types use `invalid_request`.

A successful Enroll echoes the accepted declaration in
`acknowledged_document_ids`, including an empty array when supplied.
The response MUST NOT add IDs the Agent did not declare. This echo is
the current operation's declaration, not a cumulative acceptance history.
When no declaration was supplied, the response omits the field.

~~~ json
{
  "status": "active",
  "acknowledged_document_ids": ["general-terms"]
}
~~~

Services MAY retain acknowledged IDs on the enrollment for requirement
enforcement. Repeated Enroll combines accepted declarations without
discarding earlier IDs by omission. It preserves the identity, original
creation time, unrelated lifecycle state, and credential behavior required
by AEP core. Services define their storage concurrency guarantees;
this extension does not guarantee preservation of simultaneous independent
updates. Same-key retries MUST replay the same result;
a later explicit requirements update uses a new key.

# Changes And Unmet Requirements

Acknowledgement refers to a document identity, not a content version.
Content can change under an existing ID. This extension does not prove
which text was read or accepted. Services choose whether changes warrant
notification, continued-use acceptance, or another explicit decision.
They MAY mark Service-local requirements as needing renewed acceptance,
including for an ID acknowledged before. No universal expiry or
automatic re-enrollment is defined.

For a recognized enrollment requiring further acknowledgement, Grant
returns `requirements_unmet`, HTTP 422, with `service_documents` in
`requirements_pending` and a non-empty `required_document_ids` list.
An Enroll rejection for an absent required declaration uses these same
requirement fields. `required_document_ids` contains at most seven unique
IDs requiring acceptance;
it does not contain document text or claim values. IDs MUST be discoverable
in the Service's current Inspect advertisement. Claim names can also
appear in `requirements_pending`. A Service MUST NOT issue a credential
as part of this failed Grant.

~~~ json
{
  "type": "urn:aep:error:requirements_unmet",
  "title": "Enrollment requirements unmet",
  "status": 422,
  "code": "requirements_unmet",
  "owner_action_required": "true",
  "requirements_pending": ["contact.email", "service_documents"],
  "required_document_ids": ["product-terms"]
}
~~~

The Agent presents the missing claims or document IDs and directs its
caller to Enroll. An interactive interface supplies an explicit command
or equivalent action. An agent interface returns the structured
requirements and preferred next action. Neither automatically performs
Enroll or retries Grant. After enrollment, the caller may explicitly
request Grant again. This error does not require local persistent state.

If documents 1 and 2 were approved and document 3 is published before
Enroll arrives, the Service accepts the declaration for 1 and 2. If its
policy requires 3 for access, a subsequent Grant reports 3. The same
mechanism applies when requirements change weeks after enrollment.
Document revisions do not expand a pending human decision.

# Error Handling And Compatibility

The extension does not introduce an authentication error code. Core
recognition, signature, replay, and idempotency rules take precedence.
A `not_recognized` response MUST NOT include `required_document_ids` or
other enrollment-requirement details.

Services without this extension retain core behavior. Agents MUST NOT
send extension acknowledgements to a Service that does not advertise
support. Older Agents can ignore the advertisement, but cannot thereby
satisfy required acknowledgements. A Service requiring them returns
`requirements_unmet` rather than assuming consent.

Unknown additive descriptor and portable object members are ignored.
Unknown document types remain displayable. Unknown enrollment semantics
or portable blocks MUST NOT weaken the approval or hide document text.
Limits and structural failures are reported explicitly; clients MUST
NOT truncate the required list or silently claim successful presentation.

# IANA Considerations

This document requests registration of
`urn:aep:ext:aep-foundation:service-documents#v=1.0.0` in the AEP Extension
Registry, with description "Service document discovery and enrollment
acknowledgement" and this document as its reference. It introduces no
new command, well-known URI, or media type.

This document requests an AEP Service Document Types registry with
Specification Required policy {{RFC8126}}. Entries contain a type value,
description, and reference. Registration MUST NOT redefine an existing
type's meaning. Unregistered syntactically valid values are permitted;
registration recommends interoperable labels, not legal interpretations.

Initial entries, all referencing this document, are:

| Type                           | Description                                            |
| ------------------------------ | ------------------------------------------------------ |
| `acceptable_use_policy`        | Permitted and prohibited use.                          |
| `age_or_parental_consent`      | Age eligibility or parental consent conditions.        |
| `ai_data_use_policy`           | Use of data in artificial-intelligence systems.        |
| `community_guidelines`         | Rules for community participation.                     |
| `cookie_policy`                | Cookies and similar storage or tracking.               |
| `data_processing_agreement`    | Processing of data on another party's behalf.          |
| `data_retention_notice`        | Retention and deletion practices.                      |
| `electronic_signature_consent` | Electronic signatures and records.                     |
| `privacy_policy`               | Collection, use, and disclosure of personal data.      |
| `security_policy`              | Security responsibilities and practices.               |
| `subscription_terms`           | Recurring-service terms.                               |
| `supplemental_terms`           | Additional terms for a particular offering or context. |
| `terms_of_service`             | General terms for use of a service.                    |

# Security Considerations

Document URLs and content are untrusted input. Applications must establish
destination trust before fetching; HTTPS verification alone does not
establish that a destination is permitted by an application's network
policy. Deployments requiring protection against DNS rebinding can enforce
destination restrictions at the connection or network boundary. Fetchers
must enforce the redirect, size, and time bounds above, including against
decompression expansion. Renderers MUST escape content
for their output context; they MUST NOT execute scripts, terminal
escapes, or document-provided instructions. A discovered type or title
does not establish that the document is legally valid or trustworthy.

Acknowledgements are authenticated Agent declarations. Core assertions
authenticate the Agent and operation, not a signed document-content
snapshot. This extension provides no independent proof that a human
read the documents or that a Platform approved particular bytes.
Services needing stronger legal evidence require a separate agreement;
they MUST NOT represent this identifier-only mechanism as such evidence.

An incomplete declaration does not satisfy missing access requirements.
Services exposing protected resources without Grant MUST apply their
own access policy there too; enrolling an identity is not authorization
to every application resource. This extension does not mandate changes
to existing credential revocation or application authorization rules.

Services MUST preserve core anti-enumeration protections and SHOULD
rate-limit document and enrollment requests. Unsupported required
semantics MUST NOT be silently downgraded to not-required content.

# Privacy Considerations

Public document retrieval does not need the Agent's identity, claim
values, or credentials. It still reveals a network request to the
document host; clients SHOULD avoid unnecessary prefetching and tracking
parameters. Acknowledgements are Service-scoped and MUST NOT be sent to
unrelated Services. Platforms and Services SHOULD minimize retention and
logging of acknowledgement metadata. No legal-document archive or
per-document audit trail is required by this extension.
