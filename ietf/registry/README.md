# AEP Repository Registry

This directory contains repository-local, machine-readable registry entries for
AEP extensions.

These entries are governance support material. They do not replace IANA
registries once IANA registries exist.

## Layout

```text
registry/
  extension-entry.schema.json
  grant-types/
    oauth-bearer.json
    api-key.json
    basic.json
```

## Validation

Run:

```sh
make -C ietf check-registry
```

The checker validates each entry against `extension-entry.schema.json` and
performs repository-specific consistency checks.
