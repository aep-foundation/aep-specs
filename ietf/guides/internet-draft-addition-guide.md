# Internet-Draft Addition Guide

Use this guide for every new AEP Internet-Draft, including extension, grant
type, identity method, Platform, transport, policy, attestation, and other
future specification documents.

The goal is stronger than making CI pass. A draft that completes this guide
should be ready for public IETF posting: the source is in the right place, the
document is internally coherent, support artifacts match the prose, generated
outputs are current, and the posting package is ready.

## 1. Classify The Draft

Decide the correct `ietf/specs/` subdirectory before editing content.

- `core/`: baseline interoperable protocol behavior.
- `grant-types/`: concrete Grant and Revoke session credential formats.
- `identity-methods/`: concrete Agent identity methods.
- `platforms/`: Platform-operated APIs outside the Service-facing AEP command
  surface.
- `transports/`: non-baseline transport bindings.
- `extensions/`: optional protocol capabilities that build on core and are not
  better described by a more specific spec class.

Update `ietf/specs/README.md` and the target subdirectory `README.md`.

Exit criteria:

- The draft path matches the protocol layer it defines.
- Repo navigation explains the new spec class or existing class clearly.
- No README implies the draft belongs to a different class.

## 2. Set The Draft Name And Metadata

Choose an author-style Internet-Draft name, usually
`draft-kavian-aep-<topic>-00.md`. Avoid terms such as `profile` unless the
draft is truly a constrained profile of another mechanism.

Check:

- YAML `docname` exactly matches the filename without `.md`.
- `title`, `abbrev`, `category`, `ipr`, `submissiontype`, `stand_alone`, and
  author metadata match existing drafts.
- Normative references are required to implement the wire behavior.
- Informative references are short and directly relevant.

Exit criteria:

- Draft lint passes.
- Datatracker links derived from the docname are correct.
- Filename, `docname`, README links, vectors, and generated index all use the
  same identifier.

## 3. Read The Required Context

Read before editing:

- `ietf/STYLE.md`
- `ietf/specs/README.md`
- the target subdirectory `README.md`
- the closest existing draft in the same class
- any draft referenced normatively by the new draft
- source design material that motivated the draft

Extract requirements into a temporary gap list and mark each gap as: fix in
draft, fix in schemas, fix in vectors, fix in conformance, intentionally out of
scope, or defer with rationale.

Exit criteria:

- The draft does not rely on summary memory.
- Source requirements are implemented or explicitly scoped out.
- No private strategy, partner assumptions, or internal roadmap text leaks into
  public draft files.

## 4. Write The Draft To IETF Quality

The draft needs:

- abstract stating what the document defines without marketing language
- introduction stating scope, non-goals, and relationship to AEP core
- BCP 14 Requirements Language
- terminology that reuses AEP core terms and defines only new terms
- complete wire-visible behavior
- request, response, validation, and error behavior for every new endpoint,
  command, object, or registry value
- testable normative statements
- examples that are fake, realistic, and schema-valid
- `lower_snake_case` JSON fields
- string-encoded AEP-owned numeric protocol values
- RFC 3339 timestamps
- JWT NumericDate JSON numbers where governed by JWT specs
- no hand-written `# References` section

Exit criteria:

- The draft reads like the existing AEP Internet-Drafts.
- A new implementer can build the behavior from the draft alone.
- Examples and normative prose do not contradict each other.

## 5. Preserve AEP Architecture

The draft must state how it relates to AEP core and must not redefine core
claims, commands, errors, lifecycle states, roles, or fields.

Preserve:

- explicit discovery
- fail-closed authentication and replay behavior
- the `not_recognized` anti-enumeration surface where applicable
- separation between Service-facing AEP commands and Platform-operated APIs
- optional behavior staying out of core unless required for minimum
  interoperability

Exit criteria:

- The draft composes with AEP core without changing core semantics.
- Cross-layer references flow from the new draft to core, not from core to the
  optional draft unless deliberately updating core.
- Unsupported implementations can safely ignore optional behavior.

## 6. Review Security And Privacy

Security and Privacy Considerations must be specific to the draft.

Cover:

- authentication boundaries
- authorization boundaries
- replay protection
- idempotency for mutating operations
- credential, token, key, or secret disclosure
- information disclosure and enumeration risk
- denial-of-service and rate limiting
- audit requirements
- log and telemetry minimization
- correlation risk and pairwise identifiers where relevant
- recovery, rotation, suspension, revocation, or termination where relevant

Exit criteria:

- Security and privacy sections cover every new trust boundary.
- No endpoint exposes private signing material, raw credentials, or unnecessary
  PII.
- Failure behavior does not create probing-friendly distinctions.

## 7. Align JSON Schemas

Add schemas for stable wire objects introduced by the draft.

Check:

- schema names are consistent
- `$id` values use `https://www.aep.foundation/schemas/`
- required fields match normative prose
- optional fields are optional in prose
- enum values match normative prose exactly
- DID fields use appropriate patterns
- date-time fields use `format: date-time`
- numeric-string fields are strings, not JSON numbers
- `additionalProperties` is intentional

