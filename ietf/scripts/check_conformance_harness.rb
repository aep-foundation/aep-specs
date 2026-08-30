#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
VECTOR_ROOT = ROOT.join("test-vectors")

COMMAND_PATHS = {
  "enroll" => "/aep/enroll",
  "grant" => "/aep/grant",
  "revoke" => "/aep/revoke",
  "status" => "/aep/status"
}.freeze

POST_COMMANDS = %w[enroll grant revoke].freeze
AUTHENTICATED_COMMANDS = %w[enroll grant revoke status].freeze
AUTHENTICATED_OPERATIONS = (AUTHENTICATED_COMMANDS + ["authenticate"]).freeze
GRANT_TYPES = %w[oauth-bearer api-key basic].freeze
CLAIM_NAMES = %w[
  contact.address.primary
  contact.email
  contact.mobile
  person.birthdate
  person.first_name
  person.last_name
  person.username
].freeze
CREDENTIAL_PROFILES = {
  "oauth-bearer" => {
    category: "credentials/oauth-bearer",
    required_fields: %w[access_token expires_at token_type],
    token_type: "Bearer"
  },
  "api-key" => {
    category: "credentials/api-key",
    required_fields: %w[api_key expires_at header]
  },
  "basic" => {
    category: "credentials/basic",
    required_fields: %w[expires_at password username]
  }
}.freeze
PLATFORM_LIFECYCLE_STATES = %w[active revoked suspended terminated].freeze

def vector(path)
  JSON.parse(VECTOR_ROOT.join(path).read)
end

def expect(errors, condition, message)
  errors << message unless condition
end

def endpoint(base, command)
  "#{base.sub(%r{/+\z}, "")}/#{command}"
end

errors = []

inspect = vector("inspect/minimal-http.json").fetch("expected")
commands = inspect.fetch("commands")
endpoint_base = inspect.fetch("http").fetch("endpoint_base")

expect(errors, inspect.dig("bindings", "supported").include?("http"), "Inspect must advertise http binding")
expect(errors, inspect.dig("identity", "methods") == ["did:web"], "Inspect must advertise did:web as the v00 identity method")
expect(errors, commands.fetch("supported").sort == %w[enroll grant inspect revoke status], "Inspect command set must match current v00 command set")
expect(errors, commands.fetch("grant_types").sort == GRANT_TYPES.sort, "Inspect grant_types must advertise the three published credential profiles")
expect(errors, inspect.dig("service", "did").start_with?("did:web:"), "Inspect service.did must be did:web")
expect(errors, inspect.dig("authentication", "methods") == %w[aep-jwt oauth-bearer api-key basic], "Inspect authentication methods must preserve preference order")
expect(errors, !commands.fetch("supported").include?("authenticate"), "authenticate must not appear as a Service command")
expect(errors, inspect.dig("http", "openapi", "url") == "/openapi.json", "Inspect must advertise an OpenAPI URI-reference")
expect(errors, inspect.dig("http", "openapi", "path_matching", "trailing_slash") == "strict", "Inspect OpenAPI vector must declare strict slash matching")

claims_inspect = vector("inspect/claims-catalog-advertisement.json").fetch("expected")
advertised_claims = %w[required preferred optional].flat_map do |requirement|
  claims_inspect.dig("claims", requirement)
end
expect(errors, advertised_claims.sort == CLAIM_NAMES.sort, "Claims Inspect vector must advertise the complete Claims catalog exactly once")

claims_catalog = vector("claims/person-contact-catalog.json").fetch("expected")
expect(errors, claims_catalog.keys.sort == CLAIM_NAMES.sort, "Claims catalog vector must contain every registered Claim Name")

claims_enroll = vector("enroll/request-claims-catalog.json").dig("input", "claims")
expect(errors, claims_enroll == claims_catalog, "Claims Enroll vector values must match the canonical Claims catalog vector")

forward_address = vector("claims/forward-compatible-address.json")
expect(errors, forward_address.dig("expected", "valid") == true, "Claims profile must accept additional object members")
expect(errors, forward_address.dig("expected", "unknown_object_members") == "ignore", "Unknown Claim object members must be ignored")

