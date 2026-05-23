.PHONY: test lint

test:
	@LUA_PATH="src/?.lua;;" lua test/run.lua "$(VERBOSE)"

lint:
	@lua-language-server --check . 2>&1
