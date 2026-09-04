#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "time"
require "timeout"
require "uri"

ROOT = File.expand_path("../..", __dir__)
PARENT = File.dirname(ROOT)
LANGUAGES = %w[node go java python rust].freeze
DISPLAY_NAMES = {
  "node" => "Node.js",
  "go" => "Go",
  "java" => "Java",
  "python" => "Python",
  "rust" => "Rust"
}.freeze
TIMEOUT_SECONDS = Integer(ENV.fetch("AEP_INTEROPERABILITY_TIMEOUT", "120"), 10)
PLATFORM_PORT_BASE = Integer(ENV.fetch("AEP_INTEROPERABILITY_PLATFORM_PORT", "47100"), 10)
SERVICE_PORT_BASE = Integer(ENV.fetch("AEP_INTEROPERABILITY_SERVICE_PORT", "47101"), 10)

directories = LANGUAGES.to_h do |language|
  variable = "AEP_#{language.upcase}_DIR"
  [language, File.expand_path(ENV.fetch(variable, File.join(PARENT, "aep-#{language}")))]
end
output_directory = File.expand_path(
  ENV.fetch("AEP_INTEROPERABILITY_OUTPUT", File.join(ROOT, ".interoperability/reports"))
)

def java_classpath(directory)
  path = File.join(directory, ".interop/work/java-classpath.txt")
  FileUtils.mkdir_p(File.dirname(path))
  output, error, status = Open3.capture3(
    "./mvnw", "--quiet", "--batch-mode", "--no-transfer-progress", "-f", "examples/pom.xml",
    "-Dmdep.outputFile=#{path}", "dependency:build-classpath", chdir: directory
  )
  raise "Cannot prepare the Java interoperability classpath: #{error.empty? ? output : error}" unless
    status.success?

  [File.join(directory, "examples/target/classes"), File.read(path).strip].join(File::PATH_SEPARATOR)
end

def configurations(directories, java_classpath, service_port, platform_url)
  service_url = "http://127.0.0.1:#{service_port}"
  listen = "127.0.0.1:#{service_port}"
  {
    "node" => {
      service: [
        { "PORT" => service_port.to_s,
          "SERVICE_DID" => "did:web:127.0.0.1%3A#{service_port}:services:example-service" },
        ["node", "examples/aep-service-credential-api-key/dist/index.js"]
      ],
      agent: [
        { "PLATFORM_URL" => platform_url, "SERVICE_URL" => service_url },
        ["node", "examples/aep-agent-did-web-grant-status-revoke/dist/index.js"]
      ]
    },
    "go" => {
      service: [{}, ["go", "run", "./cmd/aep-interop", "server", "-listen", listen]],
      agent: [{}, ["go", "run", "./cmd/aep-interop", "agent", "-platform-url", platform_url,
                    "-service-url", service_url]]
    },
    "java" => {
      service: [{}, ["java", "-cp", java_classpath,
                     "foundation.aep.examples.NodeInteroperability", "server", "--listen", listen]],
      agent: [{}, ["java", "-cp", java_classpath,
                   "foundation.aep.examples.NodeInteroperability", "agent", "--platform-url",
                   platform_url, "--service-url", service_url]]
    },
    "python" => {
      service: [{}, ["uv", "run", "python", "scripts/node_interoperability.py", "server",
                     "--listen", listen]],
      agent: [{}, ["uv", "run", "python", "scripts/node_interoperability.py", "agent",
                   "--platform-url", platform_url, "--service-url", service_url]]
    },
    "rust" => {
      service: [{}, ["cargo", "run", "--quiet", "--locked", "-p", "aep-examples",
                     "--bin", "aep-interop", "--", "server", "--listen", listen]],
      agent: [{}, ["cargo", "run", "--quiet", "--locked", "-p", "aep-examples",
                   "--bin", "aep-interop", "--", "agent", "--platform-url", platform_url,
                   "--service-url", service_url]]
    }
  }.each_with_object({}) do |(language, value), result|
    result[language] = value.merge(directory: directories.fetch(language), service_url: service_url)
  end