minimal_email = vector("claims/minimal-email.json")
expect(errors, minimal_email.dig("input", "claim_values", "contact.email") == "a@b", "Claims profile must cover the minimum three-character email shape")
expect(errors, minimal_email.dig("expected", "valid") == true, "The minimum email shape must be valid")
quoted_email = vector("claims/quoted-email.json")
expect(errors, quoted_email.dig("expected", "valid") == true, "A quoted RFC 5321 local-part must be valid")

%w[invalid-address invalid-birthdate invalid-country-shape invalid-email-domain invalid-email-dot-string invalid-email-format invalid-empty-email invalid-mobile invalid-value-type].each do |name|
  invalid = vector("claims/#{name}.json")
  expect(errors, invalid.dig("expected", "valid") == false, "#{name} must be a negative Claim Value vector")
end

negotiation = vector("claims/negotiation-compatibility.json")
expect(errors, negotiation.dig("expected", "enrollment_requirement_satisfied") == true, "Omitted preferred and optional Claims must not prevent enrollment")
expect(errors, negotiation.dig("expected", "omitted_preferred_allowed") == true, "Preferred Claim Values may be omitted")
%w[unknown_optional_action unknown_preferred_action unknown_submitted_default_action].each do |field|
  expect(errors, negotiation.dig("expected", field) == "ignore", "#{field} must preserve Claims forward compatibility")
end

unknown_required = vector("claims/unknown-required-claim.json")
expect(errors, unknown_required.dig("expected", "can_satisfy") == false, "An unsupported unknown required Claim cannot be satisfied")

COMMAND_PATHS.each do |command, path|
  expect(errors, endpoint(endpoint_base, command) == path, "endpoint_base must construct #{path} for #{command}")
end

default_endpoint = vector("inspect/default-endpoint-base.json")
expect(
  errors,
  !default_endpoint.dig("expected", "document", "http").key?("endpoint_base"),
  "Default endpoint-base vector must omit endpoint_base"
)
expect(
  errors,
  default_endpoint.dig("expected", "endpoint_base") == "/aep/",
  "Omitted endpoint_base must resolve to /aep/"
)

%w[
  authenticated-command-without-identity-method
  authentication-method-limit
  command-without-inspect
  grant-without-grant-types
  invalid-advertisement-identifiers
  invalid-openapi-reference
  missing-signing-algorithm
].each do |name|
  invalid = vector("inspect/#{name}.json")
  expect(errors, invalid.dig("expected", "valid") == false, "#{name} must be a negative Inspect vector")
end

