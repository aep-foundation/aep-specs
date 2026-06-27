DRAFTS := \
	specs/core/draft-kavian-agent-enrollment-protocol-00.md \
	specs/extensions/draft-kavian-aep-oauth-session-credential-00.md \
	specs/extensions/draft-kavian-aep-api-key-session-credential-00.md \
	specs/extensions/draft-kavian-aep-basic-session-credential-00.md
ARTIFACTS := ../docs/artifacts
KRAMDOWN_RFC := bundle exec kramdown-rfc
XML2RFC := .venv/bin/xml2rfc
XML2RFC_CACHE := .cache/xml2rfc

.PHONY: check lint render clean

check: lint

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
	@grep -q '^  W3C-DID:$$' "specs/core/draft-kavian-agent-enrollment-protocol-00.md"

render:
	@$(KRAMDOWN_RFC) --version >/dev/null || { echo "kramdown-rfc is required for render; run bundle install"; exit 1; }
	@test -x "$(XML2RFC)" || { echo "xml2rfc is required for render; run python3 -m venv .venv && .venv/bin/python -m pip install -r requirements.txt"; exit 1; }
	@mkdir -p "$(ARTIFACTS)" "$(XML2RFC_CACHE)"
	@for draft in $(DRAFTS); do \
		docname=$$(basename "$$draft" .md); \
		$(KRAMDOWN_RFC) "$$draft" > "$(ARTIFACTS)/$$docname.xml"; \
		$(XML2RFC) --cache "$(XML2RFC_CACHE)" --text --html --path "$(ARTIFACTS)" "$(ARTIFACTS)/$$docname.xml"; \
	done

clean:
	@for draft in $(DRAFTS); do \
		docname=$$(basename "$$draft" .md); \
		rm -f "$(ARTIFACTS)/$$docname.xml"; \
		rm -f "$(ARTIFACTS)/$$docname.txt"; \
		rm -f "$(ARTIFACTS)/$$docname.html"; \
	done
