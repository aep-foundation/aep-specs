# Agent Enrollment Protocol Specifications

[![CI](https://github.com/aep-foundation/aep-specs/actions/workflows/ci.yml/badge.svg)](https://github.com/aep-foundation/aep-specs/actions/workflows/ci.yml)
[![Deploy](https://github.com/aep-foundation/aep-specs/actions/workflows/deploy.yml/badge.svg)](https://github.com/aep-foundation/aep-specs/actions/workflows/deploy.yml)
[![IETF Draft](https://img.shields.io/badge/IETF-Agent_Enrollment_Protocol-blue)](https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/)
[![Examples](https://img.shields.io/badge/AEP-live_examples-6f42c1)](https://www.aep.foundation/examples/)
[![Schemas](https://img.shields.io/badge/JSON-Schemas-2ea44f)](https://www.aep.foundation/schemas/)
[![License](https://img.shields.io/badge/License-CC0%20%2B%20Apache--2.0%2FMIT-yellow.svg)](./LICENSE.md)

The open specification for establishing trust between autonomous Agents and
the Services they use.

The Agent Enrollment Protocol (AEP) defines how an Agent discovers a Service's
requirements, enrolls a cryptographic identity, authenticates requests,
obtains optional scoped credentials, checks its enrollment state, and revokes
access. The protocol is machine-first, transport-aware, and designed for
independent implementation.

```text
Discover           Establish trust          Use access              Manage lifecycle
Inspect ─────────▶ Enroll ────────────────▶ Authenticate ─────────▶ Status
                         └──────── Grant ─▶ Session credential └──▶ Revoke
```

## Protocol at a Glance

| Command     | What the Agent learns or changes                                                                                                   |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Inspect** | Discovers the Service DID, command endpoints, supported identity methods, authentication methods, grant types, and policy metadata |
| **Enroll**  | Registers a Service-scoped Agent identity and returns an active or pending enrollment state                                        |
| **Grant**   | Exchanges proof-of-possession for an optional scoped session credential                                                            |
| **Status**  | Reads the current enrollment state and any outstanding requirements                                                                |
| **Revoke**  | Invalidates one or more issued session credentials                                                                                 |

The core protocol does not require a particular session-credential format. A
Service can implement Inspect, Enroll, and Status without Grant or Revoke, or
advertise one or more companion grant types when session credentials are
useful.

## Read the Specifications

| Document                                                                                                    | Scope                                                                                                                                     | Source                                                                                     |
| ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [Agent Enrollment Protocol](https://datatracker.ietf.org/doc/draft-kavian-agent-enrollment-protocol/)       | Core commands, HTTP transport, discovery, client assertions, identity-method substrate, errors, security, privacy, and IANA registrations | [`draft-04`](./ietf/specs/core/draft-kavian-agent-enrollment-protocol-04.md)               |
| [Claim Values](https://datatracker.ietf.org/doc/draft-kavian-aep-claims/)                                   | Interoperable claim names and forward-compatible claim value shapes                                                                       | [`draft-01`](./ietf/specs/core/draft-kavian-aep-claims-01.md)                              |
| [`did:web` Identity Method](https://datatracker.ietf.org/doc/draft-kavian-aep-did-web-identity-method/)     | Initial AEP-defined identity method feature                                                                                               | [`draft-00`](./ietf/specs/identity-methods/draft-kavian-aep-did-web-identity-method-00.md) |
| [Platform Hosted Identity](https://datatracker.ietf.org/doc/draft-kavian-aep-platform-hosted-identity/)     | Service-scoped Agent DID provisioning, delegated signing, verification, and lifecycle                                                     | [`draft-01`](./ietf/specs/platforms/draft-kavian-aep-platform-hosted-identity-01.md)       |
| [OAuth Session Credential](https://datatracker.ietf.org/doc/draft-kavian-aep-oauth-session-credential/)     | OAuth Bearer credentials issued and revoked through Grant and Revoke                                                                      | [`draft-03`](./ietf/specs/grant-types/draft-kavian-aep-oauth-session-credential-03.md)     |
| [API-key Session Credential](https://datatracker.ietf.org/doc/draft-kavian-aep-api-key-session-credential/) | API-key credentials issued and revoked through Grant and Revoke                                                                           | [`draft-03`](./ietf/specs/grant-types/draft-kavian-aep-api-key-session-credential-03.md)   |
| [Basic Session Credential](https://datatracker.ietf.org/doc/draft-kavian-aep-basic-session-credential/)     | HTTP Basic credentials issued and revoked through Grant and Revoke                                                                        | [`draft-03`](./ietf/specs/grant-types/draft-kavian-aep-basic-session-credential-03.md)     |

## Implement and Test

The repository connects normative documents to artifacts that can be consumed
by SDKs, servers, and conformance suites:

| Area                                       | Contents                                                                                                  |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| [`ietf/examples`](./ietf/examples)         | Complete command, Claims negotiation, protected-resource, authorization-composition, and OpenAPI examples |
| [`ietf/schemas`](./ietf/schemas)           | JSON Schemas for stable request, response, discovery, Claims, Platform, and problem-detail objects        |
| [`ietf/test-vectors`](./ietf/test-vectors) | Success, rejection, Claims compatibility, redirect-safety, replay/idempotency, and Platform cases         |
| [`ietf/conformance`](./ietf/conformance)   | Conformance profiles and the offline fixture harness                                                      |
| [`ietf/registry`](./ietf/registry)         | Machine-readable authentication, identity, grant-type, Claim Name, extension, and HTTP-field entries      |
| [`ietf/guides`](./ietf/guides)             | Non-normative implementation and Internet-Draft authoring guidance                                        |

Start with the [implementer guide](./ietf/guides/implementer-guide.md), then use
the [complete Enroll → Grant → Revoke transcript](./ietf/examples/enroll-grant-revoke-transcript.md)
as a wire-level companion to the core draft.

## Repository Map

```text
aep-specs/
├── ietf/
│   ├── specs/          # Internet-Draft Markdown sources
│   ├── examples/       # reviewed protocol examples and transcripts
│   ├── schemas/        # source JSON Schemas
│   ├── test-vectors/   # conformance inputs and expected outcomes
│   ├── conformance/    # profiles and artifact manifest
│   ├── registry/       # repository-local registry entries
│   ├── guides/         # non-normative implementation guidance
│   └── governance/     # extension registration guidance
├── docs/               # published website, examples, and schema copies
└── artifacts/          # local rendered drafts; generated and gitignored
```

The [`ietf/README.md`](./ietf/README.md) documents the draft workspace and full
rendering prerequisites.

## Build and Validate

Install the Ruby dependencies, then run the complete repository check:

```sh
cd ietf
bundle config set path vendor/bundle
bundle install
make check
```

Useful focused targets:

```sh
# Validate draft structure, references, vectors, schemas, harness, and registries
make -C ietf check

# Format Markdown tables
make -C ietf format

# Render XML, text, HTML, PDF, examples, schemas, and the site index
make -C ietf render

# Run idnits against rendered text drafts
make -C ietf idnits
```

Rendering also requires Python packages from
[`ietf/requirements.txt`](./ietf/requirements.txt) and the native dependencies
described in [`ietf/README.md`](./ietf/README.md). Generated drafts are written
to `artifacts/`; the deploy workflow publishes them on the latest GitHub
release.

## Reference Resources

| Resource           | Best for                                                                  | Link                                                                                 |
| ------------------ | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Complete draft set | Core, claims, identity method, Platform, and session-credential documents | [Published specification site](https://www.aep.foundation/)                          |
| Rendered artifacts | HTML, text, XML, and PDF builds of every draft                            | [Latest GitHub release](https://github.com/aep-foundation/aep-specs/releases/latest) |
| Implementer guide  | A practical route through the drafts and support artifacts                | [Implementer guide](./ietf/guides/implementer-guide.md)                              |
| Protocol examples  | Inspect documents and complete HTTP transcripts                           | [Examples](https://www.aep.foundation/examples/)                                     |
| JSON Schemas       | Machine-readable validation of stable wire objects                        | [Published schemas](https://www.aep.foundation/schemas/)                             |
| Test vectors       | Positive and negative implementation cases                                | [Test vectors](./ietf/test-vectors)                                                  |
| Node.js SDK        | Reference TypeScript implementation and runnable applications             | [`aep-node`](https://github.com/aep-foundation/aep-node)                             |

Internet-Draft prose is normative. Schemas, examples, registries, and test
vectors are implementation support artifacts and do not replace the
specifications.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the contribution workflow,
[GOVERNANCE.md](./GOVERNANCE.md) for project governance, and
[`ietf/STYLE.md`](./ietf/STYLE.md) for Internet-Draft writing conventions.

Security issues should be reported through [SECURITY.md](./SECURITY.md).

## License

See [LICENSE.md](./LICENSE.md). Specification text and repository software use
the licenses described there.
