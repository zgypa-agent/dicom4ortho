# Root orchestration: language-specific recipes belong to their implementation.
include python/Makefile

.PHONY: update_codes
update_codes: ## Fetch once and regenerate terminology artifacts for all ports
	$(PYTHON) tools/generate_codes.py

.PHONY: check_codes
check_codes: ## Check every port's terminology against upstream without writing
	$(PYTHON) tools/generate_codes.py --check
