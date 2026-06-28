DRAFTS := \
	specs/core/draft-kavian-agent-enrollment-protocol-00.md \
	specs/extensions/draft-kavian-aep-oauth-session-credential-00.md \
	specs/extensions/draft-kavian-aep-api-key-session-credential-00.md \
	specs/extensions/draft-kavian-aep-basic-session-credential-00.md
EXAMPLES := \
	examples/inspect-document.md \
	examples/enroll-grant-revoke-transcript.md
ARTIFACTS := ../docs/artifacts
EXAMPLE_ARTIFACTS := ../docs/examples
KRAMDOWN_RFC := bundle exec kramdown-rfc
XML2RFC := .venv/bin/xml2rfc
XML2RFC_CACHE := .cache/xml2rfc
IDNITS := idnits
MARKDOWN_TABLE_FILES ?= \
	../README.md \
	README.md \
	STYLE.md \
	specs/README.md \
	conformance/README.md \
	test-vectors/README.md \
	templates/README.md \
	templates/core-template.md \
	templates/extension-template.md \
	$(DRAFTS) \
	$(EXAMPLES)

.PHONY: check lint check-vectors format render render-drafts render-examples idnits clean

check: lint check-vectors

lint:
	@for draft in $(DRAFTS); do \
		test -f "$$draft"; \
		grep -q '^docname: draft-' "$$draft"; \
		grep -q '^# Introduction$$' "$$draft"; \
		grep -q '^# IANA Considerations$$' "$$draft"; \
		grep -q '^# Security Considerations$$' "$$draft"; \
		grep -q '^# Privacy Considerations$$' "$$draft"; \
		grep -q '^normative:$$' "$$draft"; \
		grep -q '^informative:$$' "$$draft"; \
		grep -q '{{RFC9110}}' "$$draft"; \
		! grep -q '^# References$$' "$$draft"; \
		! grep -q 'Add normative and informative references' "$$draft"; \
	done
	@grep -q '^  DID-WEB:$$' "specs/core/draft-kavian-agent-enrollment-protocol-00.md"

check-vectors:
	@bundle exec ruby scripts/check_test_vectors.rb

format:
	@bundle exec ruby scripts/format_markdown_tables.rb $(MARKDOWN_TABLE_FILES)

render: render-drafts render-examples

render-drafts:
	@$(KRAMDOWN_RFC) --version >/dev/null || { echo "kramdown-rfc is required for render; run bundle install"; exit 1; }
	@test -x "$(XML2RFC)" || { echo "xml2rfc is required for render; run python3 -m venv .venv && .venv/bin/python -m pip install -r requirements.txt"; exit 1; }
	@mkdir -p "$(ARTIFACTS)" "$(XML2RFC_CACHE)"
	@for draft in $(DRAFTS); do \
		docname=$$(basename "$$draft" .md); \
		$(KRAMDOWN_RFC) "$$draft" > "$(ARTIFACTS)/$$docname.xml"; \
		$(XML2RFC) --cache "$(XML2RFC_CACHE)" --text --html --path "$(ARTIFACTS)" "$(ARTIFACTS)/$$docname.xml"; \
	done

render-examples:
	@mkdir -p "$(EXAMPLE_ARTIFACTS)"
	@for example in $(EXAMPLES); do \
		name=$$(basename "$$example" .md); \
		bundle exec ruby scripts/render_example.rb "$$example" "$(EXAMPLE_ARTIFACTS)/$$name.html"; \
	done

idnits: render-drafts
	@command -v "$(IDNITS)" >/dev/null || { echo "idnits is required"; exit 1; }
	@for draft in $(DRAFTS); do \
		docname=$$(basename "$$draft" .md); \
		echo "== idnits: $$docname.txt =="; \
		$(IDNITS) "$(ARTIFACTS)/$$docname.txt"; \
		echo; \
	done

clean:
	@for draft in $(DRAFTS); do \
		docname=$$(basename "$$draft" .md); \
		rm -f "$(ARTIFACTS)/$$docname.xml"; \
		rm -f "$(ARTIFACTS)/$$docname.txt"; \
		rm -f "$(ARTIFACTS)/$$docname.html"; \
	done
	@for example in $(EXAMPLES); do \
		name=$$(basename "$$example" .md); \
		rm -f "$(EXAMPLE_ARTIFACTS)/$$name.html"; \
	done
