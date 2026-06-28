# AEP JSON Schemas

This directory contains JSON Schemas for stable AEP wire objects used by the
published Internet-Draft set.

The schemas are validation aids. They do not replace the Internet-Draft prose.
If a schema and a draft disagree, the draft is authoritative and the schema
should be corrected.

## Scope

The initial schema set covers the stable core HTTP objects and the three
published session-credential Grant responses:

| Schema                                    | Validates                         |
| ----------------------------------------- | --------------------------------- |
| `inspect-document.schema.json`            | Inspect document response body    |
| `enroll-request.schema.json`              | Enroll request body               |
| `enroll-response.schema.json`             | Enroll response body              |
| `status-response.schema.json`             | Status response body              |
| `grant-request.schema.json`               | Grant request body                |
| `revoke-request.schema.json`              | Revoke request body               |
| `revoke-response.schema.json`             | Revoke response body              |
| `problem.schema.json`                     | AEP Problem Details response body |
| `oauth-bearer-grant-response.schema.json` | OAuth Bearer Grant response body  |
| `api-key-grant-response.schema.json`      | API-key Grant response body       |
| `basic-grant-response.schema.json`        | HTTP Basic Grant response body    |

## Validation

Run schema validation with:

```sh
make -C ietf check-schemas
```

The default repository check runs schema validation as part of:

```sh
make -C ietf check
```

The schema checker validates the JSON test vectors that map directly to stable
wire objects. Vectors that describe metadata, JOSE processing, or multi-step
behavior remain covered by the vector structure checker.
