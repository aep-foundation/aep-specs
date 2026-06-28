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
GRANT_TYPES = %w[oauth-bearer api-key basic].freeze
CREDENTIAL_PROFILES = {
  "oauth-bearer" => {
    category: "credentials/oauth-bearer",
    required_fields: %w[access_token expires_at scopes token_type],
    token_type: "Bearer"
  },
  "api-key" => {
    category: "credentials/api-key",
    required_fields: %w[api_key expires_at header scopes]
  },
  "basic" => {
    category: "credentials/basic",
    required_fields: %w[expires_at password scopes username]
  }
}.freeze

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

COMMAND_PATHS.each do |command, path|
  expect(errors, endpoint(endpoint_base, command) == path, "endpoint_base must construct #{path} for #{command}")
end

client_assertion = vector("client-assertion/enroll-claims.json").fetch("expected")
expect(errors, client_assertion.fetch("iss") == client_assertion.fetch("sub"), "Client assertion iss and sub must match")
expect(errors, client_assertion.fetch("aud") == inspect.dig("service", "did"), "Client assertion aud must equal Inspect service.did")
expect(errors, AUTHENTICATED_COMMANDS.include?(client_assertion.fetch("op")), "Client assertion op must be an authenticated command")
expect(errors, client_assertion.fetch("exp") - client_assertion.fetch("iat") <= 300, "Client assertion lifetime must be at most 300 seconds")
expect(errors, client_assertion.fetch("jti").is_a?(String) && !client_assertion.fetch("jti").empty?, "Client assertion jti must be non-empty")

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
expect(errors, status.fetch("owner_action_required") == "false", "Status owner_action_required must use string boolean")
expect(errors, status.fetch("requirements_pending").is_a?(Array), "Status requirements_pending must be an array")

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

problem = vector("errors/not-recognized-problem.json").fetch("expected")
expect(errors, problem.fetch("status") == 401, "not_recognized problem must use HTTP 401")
expect(errors, problem.dig("body", "type") == "urn:aep:error:not_recognized", "not_recognized problem type must use AEP error URN")
expect(errors, problem.dig("body", "code") == "not_recognized", "not_recognized problem code must be not_recognized")

CREDENTIAL_PROFILES.each do |grant_type, config|
  expected = vector("#{config[:category]}/grant-response.json").fetch("expected")
  config[:required_fields].each do |field|
    expect(errors, expected.key?(field), "#{grant_type} Grant response must contain #{field}")
  end

  expect(errors, expected["credential_id"].nil? || expected["credential_id"].is_a?(String), "#{grant_type} credential_id must be a string when present")
  expect(errors, expected.fetch("scopes").is_a?(Array), "#{grant_type} scopes must be an array")
  expect(errors, expected["token_type"] == config[:token_type], "#{grant_type} token_type must be #{config[:token_type]}") if config[:token_type]
end

POST_COMMANDS.each do |command|
  vector_path = command == "enroll" ? "enroll/request-minimal.json" : "grant-revoke/#{command}-request-oauth-bearer.json"
  expected = vector(vector_path).fetch("expected")
  expect(errors, expected["method"] == "POST", "#{command} must remain a POST command")
end

if errors.empty?
  puts "Conformance harness OK"
else
  warn errors.join("\n")
  exit 1
end