end

def commit(directory)
  output, status = Open3.capture2("git", "rev-parse", "HEAD", chdir: directory)
  raise "Cannot identify SDK commit in #{directory}" unless status.success?

  changes, clean = Open3.capture2("git", "status", "--porcelain", chdir: directory)
  raise "SDK repository has uncommitted changes: #{directory}" unless clean.success? && changes.empty?

  output.strip
end

def wait_until_ready(url, process, label, log_path)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TIMEOUT_SECONDS
  loop do
    raise "#{label} exited before becoming ready: #{File.read(log_path)}" unless process.alive?

    begin
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 1) do |http|
        http.get(uri.request_uri)
      end
      return if response.is_a?(Net::HTTPSuccess)
    rescue IOError, SystemCallError, Timeout::Error
      nil
    end
    raise "#{label} did not become ready within #{TIMEOUT_SECONDS} seconds" if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep 0.1
  end
end

def run_bounded(environment, command, directory)
  output = +""
  error = +""
  status = nil
  Open3.popen3(environment, *command, chdir: directory, pgroup: true) do |input, stdout, stderr, wait|
    input.close
    output_reader = Thread.new { stdout.read }
    error_reader = Thread.new { stderr.read }
    unless wait.join(TIMEOUT_SECONDS)
      Process.kill("TERM", -wait.pid)
      wait.join(5) || Process.kill("KILL", -wait.pid)
      raise "Agent timed out after #{TIMEOUT_SECONDS} seconds"
    end
    status = wait.value
    output = output_reader.value
    error = error_reader.value
  end
  [status.success?, output.strip, error.strip]
end

def stop_process(process)
  return unless process&.alive?

  Process.kill("TERM", -process.pid)
  process.join(5) || Process.kill("KILL", -process.pid)
rescue Errno::ESRCH
  nil
end

def validate_agent_evidence(language, output)
  document = JSON.parse(output)
  if language == "node"
    raise "Node Agent did not enroll" unless document.dig("enroll", "status") == "active"
    raise "Node Agent did not select the API-key grant" unless document["credentialMode"] == "api-key"
    raise "Node Agent did not obtain a credential" unless document.dig("grant", "credential_id").is_a?(String)
    raise "Node Agent did not access the protected resource" if document["resource"].nil?
    raise "Node Agent did not revoke the credential" unless document["revoke"].is_a?(Hash)
  else
    display_name = DISPLAY_NAMES.fetch(language)
    raise "#{display_name} Agent did not enroll" unless document["enrollment"] == "active"
    raise "#{display_name} Agent did not select the API-key grant" unless
      document["credential_mode"] == "api-key"
    raise "#{display_name} Agent did not access the protected resource" unless
      document["protected_resource_status"] == 200
    raise "#{display_name} Agent retained the revoked credential" unless document["revoked"] == true
  end

  {
    credential_mode: "api-key",
    enrollment: "active",
    protected_resource: "accessed",
    revoke: "completed"
  }
rescue JSON::ParserError => error
  raise "#{DISPLAY_NAMES.fetch(language)} Agent returned invalid JSON: #{error.message}"
end

