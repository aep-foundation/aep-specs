# Agent Enrollment Protocol Internet-Draft Style

This style guide applies to Internet-Draft sources in this directory. It is
intended for the public `aep-foundation/aep-specs` repository and for document
work under `aep.foundation`.

## Design Principles

### Minimal Core

The core AEP document contains only the protocol behavior needed for minimum
interoperability:

- HTTP binding behavior with TLS protection.
- Inspect, Enroll, Grant, Revoke, and Status.
- Baseline client assertion authentication.
- `did:web` identity resolution.
- HTTP Problem Details error handling.
- IANA registrations needed by the core.

Optional capabilities belong in separate documents unless they are required for
the smallest interoperable command set.

### Layered Architecture

AEP document work is organized by protocol layer:

- **Core**: enrollment, discovery, baseline authentication, core registries.
- **Session credentials**: concrete Grant/Revoke credential formats such as
  OAuth Bearer, API-key, and Basic.
- **Lifecycle**: richer state-machine behavior beyond the minimal Status
  surface, when needed.
- **Transports**: non-HTTP bindings such as WebSocket or MCP, when needed.
- **Policy and privacy**: Service disclosures and Agent preference negotiation.
- **Attestations and proofs**: KYA, verifier attestations, and ZK proofs.

Cross-layer references should flow from extensions to core. Core should not
depend on optional extensions.

### Explicit Discovery

Services advertise protocol capabilities through Inspect. Agents do not infer
support for commands, grant types, DID methods, algorithms, extensions, or
policy blocks from undocumented behavior.

### Fail Closed

Invalid credentials, unsupported methods, expired assertions, replay attempts,
and recognition failures fail closed. Recognition failures use the common
`not_recognized` surface and do not reveal which check failed.

## RFC Writing Conventions

### IETF Format

Internet-Draft sources use the kramdown-rfc format used by the existing sources. Each document
contains:

1. YAML metadata.
2. Abstract.
3. Introduction.
4. Requirements Language.
5. Terminology, when the document introduces new terms.
6. Technical body.
7. Error Handling, when the document defines protocol behavior.
8. IANA Considerations.
9. Security Considerations.
10. Privacy Considerations.
11. References generated from YAML metadata.

Do not add a hand-written `# References` section.

### Requirements Language

- Use RFC 2119 and RFC 8174 requirements language.
- Use `MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, and `MAY` only when the
  statement is normative.
- Prefer declarative protocol prose over roadmap, strategy, or implementation
  narrative.
- Avoid "we", "should consider", "future work may", and similar conversational
  language in document bodies.

### Terminology

Define terms on first use and use them consistently:

| Term               | Meaning                                                              |
|--------------------|----------------------------------------------------------------------|
| Agent              | Autonomous software that initiates AEP requests.                     |
| Service            | HTTP server that receives AEP requests.                              |
| Inspect document   | JSON discovery document at `/.well-known/aep`.                       |
| Client assertion   | JWT signed by the Agent and presented on authenticated AEP commands. |
| Session credential | Stateful credential issued by Grant and invalidated by Revoke.       |
| Grant type         | String identifier for a session-credential format.                   |

Commands use title case in prose: Inspect, Enroll, Grant, Revoke, Status.
Wire identifiers use lowercase: `inspect`, `enroll`, `grant`, `revoke`,
`status`.

### Examples

Include examples for non-trivial wire behavior. Examples use fake but realistic
values:

```http
GET /.well-known/aep HTTP/1.1
Host: example.com
Accept: application/aep+json
```

```json
{
  "commands": {
    "grant_types": ["api-key"],
    "supported": ["enroll", "grant", "inspect", "revoke", "status"]
  }
}
```

Examples are normative only when the surrounding text says so.

### Cross-References

- Use kramdown-rfc references such as `{{RFC9110}}` for external specs.
- Prefer section-agnostic references to documents unless a precise section is
  necessary.
- Keep normative references limited to specifications required to implement the
  wire protocol.
- Keep informative references short and directly relevant.

### JSON and Wire Formatting

- JSON examples use 2-space indentation and no trailing commas.
- Field keys use `lower_snake_case`.
- AEP-owned numeric JSON values serialize as strings, such as
  `"default_lifetime_seconds": "900"`.
- RFC-governed foreign envelope fields keep their RFC-defined representation;
  JWT NumericDate claims such as `iat` and `exp` serialize as JSON numbers.
- Timestamps use RFC 3339 strings.
- Binary values use base64url without padding unless an external standard, such
  as HTTP Basic, requires another encoding.

### Line Length

Keep source lines under 72 characters when practical. Long URLs in examples may
be shortened to `example.com` values to keep rendered text readable.

## Public-Repository Hygiene

Published document sources must not contain:

- Internal roadmap language.
- Internal readiness disclaimers.
- Private partner assumptions or speculative partnership claims.
- Vendor-specific launch strategy.
- Unfinished marker text.
- References to unrelated payment protocols except when a document explicitly
  defines composition behavior.

Use `aep.foundation`, `aep-foundation`, and `aep-specs` for foundation,
organization, and repository references when such names are needed.

## Draft Naming

Individual draft source names use author-style Internet-Draft naming until a working group adopts the document:

```text
draft-kavian-agent-enrollment-protocol-00.md
```

If a working group adopts the draft, the name changes to:

```text
draft-ietf-<wg>-<topic>-00
```

## References

Use normative references only for specifications required to implement the wire protocol. Keep informative references short and directly relevant.

## IANA Considerations

Documents that define wire identifiers request or update IANA registrations. Each
registry entry should include the identifier, a short description, and the
document reference. New AEP registries use Specification Required unless a document
defines a different policy with justification.

## Security and Privacy

Security Considerations and Privacy Considerations are never empty.

Security considerations address at minimum:

- Authentication boundaries.
- Replay protection and idempotency.
- Credential theft or disclosure.
- Information disclosure and enumeration risk.
- Denial-of-service or rate-limit considerations.

Privacy considerations address at minimum:

- Agent or Owner data disclosure.
- Correlation risk.
- Log and telemetry minimization.
- Token or credential reuse outside the issuing Service.
