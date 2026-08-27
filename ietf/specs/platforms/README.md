# Platform Specifications

Platform documents define optional APIs operated by AEP Platforms outside the
Service-facing AEP command surface.

Platform specifications can define hosted identity, key custody, DID
publication, delegated signing, and Platform conformance behavior. They do not
make a Platform a Service, and they do not require Services to advertise
Platform support in Inspect.

Platform specifications describe Platform-operated APIs. Agent-side DID method
selection, key rotation, and identity wallet behavior belong to Agent tooling or
separate identity-management specifications, not to the Platform Hosted
Identity API.

For Platform Hosted Identity, `key_id` identifies the hosted `did:web` Agent
DID itself. Do not use sovereign-DID verification-method fragments such as
`#key-1` in Platform draft examples, Platform test vectors, or rendered
Platform artifacts.

Current Platform draft sources:

- `draft-kavian-aep-platform-hosted-identity-01.md`
