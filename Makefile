.PHONY: test lint

test:
	@lua test/run.lua "$(VERBOSE)"

lint:
	@lua-language-server --check . 2>&1