protocol_version = vector("inspect/protocol-version.json")
protocol_version.dig("expected", "cases").each do |test_case|
  received = test_case.fetch("received")
  supported = test_case.fetch("supported", protocol_version.dig("input", "supported"))
  syntactically_valid = received.match?(/\A(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\z/)
  compatible = syntactically_valid && received.split(".", 2).first == supported.split(".", 2).first
  expect(errors, syntactically_valid == test_case.fetch("valid"), "#{test_case.fetch('name')} version syntax must match its expectation")
  expect(errors, compatible == test_case.fetch("compatible"), "#{test_case.fetch('name')} version compatibility must match its expectation")
end

forward_compatible = vector("inspect/forward-compatible-advertisements.json")
expect(errors, forward_compatible.dig("expected", "valid") == true, "Future same-major advertisements must remain valid")
%w[unknown_binding unknown_command unknown_field].each do |field|
  expect(errors, forward_compatible.dig("expected", field) == "ignore", "#{field} must preserve forward compatibility")
end

client_assertion = vector("client-assertion/enroll-claims.json").fetch("expected")
expect(errors, client_assertion.fetch("iss") == client_assertion.fetch("sub"), "Client assertion iss and sub must match")
expect(errors, client_assertion.fetch("aud") == inspect.dig("service", "did"), "Client assertion aud must equal Inspect service.did")
expect(errors, AUTHENTICATED_COMMANDS.include?(client_assertion.fetch("op")), "Client assertion op must be an authenticated command")
expect(errors, client_assertion.fetch("exp") - client_assertion.fetch("iat") <= 300, "Client assertion lifetime must be at most 300 seconds")
expect(errors, client_assertion.fetch("jti").is_a?(String) && !client_assertion.fetch("jti").empty?, "Client assertion jti must be non-empty")

assertion_validation = vector("client-assertion/validation-requirements.json")
assertion_header = assertion_validation.dig("expected", "header")
assertion_claims = assertion_validation.dig("expected", "claims")
assertion_rejections = assertion_validation.dig("expected", "reject")
expect(errors, assertion_header == {
  "alg" => "ES256",
  "kid" => assertion_claims.fetch("iss"),
  "typ" => "JWT"
}, "Client assertion validation must require the complete identity-bound JOSE header")
expect(errors, assertion_claims.fetch("iss") == assertion_claims.fetch("sub"), "Client assertion validation must bind iss and sub")
assertion_lifetime = assertion_claims.fetch("exp") - assertion_claims.fetch("iat")
expect(errors, assertion_lifetime.between?(1, 300), "Client assertion validation must bound assertion lifetime")
%w[
  excessive_lifetime
  fragmented_resource
  insecure_resource
  mismatched_kid
  mismatched_subject
  missing_kid
  missing_resource
  nonpositive_lifetime
  unexpected_resource
  wrong_typ
].each do |failure|
  expect(errors, assertion_rejections.include?(failure), "Client assertion validation must cover #{failure}")
end

did_web_resolution = vector("client-assertion/did-web-resolution.json")
expect(errors, did_web_resolution.dig("expected", "document_url").start_with?("https://"), "did:web resolution must use HTTPS")
%w[missing_referenced_method plaintext_http wrong_did].each do |failure|
  expect(errors, did_web_resolution.dig("expected", failure) == "reject", "did:web resolution must reject #{failure}")
end

{
  "enroll/request-minimal.json" => "enroll",
  "grant-revoke/grant-request-oauth-bearer.json" => "grant",
  "grant-revoke/revoke-request-oauth-bearer.json" => "revoke"
}.each do |path, command|
  expected = vector(path).fetch("expected")
  expect(errors, expected.fetch("method") == "POST", "#{path}: #{command} must use POST")
  expect(errors, expected.fetch("path") == COMMAND_PATHS.fetch(command), "#{path}: path must be #{COMMAND_PATHS.fetch(command)}")
  expect(errors, expected.fetch("content_type") == "application/aep+json", "#{path}: content_type must be application/aep+json")
  expect(errors, expected.fetch("authorization_scheme") == "AEP", "#{path}: authorization_scheme must be AEP")
  expect(errors, expected.fetch("client_assertion_op") == command, "#{path}: client_assertion_op must be #{command}")
end

enroll = vector("enroll/request-minimal.json")
expect(errors, enroll.dig("input", "agent_did").start_with?("did:web:"), "Enroll input agent_did must be did:web")
expect(errors, enroll.dig("input", "idempotency_key") == enroll.dig("expected", "idempotency_key"), "Enroll body idempotency_key must match expected header key")

status = vector("status/response-active.json").dig("expected", "body")
expect(errors, status.fetch("status") == "active", "Status active vector must return active")
expect(errors, !status.key?("owner_action_required"), "Canonical active Status must omit false owner_action_required")
expect(errors, !status.key?("requirements_pending"), "Canonical active Status must omit empty requirements_pending")

pending_enroll = vector("enroll/response-pending-verification-owner-action.json").dig("expected", "body")
expect(errors, pending_enroll.fetch("verification_pending").is_a?(Array), "Pending Enroll must expose verification_pending")
expect(errors, pending_enroll.fetch("owner_action_required") == "true", "Owner action signal must be independent and string true")
expect(errors, !pending_enroll.key?("requirements_pending"), "Pending Enroll verification vector must not alias requirements_pending")

pending_status = vector("status/response-pending-requirements.json").dig("expected", "body")
expect(errors, pending_status.fetch("requirements_pending").is_a?(Array), "Pending Status must expose requirements_pending")
expect(errors, !pending_status.key?("verification_pending"), "Pending Status requirements vector must not alias verification_pending")

revoke_all = vector("grant-revoke/revoke-request-all-grant-types.json").fetch("expected")
expect(errors, revoke_all.dig("body", "all_grant_types") == "true", "Revoke-all body must set all_grant_types to string true")
Array(revoke_all["must_not_contain"]).each do |field|
  expect(errors, !revoke_all.fetch("body").key?(field), "Revoke-all body must not contain #{field}")
end

revoke_response = vector("grant-revoke/revoke-response-empty.json").fetch("expected")
expect(errors, revoke_response.fetch("status") == 200, "Revoke response status must be 200")
expect(errors, revoke_response.fetch("body") == {}, "Revoke response body must be empty JSON object")

idempotency = vector("idempotency/enroll-conflict.json")
expect(errors, idempotency.dig("input", "first_body_hash") != idempotency.dig("input", "second_body_hash"), "Idempotency conflict must use different request body hashes")
expect(errors, idempotency.dig("expected", "status") == 409, "Idempotency conflict must return 409")
expect(errors, idempotency.dig("expected", "body", "code") == "idempotency_conflict", "Idempotency conflict must use idempotency_conflict code")

command_header = vector("idempotency/command-header.json")
expect(errors, command_header.dig("input", "commands") == POST_COMMANDS, "Every Core POST command must require the idempotency header")
expect(errors, command_header.dig("expected", "header_required") == true, "Core command idempotency header must be required")
expect(errors, command_header.dig("expected", "missing_or_empty_status") == 400, "Missing or empty Core command idempotency headers must return 400")
expect(errors, command_header.dig("expected", "missing_or_empty_code") == "invalid_request", "Missing or empty Core command idempotency headers must use invalid_request")
expect(errors, command_header.dig("expected", "enroll_body_key") == "optional", "The Enroll body idempotency key must remain optional")
expect(errors, command_header.dig("expected", "mismatched_enroll_body_status") == 400, "A mismatched Enroll body idempotency key must return 400")

command_replay = vector("idempotency/command-replay-conflict.json")
expect(errors, command_replay.dig("expected", "scope") == %w[agent_did idempotency_key], "Core command idempotency must use the Agent and key scope")
expect(errors, command_replay.dig("expected", "retention_seconds_minimum").to_i >= 3600, "Core command idempotency retention must be at least one hour")
expect(errors, command_replay.dig("expected", "exact_retry") == "cached_or_equivalent_success", "An exact Core command retry must return a cached or equivalent success")
%w[changed_body changed_command].each do |change|
  expect(errors, command_replay.dig("expected", change, "status") == 409, "#{change} idempotency reuse must return 409")
  expect(errors, command_replay.dig("expected", change, "code") == "idempotency_conflict", "#{change} idempotency reuse must use idempotency_conflict")
end

problem = vector("errors/not-recognized-problem.json").fetch("expected")
expect(errors, problem.fetch("status") == 401, "not_recognized problem must use HTTP 401")
expect(errors, problem.dig("body", "type") == "urn:aep:error:not_recognized", "not_recognized problem type must use AEP error URN")
expect(errors, problem.dig("body", "code") == "not_recognized", "not_recognized problem code must be not_recognized")
%w[verification_pending requirements_pending owner_action_required].each do |field|
  expect(errors, !problem.fetch("body").key?(field), "not_recognized must not disclose #{field}")
end

CREDENTIAL_PROFILES.each do |grant_type, config|
  expected = vector("#{config[:category]}/grant-response.json").fetch("expected")
  config[:required_fields].each do |field|
    expect(errors, expected.key?(field), "#{grant_type} Grant response must contain #{field}")
  end

  expect(errors, expected["credential_id"].nil? || expected["credential_id"].is_a?(String), "#{grant_type} credential_id must be a string when present")
  expect(errors, expected["scopes"].nil? || expected["scopes"].is_a?(Array), "#{grant_type} scopes must be null or an array when present")
  expect(errors, expected["token_type"] == config[:token_type], "#{grant_type} token_type must be #{config[:token_type]}") if config[:token_type]
end

POST_COMMANDS.each do |command|
  vector_path = command == "enroll" ? "enroll/request-minimal.json" : "grant-revoke/#{command}-request-oauth-bearer.json"
  expected = vector(vector_path).fetch("expected")
  expect(errors, expected["method"] == "POST", "#{command} must remain a POST command")
end

resource_auth = vector("protected-resource/authenticate-assertion.json").fetch("expected")
resource_claims = resource_auth.fetch("claims")
expect(errors, resource_claims.fetch("op") == "authenticate", "Protected-resource JWT must use authenticate")
expect(errors, resource_claims.fetch("aud") == inspect.dig("service", "did"), "Protected-resource JWT audience must equal Service DID")
expect(errors, resource_claims.fetch("resource").start_with?("https://"), "Protected-resource JWT must bind an HTTPS resource")
expect(errors, resource_claims.fetch("exp") - resource_claims.fetch("iat") <= 300, "Protected-resource JWT lifetime must be at most 300 seconds")
expect(errors, resource_auth.dig("challenge", "scheme") == "AEP", "Protected-resource challenge must use AEP scheme")
expect(errors, resource_auth.dig("challenge", "service_did") == resource_claims.fetch("aud"), "Challenge Service DID must match assertion audience")

substitution = vector("protected-resource/operation-substitution-rejected.json")
expect(errors, substitution.dig("input", "operations").sort == AUTHENTICATED_OPERATIONS.sort, "Substitution vector must cover every registered authenticated operation")
expect(errors, substitution.dig("expected", "allowed").length == AUTHENTICATED_OPERATIONS.length, "Only one target is allowed per operation")

presentations = vector("protected-resource/credential-presentations.json").fetch("expected")
expect(errors, presentations.dig("oauth-bearer", "scheme") == "Bearer", "OAuth presentation must use Bearer")
expect(errors, presentations.dig("basic", "scheme") == "Basic", "Basic presentation must use Basic")
expect(errors, presentations.dig("api-key", "header") == "x-api-key", "API-key presentation example must use the response-selected illustrative header")

carriers = vector("protected-resource/authorization-carriers.json").fetch("expected")
%w[jwt bearer basic].each do |method|
  standard = carriers.fetch("standard_#{method}")
  dedicated = carriers.fetch("dedicated_#{method}")
  expect(errors, standard.fetch("carrier") == "Authorization", "#{method} standard carrier must be Authorization")
  expect(errors, dedicated.fetch("carrier") == "AEP-Authorization", "#{method} dedicated carrier must be AEP-Authorization")
  expect(errors, standard.fetch("scheme") == dedicated.fetch("scheme"), "#{method} scheme must be preserved across carriers")
end

ambiguity = vector("protected-resource/authorization-ambiguity.json").fetch("expected")
expect(errors, ambiguity.fetch("code") == "not_recognized", "Carrier ambiguity must use non-disclosing not_recognized")
expect(errors, ambiguity.fetch("fallback") == false, "Invalid dedicated credentials must not fall back")

composition = vector("protected-resource/authorization-payment-composition.json").fetch("expected")
expect(errors, composition.dig("mpp", "ambiguous") == false, "Dedicated AEP plus MPP Payment authorization must be valid")
expect(errors, composition.dig("x402", "ambiguous") == false, "Dedicated AEP plus x402 signature must be valid")
expect(errors, composition.fetch("payment_advertised_after_aep") == true, "Payment must be advertised only after AEP succeeds")

field_safety = vector("protected-resource/authorization-field-safety.json").fetch("expected")
expect(errors, field_safety.fetch("field_name_match") == "case-insensitive", "AEP-Authorization field-name matching must be case-insensitive")
%w[Authorization AEP-Authorization PAYMENT-SIGNATURE api-key-header].each do |field|
  expect(errors, field_safety.fetch("strip_on_disallowed_redirect").include?(field), "Redirect stripping must include #{field}")
end

wrong_header = vector("protected-resource/api-key-wrong-header-rejected.json")
expect(errors, wrong_header.dig("input", "issued_header").downcase != wrong_header.dig("input", "presented_header").downcase, "Wrong-header vector must use distinct header names")
expect(errors, wrong_header.dig("expected", "accepted") == false, "API key under wrong header must be rejected")

redirects = vector("protected-resource/redirect-safety.json").fetch("expected")
expect(errors, redirects.dig("same_origin", "credential_forwarded") == false, "Same-origin changed resource must use a new assertion")
expect(errors, redirects.dig("cross_origin", "anonymous_restart") == true, "Cross-origin redirect must restart anonymously")
%w[assertion_forwarded session_credential_forwarded api_key_header_forwarded].each do |field|
  expect(errors, redirects.dig("cross_origin", field) == false, "Cross-origin redirect must not forward #{field}")
end

cache = vector("caching/public-discovery-cache.json").fetch("expected")
expect(errors, cache.fetch("default_freshness_seconds") == "300", "Public discovery default freshness must be 300 seconds")
expect(errors, cache.fetch("no_cache") == "revalidate", "no-cache must require revalidation")
expect(errors, cache.fetch("no_store") == "do-not-persist", "no-store must prohibit persistence")

openapi_url = vector("openapi/url-resolution.json").fetch("expected")
expect(errors, openapi_url.fetch("forwarded_headers") == [], "OpenAPI retrieval must be anonymous")
expect(errors, openapi_url.fetch("cross_origin_https") == "allowed-anonymous", "Cross-origin HTTPS OpenAPI retrieval must remain anonymous")

openapi_security = vector("openapi/security-inheritance.json")
expect(errors, openapi_security.dig("input", "security_scheme", "x-aep-authentication-method") == "aep-jwt", "OpenAPI extension must bind a registered AEP authentication method")
expect(errors, openapi_security.dig("expected", "multiple_schemes_one_object") == "all-required", "OpenAPI compound requirements must require every scheme")

openapi_paths = vector("openapi/path-matching.json").fetch("expected")
expect(errors, openapi_paths.fetch("method") == "GET", "OpenAPI request methods must be uppercase")
expect(errors, openapi_paths.fetch("query_selects_operation") == false, "Query parameters must not select OpenAPI operations")
expect(errors, openapi_paths.fetch("similar_templates") == "contradiction", "Similar applicable templates must fail closed")

grant_before_enroll = vector("grant-revoke/grant-before-enroll-rejected.json").fetch("expected")
expect(errors, grant_before_enroll.fetch("code") == "not_recognized", "Grant before enrollment must be rejected as not_recognized")
expect(errors, grant_before_enroll.fetch("implicit_enrollment") == false, "Grant must never implicitly enroll")

platform_discovery = vector("platform/discovery.json").fetch("expected")
platform_endpoints = platform_discovery.fetch("endpoints")
expect(errors, platform_discovery.fetch("aep_version") == "1.0", "Platform discovery must advertise AEP version 1.0")
expect(errors, platform_discovery.dig("identity", "did_methods") == ["did:web"], "Platform discovery must advertise did:web")
expect(errors, platform_discovery.dig("platform", "hosted_verification") == true, "Platform hosted_verification vector must advertise support")
expect(errors, platform_endpoints.key?("hosted_verification"), "Platform hosted verification support must include an endpoint")
expect(errors, !platform_endpoints.key?("rotate_key"), "Platform discovery must not advertise rotate_key")
expect(errors, !platform_endpoints.key?("rotate-key"), "Platform discovery must not advertise rotate-key")
platform_lifetime = platform_discovery.dig("signing", "default_lifetime_seconds")
expect(errors, platform_lifetime.is_a?(String) && platform_lifetime.match?(/\A[1-9][0-9]*\z/), "Platform default_lifetime_seconds must be a positive numeric string")
expect(errors, platform_lifetime.to_i <= 300, "Platform default_lifetime_seconds must be at most 300 seconds")

platform_provision = vector("platform/provision-response.json").fetch("expected")
expect(errors, platform_provision.fetch("agent_did").start_with?("did:web:"), "Platform provision response agent_did must be did:web")
expect(errors, platform_provision.fetch("service_did").start_with?("did:web:"), "Platform provision response service_did must be did:web")
expect(errors, PLATFORM_LIFECYCLE_STATES.include?(platform_provision.fetch("status")), "Platform provision response status must be a lifecycle state")
expect(errors, platform_provision.fetch("key_id") == platform_provision.fetch("agent_did"), "Platform key_id must equal the did:web Agent DID")

platform_distinct = vector("platform/provision-response-distinct-services.json").fetch("expected")
first_platform_identity = platform_distinct.fetch("first_response")
second_platform_identity = platform_distinct.fetch("second_response")
expect(errors, first_platform_identity.fetch("service_did") != second_platform_identity.fetch("service_did"), "Distinct-Service vector must use two Service DIDs")
expect(errors, first_platform_identity.fetch("agent_did") != second_platform_identity.fetch("agent_did"), "Platform must use distinct Agent DIDs for unrelated Services")
expect(errors, first_platform_identity.fetch("key_id") == first_platform_identity.fetch("agent_did"), "First distinct-Service key_id must equal its did:web Agent DID")
expect(errors, second_platform_identity.fetch("key_id") == second_platform_identity.fetch("agent_did"), "Second distinct-Service key_id must equal its did:web Agent DID")

platform_list = vector("platform/list-response.json").fetch("expected")
expect(errors, platform_list.fetch("count").is_a?(String), "Platform list count must be a numeric string")
expect(errors, platform_list.fetch("total").is_a?(String), "Platform list total must be a numeric string")
expect(errors, platform_list.fetch("count").match?(/\A(?:0|[1-9][0-9]*)\z/), "Platform list count must be non-negative")
expect(errors, platform_list.fetch("total").match?(/\A(?:0|[1-9][0-9]*)\z/), "Platform list total must be non-negative")

platform_sign = vector("platform/sign-request.json").fetch("input")
sign_lifetime = platform_sign.fetch("lifetime_seconds")
expect(errors, sign_lifetime.is_a?(String) && sign_lifetime.match?(/\A[1-9][0-9]*\z/), "Platform sign lifetime_seconds must be a positive numeric string")
expect(errors, sign_lifetime.to_i <= 300, "Platform sign lifetime_seconds must be at most 300 seconds")
expect(errors, AUTHENTICATED_COMMANDS.include?(platform_sign.fetch("op")), "Platform sign op must be an authenticated AEP command")
expect(errors, platform_sign.fetch("platform_context").is_a?(Hash), "Platform sign platform_context must be an opaque object")

platform_sign_completed = vector("platform/sign-response.json").fetch("expected")
expect(errors, platform_sign_completed.fetch("status") == "completed", "Completed Platform Sign must use completed status")
expect(errors, platform_sign_completed.fetch("platform_context") == platform_sign.fetch("platform_context"), "Opaque Platform context must round trip")
platform_sign_pending = vector("platform/sign-response-pending.json").fetch("expected")
expect(errors, platform_sign_pending.fetch("status") == "pending", "Pending Platform Sign must use pending status")
expect(errors, platform_sign_pending.fetch("retry_after_seconds").to_i.between?(1, 300), "Pending Platform Sign retry cadence must be 1 through 300")

platform_idempotency = vector("platform/idempotency-replay-conflict.json")
expect(errors, platform_idempotency.dig("expected", "retention_seconds_minimum").to_i >= 3600, "Platform idempotency retention must be at least one hour")
expect(errors, platform_idempotency.dig("input", "initial_sign_key") != platform_idempotency.dig("input", "final_sign_key"), "Initial and final Sign must use separate idempotency keys")

platform_lifecycle = vector("platform/lifecycle-response.json").fetch("expected")
expect(errors, PLATFORM_LIFECYCLE_STATES.include?(platform_lifecycle.fetch("status")), "Platform lifecycle response status must be a lifecycle state")

platform_verification = vector("platform/verification-response-recognized.json").fetch("expected")
expect(errors, platform_verification.fetch("verified") == true, "Platform recognized verification must set verified true")
expect(errors, platform_verification.fetch("reason") == "verified", "Platform recognized verification reason must be verified")
expect(errors, AUTHENTICATED_COMMANDS.include?(platform_verification.fetch("op")), "Platform verification op must be an authenticated AEP command")

platform_unrecognized = vector("platform/verification-response-unrecognized.json").fetch("expected")
expect(errors, platform_unrecognized.fetch("verified") == false, "Platform unrecognized verification must set verified false")
expect(errors, platform_unrecognized.fetch("reason") == "not_recognized", "Platform unrecognized verification reason must be not_recognized")
%w[agent_did agent_identity_id op status].each do |field|
  expect(errors, !platform_unrecognized.key?(field), "Platform unrecognized verification must not disclose #{field}")
end

if errors.empty?
  puts "Conformance harness OK"
else
  warn errors.join("\n")
  exit 1
end
