# frozen_string_literal: true

require "cgi"
require "date"
require "yaml"

draft_paths = ARGV[0...-1]
output = ARGV[-1]
abort "usage: render_index.rb DRAFT.md [DRAFT.md ...] OUTPUT.html" if draft_paths.empty? || output.nil?

RELEASE_BASE = "https://github.com/aep-foundation/aep-specs/releases/latest/download"
REPO_BASE = "https://github.com/aep-foundation/aep-specs"

def frontmatter(text)
  match = text.match(/\A---\n(.*?)\n\.\.\./m)
  abort "missing YAML front matter" unless match

  YAML.safe_load(match[1], aliases: true, permitted_classes: [Date])
end

def abstract(text)
  match = text.match(/--- abstract\n\n(.*?)\n\n--- middle/m)
  return "" unless match

  match[1].gsub(/\s+/, " ").strip
end

def first_sentence(text)
  sentence = text.match(/.*?[.!?](?:\s|$)/)&.[](0)&.strip
  sentence || text
end

def datatracker_url(docname)
  base = docname.sub(/-\d{2}\z/, "")
  "https://datatracker.ietf.org/doc/#{base}/"
end

def release_link(docname, ext)
  "#{RELEASE_BASE}/#{docname}.#{ext}"
end

def h(value)
  CGI.escapeHTML(value.to_s)
end

drafts = draft_paths.map do |path|
  text = File.read(path)
  meta = frontmatter(text)
  docname = meta.fetch("docname")
  {
    docname: docname,
    title: meta.fetch("title"),
    description: first_sentence(abstract(text)),
    datatracker: datatracker_url(docname)
  }
end

draft_rows = drafts.map do |draft|
  docname = h(draft[:docname])
  description = h(draft[:description])
  datatracker = h(draft[:datatracker])

  <<~HTML
            <tr>
              <td class="draft-id" data-label="Draft">#{docname}</td>
              <td data-label="Description">#{description}</td>
              <td data-label="Formats">
                <span class="links">
                  <a href="#{datatracker}">IETF</a>
                  <a href="#{h(release_link(draft[:docname], "html"))}">HTML</a>
                  <a href="#{h(release_link(draft[:docname], "txt"))}">TXT</a>
                  <a href="#{h(release_link(draft[:docname], "xml"))}">XML</a>
                  <a href="#{h(release_link(draft[:docname], "pdf"))}">PDF</a>
                </span>
              </td>
            </tr>
  HTML
end.join.lines.map { |line| "          #{line}" }.join.rstrip