def write_reports(output_directory, commits, cases)
  FileUtils.mkdir_p(output_directory)
  report = {
    generated_at: Time.now.utc.iso8601,
    implementations: commits,
    platform: "node",
    cases: cases
  }
  File.write(File.join(output_directory, "agent-service-matrix.json"),
             "#{JSON.pretty_generate(report)}\n")

  rows = LANGUAGES.map do |agent|
    cells = LANGUAGES.map do |service|
      item = cases.find { |candidate| candidate[:agent] == agent && candidate[:service] == service }
      item[:status] == "passed" ? "Pass" : "Fail"
    end
    "| #{DISPLAY_NAMES.fetch(agent)} | #{cells.join(' | ')} |"
  end
  failures = cases.reject { |item| item[:status] == "passed" }
  markdown = [
    "# AEP Agent-to-Service Interoperability Matrix",
    "",
    "Generated at #{report[:generated_at]} against the commits recorded in " \
      "`agent-service-matrix.json`. Every Agent used the canonical Node.js ephemeral Platform.",
    "",
    "| Agent / Service | Node.js | Go | Java | Python | Rust |",
    "| --- | --- | --- | --- | --- | --- |",
    *rows,
    ""
  ]
  unless failures.empty?
    markdown.concat(["## Failures", ""])
    failures.each do |item|
      message = item[:message].to_s.lines.map(&:strip).reject(&:empty?).join(" ")
      markdown << "- #{item[:agent]} Agent -> #{item[:service]} Service: #{message}"
    end
    markdown << ""
  end
  File.write(File.join(output_directory, "agent-service-matrix.md"),
             "#{markdown.join("\n")}\n")
end

missing = directories.reject { |_language, directory| File.directory?(directory) }
raise "Missing SDK repositories: #{missing.values.join(', ')}" unless missing.empty?

FileUtils.mkdir_p(output_directory)
commits = directories.transform_values { |directory| commit(directory) }
java_runtime_classpath = java_classpath(directories.fetch("java"))
cases = []

LANGUAGES.each_with_index do |service, service_index|
  LANGUAGES.each_with_index do |agent, agent_index|
    pair_index = (service_index * LANGUAGES.length) + agent_index
    platform_port = PLATFORM_PORT_BASE + (pair_index * 2)
    service_port = SERVICE_PORT_BASE + (pair_index * 2)
    platform_url = "http://127.0.0.1:#{platform_port}"
    configuration = configurations(
      directories, java_runtime_classpath, service_port, platform_url
    )
    service_configuration = configuration.fetch(service)
    agent_configuration = configuration.fetch(agent)
    label = "#{agent}-agent-#{service}-service"
    platform_log_path = File.join(output_directory, "#{label}-platform.log")
    service_log_path = File.join(output_directory, "#{label}.log")
    platform_process = nil
    service_process = nil
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      File.open(platform_log_path, "w") do |platform_log|
        platform_process = Process.detach(Process.spawn(
          {
            "DID_HOST" => "127.0.0.1:#{platform_port}",
            "PORT" => platform_port.to_s,
            "PUBLIC_BASE_URL" => platform_url
          },
          "node", "examples/aep-platform-ephemeral/dist/index.js",
          chdir: directories.fetch("node"), out: platform_log, err: [:child, :out], pgroup: true
        ))
        wait_until_ready("#{platform_url}/health", platform_process, "Node Platform", platform_log_path)

        File.open(service_log_path, "w") do |service_log|
          environment, command = service_configuration.fetch(:service)
          service_process = Process.detach(Process.spawn(
            environment, *command, chdir: service_configuration.fetch(:directory), out: service_log,
            err: [:child, :out], pgroup: true
          ))
          wait_until_ready("#{service_configuration.fetch(:service_url)}/.well-known/aep",
                           service_process, "#{DISPLAY_NAMES.fetch(service)} Service", service_log_path)

          success, output, error = run_bounded(
            *agent_configuration.fetch(:agent), agent_configuration.fetch(:directory)
          )
          unless success
            message = error.empty? ? output : error
            raise(message.empty? ? "Agent exited unsuccessfully" : message)
          end

          cases << {
            agent: agent,
            service: service,
            status: "passed",
            duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
            evidence: validate_agent_evidence(agent, output)
          }
        end
      end
    rescue StandardError => error
      cases << { agent: agent, service: service, status: "failed", message: error.message }
    ensure
      stop_process(service_process)
      stop_process(platform_process)
    end
  end
end

write_reports(output_directory, commits, cases)
failures = cases.count { |item| item[:status] != "passed" }
puts "AEP Agent-to-Service interoperability: #{cases.length - failures}/#{cases.length} pairings passed"
exit 1 unless failures.zero?
