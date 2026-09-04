# AEP SDK Support

This document describes the compatibility, maintenance, and verification policy for the official
Agent Enrollment Protocol software development kits. The Internet-Drafts remain authoritative for
protocol behavior.

## Compatibility Policy

The official SDKs implement the AEP `1.x` compatibility family. As required by the core protocol,
they reject unsupported major versions and accept same-major Inspect documents according to AEP's
unknown-field and optional-capability rules.

Protocol versions and SDK versions are independent:

- `aep_version` identifies wire-protocol compatibility.
- Each language uses its ecosystem's semantic-versioning conventions for its public packages.
- SDK releases are not coordinated across languages and matching version numbers do not imply
  compatibility.
- Packages released together from one repository may share a version where that ecosystem benefits
  from a coordinated release unit.

Applications should select an SDK release supported by their language runtime and evaluate wire
compatibility through `aep_version`, not by comparing SDK package versions.

## Official SDKs

| Language                                               | Distribution                                                                                         | Runtime floor | Release unit                             | Service integrations                                 |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- | ------------- | ---------------------------------------- | ---------------------------------------------------- |
| [Node.js](https://github.com/aep-foundation/aep-node)  | [`@aep-foundation` packages on npm](https://www.npmjs.com/org/aep-foundation)                        | Node.js 22    | Independently versioned packages         | Express, Fastify, Hono, and Next.js                  |
| [Go](https://github.com/aep-foundation/aep-go)         | [`github.com/aep-foundation/aep-go`](https://pkg.go.dev/github.com/aep-foundation/aep-go)            | Go 1.26       | One module version                       | Framework-neutral HTTP handlers                      |
| [Java](https://github.com/aep-foundation/aep-java)     | [`foundation.aep` artifacts on Maven Central](https://central.sonatype.com/namespace/foundation.aep) | Java 17       | One reactor version aligned by `aep-bom` | JDK HTTP Server, Jakarta Servlet, and Spring Web MVC |
| [Python](https://github.com/aep-foundation/aep-python) | [`agent-enrollment-protocol` on PyPI](https://pypi.org/project/agent-enrollment-protocol/)           | Python 3.11   | One distribution version                 | ASGI                                                 |
| [Rust](https://github.com/aep-foundation/aep-rust)     | [`aep-*` crates on crates.io](https://crates.io/search?q=aep-)                                       | Rust 1.88     | One workspace version                    | Tower and Axum                                       |

All five SDKs provide Core protocol models and validation plus Agent, Service, and Platform roles.
Framework integrations are optional; an application can integrate the role APIs directly.

## Supported Releases

Security fixes are published for the latest stable release of each package, module, distribution,
or crate unless its release notes state otherwise. Maintainers do not promise fixes for older
release lines. Applications that cannot update should evaluate the applicable advisory and backport
requirements themselves.

Release mechanics remain ecosystem-specific:

| Language | Publication and release evidence                                                                                                                   |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Node.js  | Changesets publishes packages to npm with provenance after the repository verification gate.                                                       |
| Go       | An annotated Git tag and GitHub Release publish the module source and attach conformance and interoperability reports.                             |
| Java     | The manual release workflow publishes signed artifacts to Maven Central, attests release bundles, and verifies Maven and Gradle consumers.         |
| Python   | PyPI Trusted Publishing publishes attested distributions and verifies a clean registry consumer.                                                   |
| Rust     | crates.io Trusted Publishing publishes the workspace crates in dependency order, attests release archives, and verifies a clean registry consumer. |

Different automation does not indicate a different protocol-compatibility promise. A release is
supported only when it is available from the registry or source channel identified above.

## Conformance And Interoperability Evidence

Every official SDK executes the shared Agent, Service, and Platform conformance profiles against its
public role APIs. Conformance reports establish the behavior exercised by a particular SDK commit;
they are evidence, not a permanent certification of later code.

The cross-language boundary is exercised by two 25-cell matrices:

| Matrix            | Scope                                                                                     | Hosted evidence                                                                              |
| ----------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Agent to Service  | Every official Agent against every official Service                                       | [25-cell workflow run](https://github.com/aep-foundation/aep-specs/actions/runs/33838434732) |
| Agent to Platform | Every official Agent against every official Platform, using one canonical Node.js Service | [25-cell workflow run](https://github.com/aep-foundation/aep-specs/actions/runs/33840964889) |

Each SDK's continuous-integration workflow also runs its native verification and shared conformance
gates. Release workflows preserve ecosystem-appropriate evidence rather than requiring identical
artifact layouts across registries.

## Security Reporting

Report an implementation vulnerability through the affected SDK repository's private vulnerability
reporting channel. Report protocol-level security ambiguities through the private channel described
in [SECURITY.md](./SECURITY.md). Do not publish credentials, personal data, or active exploit details
in a public issue.