html = <<~HTML
  <!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>AEP Foundation Specifications</title>
      <style>
        :root {
          color-scheme: light dark;
          --bg: #f8fafc;
          --fg: #172033;
          --muted: #5b6475;
          --panel: #ffffff;
          --border: #d7dce5;
          --link: #0b5cad;
        }

        @media (prefers-color-scheme: dark) {
          :root {
            --bg: #10141c;
            --fg: #eef2f8;
            --muted: #aeb7c8;
            --panel: #171d28;
            --border: #2d3545;
            --link: #8ab8ff;
          }
        }

        *,
        *::before,
        *::after {
          box-sizing: border-box;
        }

        body {
          margin: 0;
          background: var(--bg);
          color: var(--fg);
          font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          line-height: 1.5;
        }

        main {
          width: min(960px, calc(100% - 32px));
          margin: 0 auto;
          padding: 48px 0;
        }

        header {
          margin-bottom: 32px;
        }

        h1 {
          margin: 0 0 8px;
          font-size: clamp(2rem, 6vw, 3.5rem);
          line-height: 1.05;
        }

        h2 {
          margin-top: 36px;
        }

        p {
          max-width: 760px;
          color: var(--muted);
        }

        a {
          color: var(--link);
        }

        table {
          width: 100%;
          border-collapse: collapse;
          background: var(--panel);
          border: 1px solid var(--border);
          border-radius: 8px;
          overflow: hidden;
        }

        th,
        td {
          padding: 12px;
          border-bottom: 1px solid var(--border);
          text-align: left;
          vertical-align: top;
        }

        tbody tr:last-child td {
          border-bottom: none;
        }

        th {
          font-size: 0.9rem;
          color: var(--muted);
        }

        .draft-id {
          font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
          font-size: 0.92rem;
          white-space: nowrap;
        }

        td:last-child {
          white-space: nowrap;
        }

        .links {
          display: inline-flex;
          gap: 10px;
          flex-wrap: nowrap;
          white-space: nowrap;
        }

        @media (max-width: 640px) {
          main {
            padding: 32px 0;
          }

          table,
          tbody,
          tr,
          td {
            display: block;
            width: 100%;
          }

          thead {
            display: none;
          }

          table {
            background: transparent;
            border: none;
            border-radius: 0;
          }

          tbody tr {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 8px;
            margin-bottom: 14px;
            padding: 4px 0;
          }

          td {
            border-bottom: 1px solid var(--border);
            padding: 10px 14px;
            white-space: normal;
          }

          tbody tr td:last-child {
            border-bottom: none;
          }

          td::before {
            content: attr(data-label);
            display: block;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            color: var(--muted);
            margin-bottom: 4px;
          }

          .draft-id {
            white-space: normal;
            word-break: break-word;
          }
        }
      </style>
    </head>
    <body>
      <main>
        <header>
          <h1>AEP Foundation Specifications</h1>
          <p>
            Internet-Draft sources and rendered specifications for the Agent
            Enrollment Protocol.
          </p>
        </header>

        <h2>Current Drafts</h2>
        <p>
          The current set contains one independently implementable core protocol
          draft and three companion session-credential drafts. The core draft
          defines Inspect, Enroll, Grant, Revoke, Status, HTTP discovery and
          transport, <code>did:web</code> identity, client assertion
          authentication, errors, security, privacy, and IANA registrations. The
          credential drafts define concrete Grant/Revoke formats that services
          may advertise when they issue session credentials.
        </p>
        <table>
          <thead>
            <tr>
              <th>Draft</th>
              <th>Description</th>
              <th>Formats</th>
            </tr>
          </thead>
          <tbody>
  #{draft_rows}
          </tbody>
        </table>

        <h2>Conformance</h2>
        <table>
          <thead>
            <tr>
              <th>Resource</th>
              <th>Description</th>
              <th>Source</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="draft-id" data-label="Resource">Conformance model</td>
              <td data-label="Description">Initial role and profile model for the published AEP draft set.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="#{REPO_BASE}/blob/main/ietf/conformance/README.md">Markdown</a>
                </span>
              </td>
            </tr>
            <tr>
              <td class="draft-id" data-label="Resource">Test vectors</td>
              <td data-label="Description">Deterministic fixtures for current-v00 Agent and Service behavior.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="#{REPO_BASE}/tree/main/ietf/test-vectors">JSON</a>
                  <a href="#{REPO_BASE}/blob/main/ietf/test-vectors/README.md">Markdown</a>
                </span>
              </td>
            </tr>
            <tr>
              <td class="draft-id" data-label="Resource">JSON Schemas</td>
              <td data-label="Description">Validation schemas for stable wire objects used by the current test vectors.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="schemas/">JSON</a>
                  <a href="#{REPO_BASE}/blob/main/ietf/schemas/README.md">Markdown</a>
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <h2>Guides</h2>
        <table>
          <thead>
            <tr>
              <th>Guide</th>
              <th>Description</th>
              <th>Source</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="draft-id" data-label="Guide">Implementer guide</td>
              <td data-label="Description">Non-normative guidance for command sequencing, idempotency, client assertions, credential choice, and revocation strategy.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="#{REPO_BASE}/blob/main/ietf/guides/implementer-guide.md">Markdown</a>
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <h2>Governance</h2>
        <table>
          <thead>
            <tr>
              <th>Resource</th>
              <th>Description</th>
              <th>Source</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="draft-id" data-label="Resource">Project governance</td>
              <td data-label="Description">Versioning, compatibility, artifact publication, review, and change management guidance.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="#{REPO_BASE}/blob/main/GOVERNANCE.md">Markdown</a>
                </span>
              </td>
            </tr>
            <tr>
              <td class="draft-id" data-label="Resource">Extension registration</td>
              <td data-label="Description">Non-normative guidance for extension identifiers, grant types, and support artifacts before formal IANA registries exist.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="#{REPO_BASE}/blob/main/ietf/governance/extension-registration.md">Markdown</a>
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <h2>Examples</h2>
        <table>
          <thead>
            <tr>
              <th>Example</th>
              <th>Description</th>
              <th>Source</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="draft-id" data-label="Example">Complete Inspect document</td>
              <td data-label="Description">A Service advertising the baseline HTTP binding, did:web, and the initial Grant credential types.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="examples/inspect-document.html">HTML</a>
                  <a href="#{REPO_BASE}/blob/main/ietf/examples/inspect-document.md">Markdown</a>
                </span>
              </td>
            </tr>
            <tr>
              <td class="draft-id" data-label="Example">Enroll, Grant, and Revoke transcript</td>
              <td data-label="Description">A minimal successful flow from enrollment through session credential issuance and revocation.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="examples/enroll-grant-revoke-transcript.html">HTML</a>
                  <a href="#{REPO_BASE}/blob/main/ietf/examples/enroll-grant-revoke-transcript.md">Markdown</a>
                </span>
              </td>
            </tr>
            <tr>
              <td class="draft-id" data-label="Example">Pending Enroll and Status polling</td>
              <td data-label="Description">A pending enrollment flow followed by Status polling until the identity becomes active.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="examples/pending-enroll-status.html">HTML</a>
                  <a href="#{REPO_BASE}/blob/main/ietf/examples/pending-enroll-status.md">Markdown</a>
                </span>
              </td>
            </tr>
            <tr>
              <td class="draft-id" data-label="Example">Status states</td>
              <td data-label="Description">Representative Status responses for pending, unavailable, suspended, terminated, and rejected identities.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="examples/status-states.html">HTML</a>
                  <a href="#{REPO_BASE}/blob/main/ietf/examples/status-states.md">Markdown</a>
                </span>
              </td>
            </tr>
            <tr>
              <td class="draft-id" data-label="Example">API-key Grant and Revoke</td>
              <td data-label="Description">API-key session credential issuance, presentation, per-credential Revoke, and grant-type Revoke.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="examples/api-key-grant-revoke.html">HTML</a>
                  <a href="#{REPO_BASE}/blob/main/ietf/examples/api-key-grant-revoke.md">Markdown</a>
                </span>
              </td>
            </tr>
            <tr>
              <td class="draft-id" data-label="Example">Basic Grant and Revoke</td>
              <td data-label="Description">Basic session credential issuance, presentation, per-credential Revoke, and grant-type Revoke.</td>
              <td data-label="Source">
                <span class="links">
                  <a href="examples/basic-grant-revoke.html">HTML</a>
                  <a href="#{REPO_BASE}/blob/main/ietf/examples/basic-grant-revoke.md">Markdown</a>
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <h2>Source</h2>
        <p>
          Draft sources and contribution guidelines are maintained in the
          <a href="#{REPO_BASE}">aep-foundation/aep-specs</a>
          repository.
        </p>
      </main>
    </body>
  </html>
HTML

File.write(output, html)
