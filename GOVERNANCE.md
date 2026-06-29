# AEP Specification Governance

This document describes how the AEP specification set evolves in this
repository. It is project governance, not protocol text. The Internet-Draft
documents remain authoritative for protocol requirements.

## Scope

This repository maintains:

- Internet-Draft sources under `ietf/specs/`.
- Non-normative guides under `ietf/guides/`.
- Conformance notes under `ietf/conformance/`.
- Test vectors under `ietf/test-vectors/`.
- JSON Schemas under `ietf/schemas/`, with public copies under
  `docs/schemas/`.
- Public website content under `docs/`.

## Change Classes

| Change class      | Examples                                                                                            | Review expectation                                       |
| ----------------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| Editorial         | Typos, wording cleanup, broken links, generated index refreshes                                     | Low risk; normal review                                  |
| Support artifact  | Examples, guides, schemas, vectors, harness checks                                                  | Verify with `make -C ietf check`                         |
| Clarification     | Resolves ambiguous draft text without changing intended behavior                                    | Check examples, schemas, and vectors for alignment       |
| Protocol behavior | Adds or changes command behavior, wire fields, error handling, registries, or security requirements | Requires careful draft review and compatibility analysis |
| Feature           | Adds an AEP-defined grant type, binding, identity method, or other optional capability              | Requires registry review when a registry exists          |
| Extension         | Adds a policy model, attestation model, proof model, third-party capability, or other large module  | Requires extension registration review                   |

## Versioning And Compatibility

AEP uses loose protocol semver for AEP-owned protocol versions and extension
versions.

| Version component | Use                                                                                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PATCH             | Editorial corrections and non-normative support fixes with no protocol behavior change.                                                                   |
| MINOR             | New optional fields, new optional commands, new extensions, and security- or interoperability-driven corrections that may require implementation changes. |
| MAJOR             | Wire-format epochs, large architectural shifts, or removal of core protocol capabilities.                                                                 |

Protocol compatibility is evaluated from the wire behavior, not from repository
file churn. A support artifact can change without changing the protocol version
when it only improves validation, documentation, examples, or generated output.

## Artifact Compatibility

| Artifact        | Compatibility rule                                                                                                                 |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Internet-Drafts | Draft text is authoritative. Behavior-changing edits need compatibility review.                                                    |
| JSON Schemas    | Schemas validate stable wire objects. Tightening schemas can affect implementers and needs review against draft prose.             |
| Test vectors    | Vectors encode expected behavior. Existing vector changes should be treated as compatibility-affecting unless correcting an error. |
| Examples        | Examples are non-normative. They should stay aligned with drafts, schemas, and vectors.                                            |
| Guides          | Guides are non-normative. Conflicts with drafts are resolved in favor of drafts.                                                   |
| Rendered site   | Generated site changes are publication artifacts and should be reproducible from source.                                           |

## Publication Model

The `ietf/` directory is the source for specifications and support material.
The `docs/` directory is the GitHub Pages site.

Rendered Internet-Draft artifacts are published as GitHub Release assets rather
than committed binaries. JSON Schemas are committed under `docs/schemas/`
because their `$id` values use stable `https://www.aep.foundation/schemas/...`
URLs.

## Required Checks

Run:

```sh
make -C ietf check
```

The check target validates draft structure, external section references, test
vectors, JSON Schema mappings, published schema copies, and offline conformance
fixture semantics.

When generated website files are affected, regenerate the relevant artifact:

```sh
make -C ietf render-index
make -C ietf render-examples
make -C ietf render-schemas
```

## Review Expectations

Specification changes should answer:

- Does the change alter wire behavior?
- Does it affect Agent or Service interoperability?
- Does it affect security, privacy, anti-enumeration, replay handling, or
  credential leakage risk?
- Do examples, schemas, vectors, and the harness still match the draft text?
- Does the change require an extension registration or registry update?

Behavior-changing changes should include updates to relevant support artifacts
in the same pull request when practical.

## IETF Relationship

The repository may contain working material that supports IETF drafts, but the
IETF process controls eventual standardization. When draft text and repository
guidance disagree, draft text is corrected through normal review. When an IETF
working group or designated experts define a different registration or review
process, that process takes precedence for the affected registry or document.
