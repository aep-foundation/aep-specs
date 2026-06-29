# Grant Type Specifications

Grant type documents define optional session-credential formats that Services
can enable for the AEP Grant and Revoke commands.

Grant type implementations can be shipped by SDKs without being enabled by
default. A Service advertises only enabled grant types in
`commands.grant_types` and publishes grant-type-specific configuration under
`commands.grant_types_config`.

Current grant type draft sources:

- `draft-kavian-aep-api-key-session-credential-01.md`
- `draft-kavian-aep-basic-session-credential-01.md`
- `draft-kavian-aep-oauth-session-credential-01.md`
