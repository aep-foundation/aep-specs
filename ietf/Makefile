DRAFTS := $(shell find specs -name 'draft-*.md' -type f | sort)
EXAMPLES := \
	examples/inspect-document.md \
	examples/enroll-grant-revoke-transcript.md
ARTIFACTS := ../artifacts
EXAMPLE_ARTIFACTS := ../docs/examples
SCHEMA_ARTIFACTS := ../docs/schemas
INDEX_ARTIFACT := ../docs/index.html
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
	schemas/README.md \
	test-vectors/README.md \
	templates/README.md \
	templates/core-template.md \
	templates/extension-template.md \
	$(DRAFTS) \
	$(EXAMPLES)

.PHONY: check lint check-drafts check-external-section-refs check-vectors check-schemas check-published-schemas check-harness format render render-drafts render-examples render-schemas render-index idnits clean

check: lint check-vectors check-schemas check-published-schemas check-harness

lint: check-drafts check-external-section-refs

check-drafts:
	@bundle exec ruby scripts/check_drafts.rb $(DRAFTS)

check-external-section-refs:
	@bundle exec ruby scripts/check_external_section_refs.rb $(DRAFTS)

check-vectors:
	@bundle exec ruby scripts/check_test_vectors.rb

check-schemas:
	@bundle exec ruby scripts/check_schemas.rb

check-published-schemas:
	@bundle exec ruby scripts/publish_schemas.rb --check schemas "$(SCHEMA_ARTIFACTS)"

check-harness:
	@bundle exec ruby scripts/check_conformance_harness.rb

format:
	@bundle exec ruby scripts/format_markdown_tables.rb $(MARKDOWN_TABLE_FILES)

render: render-drafts render-examples render-schemas render-index

render-drafts:
	@$(KRAMDOWN_RFC) --version >/dev/null || { echo "kramdown-rfc is required for render; run bundle install"; exit 1; }
	@test -x "$(XML2RFC)" || { echo "xml2rfc is required for render; run python3 -m venv .venv && .venv/bin/python -m pip install -r requirements.txt"; exit 1; }
	@mkdir -p "$(ARTIFACTS)" "$(XML2RFC_CACHE)"
	@for draft in $(DRAFTS); do \
		docname=$$(basename "$$draft" .md); \
		$(KRAMDOWN_RFC) "$$draft" > "$(ARTIFACTS)/$$docname.xml"; \
		$(XML2RFC) --cache "$(XML2RFC_CACHE)" --text --html --pdf --path "$(ARTIFACTS)" "$(ARTIFACTS)/$$docname.xml"; \
	done

render-examples:
	@mkdir -p "$(EXAMPLE_ARTIFACTS)"
	@for example in $(EXAMPLES); do \
		name=$$(basename "$$example" .md); \
		bundle exec ruby scripts/render_example.rb "$$example" "$(EXAMPLE_ARTIFACTS)/$$name.html"; \
	done

render-schemas:
	@bundle exec ruby scripts/publish_schemas.rb schemas "$(SCHEMA_ARTIFACTS)"

render-index:
	@bundle exec ruby scripts/render_index.rb $(DRAFTS) "$(INDEX_ARTIFACT)"

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
		rm -f "$(ARTIFACTS)/$$docname.pdf"; \
	done