Update `ietf/schemas/README.md`, `ietf/scripts/check_schemas.rb`, and
published copies under `docs/schemas/`.

Exit criteria:

- Every stable wire object has a schema or a documented reason it does not.
- Every schema has at least one validating test vector when practical.
- Schema and published-schema checks pass.

## 8. Build Meaningful Test Vectors

Vectors should cover interoperability behavior, not only object syntax.

Add vectors for:

- stable request objects
- stable success response objects
- important error or non-disclosure behavior
- idempotency behavior for mutating operations
- discovery or advertisement behavior
- lifecycle or state transitions when defined

Update `ietf/scripts/check_test_vectors.rb` and `ietf/test-vectors/README.md`
for new categories, roles, or profiles.

Exit criteria:

- Vectors exercise the draft's interoperability surface.
- Vector checks pass.
- Schema-targeted vectors validate.

## 9. Define Conformance Impact

Decide whether the draft adds Agent, Service, Platform, binding, extension, or
other role requirements.

Define:

- support claim requirements
- Core, Standard, Extended, or claim-dependent status
- static-vector coverage
- live-harness coverage
- declaration-only requirements

Update `ietf/conformance/README.md` and
`ietf/scripts/check_conformance_harness.rb` when needed.

Exit criteria:

- An implementer knows how to claim support.
- Conformance text does not imply optional support is required.
- Harness checks pass.

## 10. Review Registry And Governance Needs

Decide whether the draft registers a command, grant type, identity method,
extension, error code, lifecycle state, well-known URI, media type, or other
wire identifier.

Update:

- IANA Considerations
- `ietf/registry/` entries
- `ietf/governance/README.md`
- `ietf/governance/extension-registration.md` only when extension registration
  behavior changes
- `ietf/scripts/check_registry.rb` when validation rules change

Exit criteria:

- Every new wire identifier has a registration path or a clear reason no
  registration is needed.
- IANA Considerations is not empty when registrable values are defined.
- Registry checks pass.

## 11. Update Documentation And Navigation

Update:

- root `README.md`
- `ietf/README.md`
- `ietf/specs/README.md`
- the target subdirectory `README.md`
- `ietf/schemas/README.md`
- `ietf/test-vectors/README.md`
- `CONTRIBUTING.md` if the workflow changes
- generated `docs/index.html`
- generated schema docs and copies

Exit criteria:

- A reader can discover the draft from the root README and IETF README.
- Website index points to the correct release asset names.
- No public documentation points to an old filename, old folder, or old draft
  classification.

## 12. Render And Inspect Artifacts

Run:

```sh
make -C ietf format
make -C ietf render-index
make -C ietf render-schemas
make -C ietf render-drafts
```

Inspect generated `.txt`, `.html`, `.xml`, and `.pdf` artifacts. Record render
warnings and decide whether they block posting.

Exit criteria:

- Rendered artifacts exist under the current docname.
- Generated outputs are readable enough for public review.
- Checked-in generated docs have no stale links.

## 13. Run Consistency Searches

Search for:

- old draft names
- old folder paths
- stale terminology
- old error names
- `profile` when the draft is not a profile
- `extension` in non-extension draft material
- internal strategy terms
- private partner names or speculative launch language

Exit criteria:

- Stale hits are fixed or intentionally retained with a documented reason.
- Checked source and docs contain no stale draft name, path, or taxonomy.

## 14. Run The Full Check Gate

Run:

```sh
make -C ietf check
git diff --check
git status --short
git diff --stat
```

Review substantive diffs, not only summaries.

Exit criteria:

- `make -C ietf check` passes.
- `git diff --check` reports no whitespace errors.
- All modified and untracked files are expected.
- No unrelated user changes were reverted or overwritten.

## 15. Perform Publication Readiness Review

Read the draft from top to bottom as if reviewing an IETF submission.

Confirm:

- title and abstract identify the specification
- required sections are present
- the draft can be implemented without private context
- examples are consistent and useful
- schemas and vectors cover stable wire behavior
- conformance impact is explicit
- IANA Considerations is correct
- Security Considerations is complete enough for public review
- Privacy Considerations is complete enough for public review
- source-design gaps do not block posting

Exit criteria:

- The editor would be comfortable posting the draft to IETF Datatracker.
- Remaining work, if any, is post-publication improvement rather than a blocker
  to public review.

## 16. Prepare The IETF Posting Package

Use the rendered XML artifact for Datatracker upload.

Confirm:

- XML docname matches the intended draft identifier
- rendered text artifact has the expected title, date, author, and abstract
- references are complete
- no unresolved placeholders remain
- version suffix is correct
- release asset names align with the docname

Prepare a short posting summary: what the draft defines, what it depends on,
and what review is requested.

Exit criteria:

- The draft can be posted to IETF without additional repo surgery.
- Posting summary accurately represents the draft and its relation to AEP core.
