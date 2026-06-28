# AEP Extension Registration Guidance

This document is non-normative governance support. The IANA Considerations
sections of published RFCs are authoritative once registries are established.

## Extension Identifiers

AEP extension identifiers are absolute URIs. AEP-owned extension identifiers
use:

```text
urn:aep:ext:<authority>:<name>#v=<MAJOR>.<MINOR>.<PATCH>
```

The base URN identifies the extension. The `v` fragment selects the extension
version. Future fragment parameters use `&` separators.

## Registration Classes

| Registration class           | Examples                                | Expected document                                 |
| ---------------------------- | --------------------------------------- | ------------------------------------------------- |
| Command extension            | Lifecycle commands, audit export        | Internet-Draft or equivalent stable specification |
| Grant type                   | `oauth-bearer`, `api-key`, `basic`      | Grant/Revoke credential specification             |
| Binding                      | HTTP, MCP, WebSocket, SSE               | Binding specification                             |
| Identity method profile      | DID method profiles beyond `did:web`    | Identity method specification                     |
| Policy or claim extension    | Privacy preference, data residency, KYA | Extension specification                           |
| Proof or attestation profile | ZK proof type, runtime attestation      | Profile specification                             |

## Grant Type Registration Requirements

A grant type specification should define:

| Requirement           | Description                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------ |
| Identifier            | Lowercase hyphenated `grant_type` string.                                                  |
| Inspect advertisement | Required `commands.grant_types` value and optional `commands.grant_types_config` fields.   |
| Grant request         | Required and optional request fields beyond `grant_type`.                                  |
| Grant response        | Response fields, required secrets, identifiers, expiry, and scope behavior.                |
| Presentation          | How the credential is presented to resource endpoints.                                     |
| Expiry                | Required expiry semantics and timestamp fields.                                            |
| Revoke                | Grant-type Revoke, optional per-credential Revoke, and interaction with `all_grant_types`. |
| Errors                | Any additional error behavior beyond the core error vocabulary.                            |
| Security              | Storage, leakage, entropy, logging, replay, and audience-binding considerations.           |
| Privacy               | Correlation and data-minimization considerations.                                          |

## Compatibility Expectations

Extensions are additive. They must not redefine core command semantics, core
field names, status values, error codes, authentication rules, or media types.

An extension can add:

- New Inspect fields.
- New `commands.grant_types_config` fields.
- New request or response fields scoped to its command or grant type.
- New extension identifiers.
- New test vectors, schemas, examples, and conformance harness checks.

An extension should preserve forward compatibility by requiring Agents and
Services to ignore unknown additive fields unless local policy requires
rejection.

## Review Checklist

Before adding an extension, verify:

- The extension has a stable identifier.
- The extension does not duplicate an existing extension.
- Wire identifiers use lowercase hyphenated tokens.
- Field names use `lower_snake_case`.
- AEP-owned numeric values are JSON strings.
- Timestamps use RFC 3339 strings.
- Required security and privacy considerations are explicit.
- Examples, schemas, vectors, and harness checks are included when the wire
  behavior is stable enough to test.

## Temporary Repository Registration

Until formal IANA registries exist, repository review should treat the published
drafts and this guidance as the temporary registration process. Once IANA
registries are created, the IANA registry contents and designated expert review
process supersede this temporary repository guidance.

Repository-local registry entries live in `ietf/registry/`. They are validated
by:

```sh
make -C ietf check-registry
```
