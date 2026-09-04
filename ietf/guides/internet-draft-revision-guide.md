# Internet-Draft Revision Guide

This guide describes how to advance one or more published AEP Internet-Drafts to new revisions. It
complements `internet-draft-addition-guide.md`, which covers introducing a new draft.

An Internet-Draft revision is an immutable publication. Never change the source for an already
published revision and submit it again under the same document name. Advance its numeric suffix and
publish the resulting revision instead.

## 1. Establish The Published Baseline

For every affected draft:

1. Open its official IETF Datatracker page.
2. Record the latest published revision and publication date.
3. Compare that revision with the repository source and the proposed changes.
4. Identify every draft whose contents must change.

Do not infer the published revision from the repository filename, website, Git tag, or GitHub
Release. Datatracker is authoritative for the publication state.

## 2. Determine The Revision Set And Order

AEP consists of a core draft and companion drafts for Claims, identity methods, grant types, and
Platforms. A change can require multiple new revisions.

Build the dependency order before editing:

1. Revise foundational drafts first.
2. Revise drafts that normatively depend on them next.
3. Update informative references when publishing the dependent draft would otherwise preserve stale
   publication metadata.

Changing a reference inside a published draft changes that draft. Give it a new revision rather
than rewriting its published source under the existing suffix.

## 3. Advance Each Draft Source

For each revised draft:

1. Rename its Markdown file from `-NN.md` to `-(NN+1).md`.
2. Update the frontmatter `docname` to the same full document name.
3. Set the frontmatter `date` to the intended submission date. The date for every draft being
   submitted must be within three days of the actual Datatracker upload date. Update and render the
   draft again if submission is delayed beyond that window.
4. Update references to revised dependent drafts, including the reference `date` and `seriesinfo`
   revision.
5. Re-read the complete draft and confirm the revision contains only intended current-state text.

The filename, `docname`, rendered artifact basename, Datatracker submission name, immutable Git tag,
and immutable GitHub Release name must agree.

## 4. Update AEP Repository References

Search the entire repository for both the old full document name and shortened revision labels such
as `draft-03`. Inspect every match rather than applying an unreviewed global replacement.

Depending on the revised draft, update:

- the root `README.md` draft list
- `ietf/README.md` and the relevant `ietf/specs/**/README.md`
- registry entries under `ietf/registry/`
- conformance scope and ownership metadata under `ietf/conformance/`
- test-vector `drafts` ownership arrays under `ietf/test-vectors/`
- validator allowlists and draft-name checks under `ietf/scripts/`
- schemas and examples containing versioned identifiers
- website links and release-asset names
- workflows or publication scripts containing explicit draft names

Retain an old revision reference only when it intentionally identifies an immutable historical
publication. Confirm that reason during review.

When the public website contains InFlow-generated per-draft pages under `docs/draft/`, treat every
affected page as part of the revision. Use the owning website process to regenerate those pages and
inspect its manifest of committed outputs. AEP can publish multiple draft pages, so verify the page
for every revised draft as well as navigation that links the complete draft set. The normal IETF
render target does not own these pages; do not hand-edit their generated HTML.

## 5. Render The Committed Artifacts

From the repository root, run:

```sh
make -C ietf format
make -C ietf render
```

The render target creates ignored XML, text, HTML, and PDF files under `artifacts/`. It also
regenerates the committed website index, examples, schemas, and conformance material under `docs/`.
Review every committed generated-file change.

## 6. Validate The Revision

Run:

```sh
make -C ietf check
make -C ietf idnits
git diff --check
git status --short
```

Then:

1. Repeat the repository-wide searches for the old full document name and old shortened revision.
2. Confirm every remaining match is intentionally historical.
3. Confirm each draft being submitted has a top-level publication date within three days of the
   planned Datatracker upload. Do not change dates within bibliographic references unless the
   referenced publication changed.
4. Inspect the rendered text for the expected title, date, revision, references, and abstract.
5. Inspect the complete Git diff, including generated files.
6. Run `make -C ietf render` again and confirm it does not produce additional committed changes.

Do not treat a successful renderer as proof that repository references, registries, vectors,
allowlists, or InFlow-generated draft pages are current. The final searches and diff review are
required.

## 7. Review And Merge The Pull Request

Keep the complete revision set coherent in its pull request. The pull request description should
identify:

- every draft being advanced
- each old and new revision
- draft dependencies and intended submission order
- the substantive protocol changes
- the commands that passed
- any intentionally retained old-revision references
- the state of every affected InFlow-generated public draft page

Merge the reviewed pull request before submitting its artifacts to IETF Datatracker. Submit the
exact artifacts rendered from the merged commit.

## 8. Submit And Verify The Drafts

Submit the rendered XML files to IETF Datatracker in dependency order. For every submission:

1. Recheck that the draft's top-level date is within three days of the current date. If it is not,
   update the source date, repeat rendering and validation, and merge the corrected source before
   uploading it.
2. Confirm Datatracker accepted the intended revision.
3. Confirm the published title, date, abstract, and references.
4. Record the merged repository commit that produced the artifact.

Do not submit dependent drafts until their referenced AEP revisions are available when that ordering
is necessary for accurate publication metadata.

## 9. Preserve The Published Revision

After Datatracker publication, follow `CONTRIBUTING.md` to create the immutable annotated Git tag
and GitHub Release named after the full document revision and attach its XML, text, HTML, and PDF
artifacts.

The deployment workflow separately moves the replaceable `latest` Git tag and GitHub Release to
the deployed `main` commit. `latest` is a convenience snapshot; it does not replace the immutable
tag and release for a submitted revision.

Final verification requires all of the following:

- Datatracker shows the intended revision.
- The immutable Git tag identifies the merged source commit.
- The immutable GitHub Release contains correctly named artifacts.
- The `latest` release and public website resolve to the current material.
- Repository searches reveal no accidental stale revision references.
