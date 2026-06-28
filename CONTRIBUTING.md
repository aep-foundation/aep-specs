# Contributing

This repository contains Internet-Draft sources, rendered artifacts, and web
content for the Agent Enrollment Protocol (AEP).

## Making Changes

### Branching

- `main` is the stable branch.
- Use feature branches for proposed changes.
- Keep pull requests focused on one protocol concern.

### Pull Request Checklist

Before submitting a pull request:

1. Run `make -C ietf check`.
2. Render updated artifacts when changing Internet-Draft sources:

   ```sh
   make -C ietf render
   ```

3. Confirm rendered specification links point to the latest release assets.
4. Avoid hardcoded external section references unless no practical alternative
   exists.
5. Confirm no internal roadmap, private partner context, or speculative launch
   language appears in public specification files.

## Types of Changes

| Change Type               | Process                                                           |
|---------------------------|-------------------------------------------------------------------|
| Typo or editorial fix     | Pull request to `main`.                                           |
| Core protocol change      | Open an issue or discussion first.                                |
| Session credential change | Update the relevant document under `ietf/specs/extensions/`.      |
| New extension draft       | Use `ietf/templates/extension-template.md`.                       |
| Build or website change   | Include generated output only when it is intentionally published. |

## Writing Style

Follow `ietf/STYLE.md` for Internet-Draft conventions.

Protocol requirements use RFC 2119 and RFC 8174 keywords. Examples use fake
but realistic values, `lower_snake_case` JSON field names, and 2-space JSON
indentation.

## AI-Assisted Contributions

If AI tools help prepare a contribution:

1. The contributor remains responsible for correctness and quality.
2. Significant AI assistance should be disclosed in the pull request
   description.
3. Generated content must be reviewed for RFC style, protocol accuracy, and
   public-repository hygiene.

## Local Rendering

Install the render toolchain:

```sh
cd ietf
bundle config set path vendor/bundle
bundle install
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

Run checks and render artifacts:

```sh
make -C ietf check
make -C ietf render
```

Rendered XML, text, HTML, and PDF artifacts are written to the ignored
root-level `artifacts/` directory. The deploy workflow publishes those files as
GitHub Release assets for the website to link.
